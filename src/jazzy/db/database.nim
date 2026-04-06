import tiny_sqlite
export tiny_sqlite
import std/locks

proc dbValue*(v: int64): DbValue = DbValue(kind: sqliteInteger, intVal: v)
proc dbValue*(v: int): DbValue = DbValue(kind: sqliteInteger, intVal: v.int64)
proc dbValue*(v: string): DbValue = DbValue(kind: sqliteText, strVal: v)
proc dbValue*(v: float): DbValue = DbValue(kind: sqliteReal, floatVal: v)
proc dbValue*(v: bool): DbValue = DbValue(kind: sqliteInteger, intVal: (if v: 1.int64 else: 0.int64))
proc dbNull*(): DbValue = DbValue(kind: sqliteNull)

var dbConn*: DbConn
var dbLock*: Lock
var isConnected*: bool = false

# Initialize lock at module level to avoid crashes
initLock(dbLock)

proc connectDB*(path: string) =
  dbConn = openDatabase(path)
  dbConn.exec("PRAGMA journal_mode=WAL")
  isConnected = true

proc getConn*(): DbConn =
  return dbConn

proc isDbConnected*(): bool =
  return isConnected

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
  if isConnected:
    withDB:
      dbConn.close()
    isConnected = false
  # Note: deinitLock is usually called at the very end of app lifecycle

proc exec*(sql: string) =
  if isConnected:
    withDB:
      dbConn.exec(sql)
