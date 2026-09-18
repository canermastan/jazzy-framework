import tiny_sqlite
export tiny_sqlite
import std/[asyncdispatch, locks, strutils]
import ../core/config

type
  DatabaseDriver* = enum
    dbSqlite,
    dbPostgres,
    dbMySql

proc dbValue*(v: int64): DbValue = DbValue(kind: sqliteInteger, intVal: v)
proc dbValue*(v: int): DbValue = DbValue(kind: sqliteInteger, intVal: v.int64)
proc dbValue*(v: string): DbValue = DbValue(kind: sqliteText, strVal: v)
proc dbValue*(v: float): DbValue = DbValue(kind: sqliteReal, floatVal: v)
proc dbValue*(v: bool): DbValue = DbValue(kind: sqliteInteger, intVal: (if v: 1.int64 else: 0.int64))
proc dbNull*(): DbValue = DbValue(kind: sqliteNull)

var dbConn*: DbConn
var dbLock*: Lock
var isConnected*: bool = false
var configuredDriver = dbSqlite
var databaseConfigured = false
var sqliteTransactionDepth {.threadvar.}: int
var sqliteSchemaEpoch = 0

# Initialize lock at module level to avoid crashes
initLock(dbLock)

proc connectDB*(path: string) =
  ## Legacy explicit SQLite connection. Prefer DB_CONNECTION/DB_DATABASE in .env.
  if path.len == 0:
    raise newException(ValueError, "SQLite database path cannot be empty")
  dbConn = openDatabase(path)
  dbConn.exec("PRAGMA journal_mode=WAL")
  dbConn.exec("PRAGMA foreign_keys=ON")
  isConnected = true
  configuredDriver = dbSqlite
  databaseConfigured = true

proc databaseDriver*(): DatabaseDriver {.gcsafe.} =
  configuredDriver

proc databaseUrl*(): string {.gcsafe.} =
  ## The configured PostgreSQL connection URL.
  getConfig("DATABASE_URL")

proc databasePoolMin*(): int {.gcsafe.} =
  try:
    parseInt(getConfig("DB_POOL_MIN", "1"))
  except ValueError:
    1

proc databasePoolMax*(): int {.gcsafe.} =
  try:
    parseInt(getConfig("DB_POOL_MAX", "1"))
  except ValueError:
    1

proc configureDatabase*() =
  ## Configure the selected database from the environment.
  ##
  ## DB_CONNECTION accepts sqlite (default), postgres, or mysql. SQLite opens
  ## once during startup; PostgreSQL opens one lazy pool per Mummy worker.
  if databaseConfigured:
    return
  let connection = getConfig("DB_CONNECTION", "sqlite").toLowerAscii()
  case connection
  of "", "sqlite":
    configuredDriver = dbSqlite
    let path = getConfig("DB_DATABASE", "database.sqlite")
    if not isConnected:
      connectDB(path)
  of "postgres", "postgresql":
    configuredDriver = dbPostgres
    if databaseUrl().len == 0:
      raise newException(ValueError,
        "DATABASE_URL is required when DB_CONNECTION=postgres")
  of "mysql", "mariadb":
    configuredDriver = dbMySql
    raise newException(ValueError,
      "MySQL/MariaDB support is not available yet")
  else:
    raise newException(ValueError, "Unsupported DB_CONNECTION: " & connection)
  databaseConfigured = true

proc ensureDatabaseConfigured*() =
  ## Lazily load .env and prepare the selected database for code that runs
  ## before Jazzy.serve(), such as application schema setup.
  if not databaseConfigured:
    loadEnv(silent = true)
    configureDatabase()

proc isDatabaseConfigured*(): bool {.gcsafe.} =
  databaseConfigured

proc getConn*(): DbConn {.gcsafe.} =
  ## Callers must hold `dbLock` while using this connection.  The connection is
  ## initialized before serving requests and protected by that lock, so reading
  ## its handle is safe from Jazzy's GC-safe async request handlers.
  {.cast(gcsafe).}:
    return dbConn

proc isDbConnected*(): bool =
  return isConnected

proc acquireDB*() =
  acquire(dbLock)

proc releaseDB*() =
  release(dbLock)

template withDB*(body: untyped) =
  ## A migration pins the SQLite connection for the duration of its
  ## transaction. Normal builder calls must not acquire the same
  ## non-reentrant lock again while that transaction is active.
  if sqliteTransactionDepth > 0:
    body
  else:
    acquire(dbLock)
    try:
      body
    finally:
      release(dbLock)

proc markSqliteSchemaChanged*() =
  ## tiny_sqlite caches prepared statements. Include this epoch in statements
  ## issued after a builder-managed DDL change so `SELECT *` cannot keep an old
  ## column layout after an add, rename, drop, or table rebuild.
  if configuredDriver != dbSqlite:
    return
  withDB:
    inc sqliteSchemaEpoch

proc sqliteSchemaStatement*(sql: string): string =
  ## The caller must hold dbLock. A trailing comment is valid SQL and changes
  ## only when Jazzy's schema builder changes the SQLite schema.
  sql & " /* jazzy-schema-" & $sqliteSchemaEpoch & " */"

proc withSqliteTransaction*(body: proc(): Future[void]): Future[void] {.async.} =
  ## Run a startup/CLI operation in one SQLite transaction.
  ##
  ## This is an internal primitive for the migration runner. It holds Jazzy's
  ## shared SQLite lock, so it must not be used for arbitrary long-running
  ## work in a live request handler.
  ensureDatabaseConfigured()
  if databaseDriver() != dbSqlite:
    raise newException(ValueError, "SQLite transaction requested for a non-SQLite database")
  if sqliteTransactionDepth > 0:
    raise newException(ValueError, "Nested SQLite transactions are not supported")

  acquire(dbLock)
  inc sqliteTransactionDepth
  let conn = getConn()
  try:
    conn.exec("BEGIN IMMEDIATE")
    try:
      await body()
      conn.exec("COMMIT")
    except CatchableError:
      try:
        conn.exec("ROLLBACK")
      except CatchableError:
        discard
      raise
  finally:
    dec sqliteTransactionDepth
    release(dbLock)

proc closeDB*() =
  if isConnected:
    withDB:
      dbConn.close()
    isConnected = false
  # Note: deinitLock is usually called at the very end of app lifecycle

proc exec*(sql: string) =
  if isConnected:
    withDB:
      dbConn.exec(sql)
