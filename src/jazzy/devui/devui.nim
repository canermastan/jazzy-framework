import std/[asyncdispatch, json, tables, strutils, sequtils, times]
import ../http/[context, types, router]
import ../core/[config, cache, logger]
import ../db/[database, builder]
import tiny_sqlite

const
  devUiHtml = staticRead("assets/index.html")
  picoCss = staticRead("assets/pico.min.css")
  alpineJs = staticRead("assets/alpine.min.js")

const sensitiveKeywords = ["secret", "password", "key"]

template requireDb(ctx: Context) =
  if not isDbConnected():
    ctx.status(404).json(%*{"error": "Database not configured"})
    return

proc getDbTablesApi*(ctx: Context) {.async.} =
  requireDb(ctx)

  var tablesArray = newJArray()
  try:
    withDB:
      let conn = getConn()
      for row in conn.iterate("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"):
        let tableName = row[0].strVal
        var t = newJObject()
        t["name"] = %tableName
        var count = 0
        for cRow in conn.iterate("SELECT COUNT(*) FROM " & tableName):
          count = cRow[0].intVal
        t["count"] = %count
        tablesArray.add(t)
    ctx.json(tablesArray)
  except Exception as e:
    ctx.status(500).json(%*{"error": e.msg})

proc getDbDataApi*(ctx: Context) {.async.} =
  requireDb(ctx)

  let tableName = ctx.param("table")
  if tableName == "":
    ctx.status(400).json(%*{"error": "Table name required"})
    return

  try:
    let data = DB.table(tableName).limit(50).get()
    ctx.json(data)
  except Exception as e:
    ctx.status(500).json(%*{"error": e.msg})

proc getDbTableSchemaApi*(ctx: Context) {.async.} =
  requireDb(ctx)

  let tableName = ctx.param("table")
  if tableName == "":
    ctx.status(400).json(%*{"error": "Table name required"})
    return

  var columnsArray = newJArray()
  try:
    withDB:
      let conn = getConn()
      for row in conn.iterate("PRAGMA table_info(" & sanitizeIdentifier(
          tableName) & ")"):
        var col = newJObject()
        col["id"] = %row[0].intVal
        col["name"] = %row[1].strVal
        col["type"] = %row[2].strVal
        col["notnull"] = %row[3].intVal
        col["default"] = valToJson(row[4])
        col["pk"] = %row[5].intVal
        columnsArray.add(col)
    ctx.json(columnsArray)
  except Exception as e:
    ctx.status(500).json(%*{"error": e.msg})

proc postDbQueryApi*(ctx: Context) {.async.} =
  requireDb(ctx)

  let sql = ctx.input("sql")
  if sql.strip() == "":
    ctx.status(400).json(%*{"error": "SQL query is empty"})
    return

  try:
    withDB:
      let conn = getConn()
      let upperSql = sql.toUpperAscii().strip()

      if upperSql.startsWith("SELECT") or upperSql.startsWith("PRAGMA"):
        var results = newJArray()

        # Try to extract column names for simple "SELECT ... FROM table" queries
        var colNames: seq[string] = @[]
        let fromIdx = upperSql.find("FROM ")
        if fromIdx >= 0:
          let afterFrom = sql.strip()[fromIdx + 5 .. ^1].strip()
          let tableEnd = afterFrom.find({' ', ';', '\n', '\r'})
          let guessedTable = if tableEnd > 0: afterFrom[0 ..< tableEnd]
                             else: afterFrom
          try:
            colNames = getColumns(sanitizeIdentifier(guessedTable))
          except:
            discard

        for row in conn.iterate(sql):
          var obj = newJObject()
          for i in 0 ..< row.len:
            let colName = if i < colNames.len: colNames[i]
                          else: "col_" & $i
            obj[colName] = valToJson(row[i])
          results.add(obj)
        ctx.json(%*{"type": "data", "data": results})
      else:
        conn.exec(sql)
        ctx.json(%*{"type": "exec", "affected": conn.changes()})
  except Exception as e:
    ctx.status(500).json(%*{"error": e.msg})

proc getRoutesApi*(ctx: Context) {.async.} =
  var routesArray = newJArray()

  for route in Route.routes:
    var r = newJObject()
    r["method"] = %( $route.httpMethod)
    r["path"] = %route.path
    r["middlewares"] = %route.middlewares.join(", ")
    r["isInternal"] = %(route.path.startsWith("/dev-ui"))
    routesArray.add(r)

  ctx.json(routesArray)

proc getEnvApi*(ctx: Context) {.async.} =
  var envObj = newJObject()
  let configs = getAllConfigs()

  for key, val in configs.pairs:
    let lower = key.toLowerAscii()
    let isSensitive = sensitiveKeywords.anyIt(lower.contains(it))
    if isSensitive:
      envObj[key] = %"********"
    else:
      envObj[key] = %val

  ctx.json(envObj)

proc getCacheApi*(ctx: Context) {.async.} =
  var cacheArray = newJArray()
  let now = epochTime()

  for item in ctx.cache.getAllKeys():
    var obj = newJObject()
    obj["key"] = %item.key
    let remaining = item.expiresAt - now
    obj["ttl"] = %(if remaining > 0: $remaining.int & "s" else: "Expired")
    cacheArray.add(obj)

  ctx.json(cacheArray)

proc postClearCache*(ctx: Context) {.async.} =
  ctx.cache.clear()
  ctx.json(%*{"status": "ok"})

proc serveDevUi*(ctx: Context) {.async.} =
  ctx.html(devUiHtml)

proc servePico*(ctx: Context) {.async.} =
  ctx.header("Content-Type", "text/css")
  ctx.response.body = picoCss

proc serveAlpine*(ctx: Context) {.async.} =
  ctx.header("Content-Type", "application/javascript")
  ctx.response.body = alpineJs

proc registerDevUi*(path: string = "/dev-ui") =
  if isProduction():
    Log.warn("Dev UI is disabled in production mode")
    return

  Route.get(path, serveDevUi)
  Route.get(path & "/assets/pico.min.css", servePico)
  Route.get(path & "/assets/alpine.min.js", serveAlpine)

  # API Endpoints
  Route.get(path & "/api/routes", getRoutesApi)
  Route.get(path & "/api/env", getEnvApi)
  Route.get(path & "/api/cache", getCacheApi)
  Route.post(path & "/api/cache/clear", postClearCache)

  # Database API
  Route.get(path & "/api/db/tables", getDbTablesApi)
  Route.get(path & "/api/db/schema/:table", getDbTableSchemaApi)
  Route.get(path & "/api/db/data/:table", getDbDataApi)
  Route.post(path & "/api/db/query", postDbQueryApi)

