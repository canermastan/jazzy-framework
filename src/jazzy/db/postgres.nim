## PostgreSQL adapter for Jazzy.
##
## This is deliberately a small first integration layer.  It owns Jazzy's
## public connection shape while `async_postgres` owns the PostgreSQL wire
## protocol and connection pool implementation.

import std/asyncdispatch
import async_postgres
export async_postgres
import database

type
  PostgresDatabase* = ref object
    pool: PgPool
    maxConnections: int
    inUse: int
    waiters: seq[Future[void]]

var
  workerDatabase {.threadvar.}: PostgresDatabase
  workerConnecting {.threadvar.}: Future[PostgresDatabase]
  workerDsn {.threadvar.}: string
  pinnedConnection {.threadvar.}: PgConnection

proc acquireSlot(db: PostgresDatabase): Future[void] {.async, gcsafe.} =
  let limit = max(1, db.maxConnections)
  while db.inUse >= limit:
    let waiter = newFuture[void]("jazzy.postgres.acquireSlot")
    db.waiters.add(waiter)
    await waiter
  inc db.inUse

proc releaseSlot(db: PostgresDatabase) {.gcsafe.} =
  if db.inUse > 0:
    dec db.inUse
  let limit = max(1, db.maxConnections)
  while db.waiters.len > 0 and db.inUse < limit:
    let waiter = db.waiters[0]
    db.waiters.delete(0)
    if not waiter.finished:
      waiter.complete()
      break

proc connectPostgres*(dsn: string, minConnections = 1,
    maxConnections = 1): Future[PostgresDatabase] {.async, gcsafe.} =
  ## Connect to PostgreSQL using a DSN and create a pool for this database.
  ##
  ## This first adapter intentionally returns an explicit database handle.
  ## A later Jazzy integration can own one pool per Mummy worker thread.
  if dsn.len == 0:
    raise newException(ValueError, "PostgreSQL DSN cannot be empty")
  if minConnections < 0 or maxConnections < 1 or minConnections > maxConnections:
    raise newException(ValueError, "Invalid PostgreSQL pool size")

  new(result)
  result.maxConnections = maxConnections
  # Pass minSize = 0 so background maintenance replenishment cannot race with
  # per-worker demand, and resetQuery = "" to avoid an extra round-trip (and
  # background slot hold) on every query release in Jazzy's query builder.
  # Use environment = false so DATABASE_URL in .env is not overridden by
  # ambient PG* environment variables or host ~/.postgresql files.
  let config = initPoolConfig(
    parseDsn(dsn, environment = false),
    minSize = 0,
    maxSize = maxConnections,
    resetQuery = ""
  )
  # asyncdispatch keeps its dispatcher in thread-local storage. The driver is
  # conservative about that internal state, so Nim cannot infer GC safety
  # through its async call chain. This boundary is safe only because this
  # adapter never shares a PgPool between OS threads.
  {.cast(gcsafe).}:
    result.pool = await newPool(config)
    if minConnections > 0:
      try:
        let warmConn = await result.pool.acquire()
        warmConn.release()
      except CatchableError:
        await result.pool.close()
        result.pool = nil
        raise

proc postgresForWorker*(dsn: string, minConnections = 1,
    maxConnections = 1): Future[PostgresDatabase] {.async, gcsafe.} =
  ## Return the PostgreSQL pool owned by the current Mummy worker thread.
  ##
  ## The same DSN must be used for the lifetime of a worker. Each worker gets
  ## an independent pool, so no PgPool is shared across OS threads.
  if not workerDatabase.isNil:
    if workerDsn != dsn:
      raise newException(ValueError,
        "PostgreSQL DSN cannot change within a worker thread")
    return workerDatabase

  if not workerConnecting.isNil:
    if workerDsn != dsn:
      raise newException(ValueError,
        "PostgreSQL DSN cannot change within a worker thread")
    return await workerConnecting

  workerDsn = dsn
  let connectFut = connectPostgres(dsn, minConnections, maxConnections)
  workerConnecting = connectFut
  try:
    workerDatabase = await connectFut
    return workerDatabase
  except CatchableError:
    workerDsn = ""
    raise
  finally:
    workerConnecting = nil

