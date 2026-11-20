import std/[asyncdispatch, asyncnet, atomics, nativesockets, os, strutils, unittest]
import jazzy/db/postgres
import jazzy/http/[context, types]

const postgresTestDsn = "JAZZY_POSTGRES_TEST_DSN"
const workerCount = 4

var workerFailures: Atomic[int]

proc addInt16Be(buf: var string, val: int16) =
  buf.add(char((val shr 8) and 0xFF))
  buf.add(char(val and 0xFF))

proc addInt32Be(buf: var string, val: int32) =
  buf.add(char((val shr 24) and 0xFF))
  buf.add(char((val shr 16) and 0xFF))
  buf.add(char((val shr 8) and 0xFF))
  buf.add(char(val and 0xFF))

proc decodeInt32Be(buf: string, offset = 0): int32 =
  (int32(uint8(buf[offset])) shl 24) or
  (int32(uint8(buf[offset + 1])) shl 16) or
  (int32(uint8(buf[offset + 2])) shl 8) or
  int32(uint8(buf[offset + 3]))

proc buildPgMsg(msgType: char, body: string): string =
  result.add(msgType)
  result.addInt32Be(int32(4 + body.len))
  result.add(body)

proc handleMockPgClient(client: AsyncSocket) {.async.} =
  try:
    let startupLenBuf = await client.recv(4)
    if startupLenBuf.len < 4:
      client.close()
      return
    let startupLen = decodeInt32Be(startupLenBuf)
    if startupLen > 4:
      discard await client.recv(int(startupLen - 4))

    var handshake = ""
    var authOkBody = ""
    authOkBody.addInt32Be(0)
    handshake.add(buildPgMsg('R', authOkBody))
    var keyBody = ""
    keyBody.addInt32Be(1234)
    keyBody.addInt32Be(5678)
    handshake.add(buildPgMsg('K', keyBody))
    handshake.add(buildPgMsg('Z', "I"))
    await client.send(handshake)

    while true:
      let typeBuf = await client.recv(1)
      if typeBuf.len == 0:
        break
      let msgType = typeBuf[0]
      let lenBuf = await client.recv(4)
      if lenBuf.len < 4:
        break
      let msgLen = decodeInt32Be(lenBuf)
      let body = if msgLen > 4: await client.recv(int(msgLen - 4)) else: ""

      case msgType
      of 'X':
        break
      of 'Q':
        var resp = ""
        if body.len <= 1:
          resp.add(buildPgMsg('I', ""))
        else:
          resp.add(buildPgMsg('C', "OK\0"))
        resp.add(buildPgMsg('Z', "I"))
        await client.send(resp)
      of 'P', 'B', 'D', 'E', 'C':
        # Extended query protocol messages are flushed when Sync ('S') arrives.
        discard
      of 'S':
        # Respond to extended query batch: ParseComplete ('1'), BindComplete ('2'),
        # RowDescription ('T'), DataRow ('D'), CommandComplete ('C'), ReadyForQuery ('Z').
        var resp = ""
        resp.add(buildPgMsg('1', ""))
        resp.add(buildPgMsg('2', ""))
        var rowDesc = ""
        rowDesc.addInt16Be(1)
        rowDesc.add("val\0")
        rowDesc.addInt32Be(0)
        rowDesc.addInt16Be(0)
        rowDesc.addInt32Be(25) # text OID
        rowDesc.addInt16Be(-1)
        rowDesc.addInt32Be(-1)
        rowDesc.addInt16Be(0)
        resp.add(buildPgMsg('T', rowDesc))
        var dataRow = ""
        dataRow.addInt16Be(1)
        dataRow.addInt32Be(1)
        dataRow.add("1")
        resp.add(buildPgMsg('D', dataRow))
        resp.add(buildPgMsg('C', "SELECT 1\0"))
        resp.add(buildPgMsg('Z', "I"))
        await client.send(resp)
      else:
        discard
  except CatchableError:
    discard
  finally:
    client.close()

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

  test "bounds worker pool to maxConnections and prevents duplicate init or transaction deadlocks":
    proc runBoundedPoolTest() {.async.} =
      let server = newAsyncSocket(buffered = false)
      server.setSockOpt(OptReuseAddr, true)
      server.bindAddr(Port(0), "127.0.0.1")
      let port = int(server.getLocalAddr()[1])
      server.listen()

      var acceptedConnections = 0
      var serverClosed = false

      proc acceptLoop() {.async.} =
        while not serverClosed:
          try:
            let client = await server.accept()
            inc acceptedConnections
            asyncCheck handleMockPgClient(client)
          except CatchableError:
            break

      asyncCheck acceptLoop()
      let dsn = "postgresql://user:pass@127.0.0.1:" & $port & "/app?sslmode=disable"
      try:
        # 1. Two concurrent postgresForWorker calls on a fresh worker thread
        # must share the same in-flight connectPostgres future and open only 1 connection.
        let f1 = postgresForWorker(dsn, minConnections = 1, maxConnections = 1)
        let f2 = postgresForWorker(dsn, minConnections = 1, maxConnections = 1)
        let db1 = await f1
        let db2 = await f2
        check db1 == db2
        check acceptedConnections == 1

        # 2. Concurrent queries on maxConnections = 1 must queue via acquireSlot
        # and reuse the single connection without opening extra connections.
        let q1 = db1.queryValue("SELECT 1")
        let q2 = db1.queryValue("SELECT 1")
        let q3 = db1.exec("SELECT 1")
        check (await q1) == "1"
        check (await q2) == "1"
        discard await q3
        check acceptedConnections == 1

        # 3. withPostgresTransaction on maxConnections = 1 must route exec,
        # query, and queryValue through the pinned connection without deadlocking
        # or opening a second connection.
        await db1.withPostgresTransaction(proc(): Future[void] {.async.} =
          discard await db1.exec("SELECT 1")
          let qr = await db1.query("SELECT 1")
          check qr.rowCount == 1
          check (await db1.queryValue("SELECT 1")) == "1"
        )
        check acceptedConnections == 1
      finally:
        await closePostgresForWorker()
        serverClosed = true
        server.close()

    waitFor runBoundedPoolTest()
