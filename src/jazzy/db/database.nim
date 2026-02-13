import tiny_sqlite
import std/locks

var dbConn*: DbConn
var dbLock*: Lock

proc connectDB*(path: string) =
  initLock(dbLock)
  dbConn = openDatabase(path)
  dbConn.exec("PRAGMA journal_mode=WAL")

proc getConn*(): DbConn =
  return dbConn

proc acquireDB*() =
  acquire(dbLock)

proc releaseDB*() =
  release(dbLock)

template withDB*(body: untyped) =
  acquire(dbLock)
  try:
    body
  finally:
    release(dbLock)

proc closeDB*() =
  withDB:
    dbConn.close()
  deinitLock(dbLock)

proc exec*(sql: string) =
  withDB:
    dbConn.exec(sql)
