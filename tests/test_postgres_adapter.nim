import std/[asyncdispatch, atomics, os, unittest]
import jazzy/db/postgres
import jazzy/http/[context, types]

const postgresTestDsn = "JAZZY_POSTGRES_TEST_DSN"
const workerCount = 4

var workerFailures: Atomic[int]

proc jazzyHandlerShape(ctx: Context): Future[void] {.async, gcsafe.} =
  let db = await postgresForWorker("postgresql://user:pass@127.0.0.1:5432/app")
  ctx.text(await db.queryValue("SELECT 1"))

let handlerCompileCheck: HandlerProc = jazzyHandlerShape

proc runPostgresAdapterTest(dsn: string): Future[void] {.async.} =
  let db = await connectPostgres(dsn, minConnections = 1, maxConnections = 2)
  defer:
    await db.close()

  discard await db.exec("DROP TABLE IF EXISTS jazzy_postgres_adapter_test")
  discard await db.exec("CREATE TABLE jazzy_postgres_adapter_test (id INTEGER PRIMARY KEY)")
  discard await db.exec("INSERT INTO jazzy_postgres_adapter_test (id) VALUES (1)")
  let count = await db.queryValue("SELECT count(*) FROM jazzy_postgres_adapter_test")
  check count == "1"

proc postgresWorker(_: int) {.thread.} =
  proc runWorker(): Future[void] {.async, gcsafe.} =
    let db = await postgresForWorker(getEnv(postgresTestDsn),
      minConnections = 1, maxConnections = 2)
    defer:
      await closePostgresForWorker()
    for _ in 0 ..< 10:
      let value = await db.queryValue("SELECT 1")
      if value != "1":
        discard workerFailures.fetchAdd(1)
  waitFor runWorker()

suite "PostgreSQL adapter":
  test "connects and executes queries":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    else:
      waitFor runPostgresAdapterTest(dsn)

  test "uses independent pools from multiple worker threads":
    if getEnv(postgresTestDsn).len == 0:
      skip()
    else:
      workerFailures.store(0)
      var workers: array[workerCount, Thread[int]]
      for i in 0 ..< workerCount:
        createThread(workers[i], postgresWorker, i)
      joinThreads(workers)
      check workerFailures.load() == 0