proc postgresForCurrentWorker*(): Future[PostgresDatabase] {.async, gcsafe.} =
  ## Return the configured PostgreSQL pool for this Mummy worker.
  if databaseDriver() != dbPostgres:
    raise newException(ValueError,
      "DB_CONNECTION must be postgres to use PostgreSQL queries")
  return await postgresForWorker(databaseUrl(), databasePoolMin(), databasePoolMax())

proc close*(db: PostgresDatabase): Future[void] {.async, gcsafe.} =
  ## Close every connection managed by this database handle.
  if not db.isNil and not db.pool.isNil:
    {.cast(gcsafe).}:
      await db.pool.close()

proc closePostgresForWorker*(): Future[void] {.async, gcsafe.} =
  ## Close and forget the PostgreSQL pool owned by the current worker thread.
  if not workerConnecting.isNil:
    try:
      discard await workerConnecting
    except CatchableError:
      discard
  if not workerDatabase.isNil:
    let db = workerDatabase
    workerDatabase = nil
    workerDsn = ""
    await db.close()

proc withPostgresTransaction*(db: PostgresDatabase,
    body: proc(): Future[void]): Future[void] {.async.} =
  ## Pin one pooled connection while `body` runs.
  ##
  ## The public builder still calls `PostgresDatabase.query/exec`; those
  ## methods route to this connection, letting migrations use normal DB and
  ## schema APIs while keeping PostgreSQL migrations atomic.
  if db.isNil or db.pool.isNil:
    raise newException(ValueError, "PostgreSQL is not connected")
  if not pinnedConnection.isNil:
    raise newException(ValueError, "Nested PostgreSQL transactions are not supported")

  await db.acquireSlot()
  var conn: PgConnection
  try:
    conn = await db.pool.acquire()
  except CatchableError:
    db.releaseSlot()
    raise
  pinnedConnection = conn
  try:
    discard await conn.exec("BEGIN")
    try:
      await body()
      discard await conn.exec("COMMIT")
    except CatchableError:
      try:
        discard await conn.exec("ROLLBACK")
      except CatchableError:
        discard
      raise
  finally:
    pinnedConnection = nil
    conn.release()
    db.releaseSlot()

proc exec*(db: PostgresDatabase, statement: string): Future[CommandResult] {.async, gcsafe.} =
  ## Execute a parameterless SQL statement.
  if db.isNil or db.pool.isNil:
    raise newException(ValueError, "PostgreSQL is not connected")
  {.cast(gcsafe).}:
    if not pinnedConnection.isNil:
      return await pinnedConnection.exec(statement)
    await db.acquireSlot()
    try:
      return await db.pool.exec(statement)
    finally:
      db.releaseSlot()

proc exec*(db: PostgresDatabase, statement: string,
    params: seq[PgParam]): Future[CommandResult] {.async, gcsafe.} =
  ## Execute a parameterized SQL statement.
  if db.isNil or db.pool.isNil:
    raise newException(ValueError, "PostgreSQL is not connected")
  {.cast(gcsafe).}:
    if not pinnedConnection.isNil:
      return await pinnedConnection.exec(statement, params)
    await db.acquireSlot()
    try:
      return await db.pool.exec(statement, params)
    finally:
      db.releaseSlot()

proc query*(db: PostgresDatabase, statement: string,
    params: seq[PgParam] = @[],
    resultFormat: ResultFormat = rfAuto): Future[QueryResult] {.async, gcsafe.} =
  ## Execute a parameterized query and return PostgreSQL row metadata and data.
  if db.isNil or db.pool.isNil:
    raise newException(ValueError, "PostgreSQL is not connected")
  {.cast(gcsafe).}:
    if not pinnedConnection.isNil:
      return await pinnedConnection.query(statement, params, resultFormat = resultFormat)
    await db.acquireSlot()
    try:
      return await db.pool.query(statement, params, resultFormat = resultFormat)
    finally:
      db.releaseSlot()

proc queryValue*(db: PostgresDatabase, statement: string): Future[string] {.async, gcsafe.} =
  ## Return the first column of the first row as text.
  if db.isNil or db.pool.isNil:
    raise newException(ValueError, "PostgreSQL is not connected")
  {.cast(gcsafe).}:
    if not pinnedConnection.isNil:
      return await pinnedConnection.queryValue(statement)
    await db.acquireSlot()
    try:
      return await db.pool.queryValue(statement)
    finally:
      db.releaseSlot()
