import tiny_sqlite

var dbConn*: DbConn

proc connectDB*(path: string) =
  dbConn = openDatabase(path)

proc getConn*(): DbConn =
  {.cast(gcsafe).}:
    return dbConn

proc closeDB*() =
  dbConn.close()

proc exec*(sql: string) =
  dbConn.exec(sql)
