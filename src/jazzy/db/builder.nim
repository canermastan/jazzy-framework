import std/[json, strutils, times]
import tiny_sqlite
import database

proc sanitizeIdentifier*(name: string): string =
  if name.len == 0:
    raise newException(ValueError, "SQL identifier cannot be empty")
  for c in name:
    if c notin {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
      raise newException(ValueError, "Invalid SQL identifier: " & name)
  return name

type
  QueryBuilder* = ref object
    tableName: string
    wheres: seq[string]
    limit: int
    offset: int
    columns: seq[string]
    orderClause: string
    params: seq[DbValue]
    withTrashedBool: bool
    onlyTrashedBool: bool

  DatabaseHelper* = object

proc valToJson*(val: DbValue): JsonNode =
  case val.kind
  of sqliteInteger: return %val.intVal
  of sqliteReal: return %val.floatVal
  of sqliteText: return %val.strVal
  of sqliteBlob: return %"<blob>"
  of sqliteNull: return newJNull()

var DB*: DatabaseHelper

# Builder Methods
proc table*(db: DatabaseHelper, name: string): QueryBuilder =
  new(result)
  result.tableName = sanitizeIdentifier(name)
  result.wheres = @[]
  result.params = @[]
  result.limit = -1
  result.offset = -1
  result.columns = @[]
  result.orderClause = ""
  result.withTrashedBool = false
  result.onlyTrashedBool = false

proc raw*(db: DatabaseHelper, sql: string, params: varargs[DbValue,
    dbValue]): JsonNode =
  result = newJArray()
  let p = @params # Convert varargs to seq
  withDB:
    for row in database.getConn().iterate(sql, p):
      var rowJson = newJObject()
      for i in 0 ..< row.len:
        rowJson[row.columns[i]] = valToJson(row[i])
      result.add(rowJson)

proc rawExec*(db: DatabaseHelper, sql: string, params: varargs[DbValue,
    dbValue]): int =
  let p = @params # Convert varargs to seq
  withDB:
    let conn = database.getConn()
    conn.exec(sql, p)
    return conn.changes()

proc select*(qb: QueryBuilder, cols: varargs[string]): QueryBuilder =
  for col in cols:
    qb.columns.add(sanitizeIdentifier(col))
  return qb

proc where*(qb: QueryBuilder, col: string, val: string): QueryBuilder =
  qb.wheres.add(sanitizeIdentifier(col) & " = ?")
  qb.params.add(dbValue(val))
  return qb

proc where*(qb: QueryBuilder, col: string, val: int): QueryBuilder =
  qb.wheres.add(sanitizeIdentifier(col) & " = ?")
  qb.params.add(dbValue(val))
  return qb

proc where*(qb: QueryBuilder, col: string, op: string,
    val: string): QueryBuilder =
  qb.wheres.add(sanitizeIdentifier(col) & " " & op & " ?")
  qb.params.add(dbValue(val))
  return qb

proc limit*(qb: QueryBuilder, n: int): QueryBuilder =
  qb.limit = n
  return qb

proc offset*(qb: QueryBuilder, n: int): QueryBuilder =
  qb.offset = n
  return qb

proc orderBy*(qb: QueryBuilder, col: string,
    direction: string = "ASC"): QueryBuilder =
  let dir = if direction.toUpperAscii == "DESC": "DESC" else: "ASC"
  qb.orderClause = sanitizeIdentifier(col) & " " & dir
  return qb

proc withTrashed*(qb: QueryBuilder): QueryBuilder =
  qb.withTrashedBool = true
  return qb

proc onlyTrashed*(qb: QueryBuilder): QueryBuilder =
  qb.onlyTrashedBool = true
  return qb

proc getColumns*(tableName: string): seq[string] =
  result = @[]
  withDB:
    for row in database.getConn().iterate("PRAGMA table_info(" & tableName & ")"):
      result.add(row[1].strVal)

proc buildWhereClause(qb: QueryBuilder, sqlStr: var string, params: var seq[DbValue]) =
  let tableCols = getColumns(qb.tableName)
  var clauses: seq[string] = qb.wheres
  params = qb.params

  # Soft delete filter
  if "deleted_at" in tableCols:
    if qb.onlyTrashedBool:
      clauses.add("deleted_at IS NOT NULL")
    elif not qb.withTrashedBool:
      clauses.add("deleted_at IS NULL")

  if clauses.len > 0:
    sqlStr.add(" WHERE " & clauses.join(" AND "))

proc get*(qb: QueryBuilder): JsonNode =
  var selectCols = "*"
  if qb.columns.len > 0:
    selectCols = qb.columns.join(", ")

  var sqlStr = "SELECT " & selectCols & " FROM " & qb.tableName

  var finalParams: seq[DbValue] = @[]
  qb.buildWhereClause(sqlStr, finalParams)

  if qb.orderClause.len > 0:
    sqlStr.add(" ORDER BY " & qb.orderClause)

  if qb.limit > -1:
    sqlStr.add(" LIMIT " & $qb.limit)
    if qb.offset > -1:
      sqlStr.add(" OFFSET " & $qb.offset)

  result = newJArray()
  withDB:
    for row in database.getConn().iterate(sqlStr, finalParams):
      var rowJson = newJObject()
      for i in 0 ..< row.len:
        rowJson[row.columns[i]] = valToJson(row[i])
      result.add(rowJson)

proc first*(qb: QueryBuilder): JsonNode =
  qb.limit = 1
  let res = qb.get()
  if res.len > 0:
    return res[0]
  return newJNull()

proc count*(qb: QueryBuilder): int =
  var sqlStr = "SELECT COUNT(*) FROM " & qb.tableName
  var finalParams: seq[DbValue] = @[]
  qb.buildWhereClause(sqlStr, finalParams)

  withDB:
    for row in database.getConn().iterate(sqlStr, finalParams):
      return row[0].intVal
  return 0

proc forceDelete*(qb: QueryBuilder) =
  var sqlStr = "DELETE FROM " & qb.tableName
  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  withDB:
    database.getConn().exec(sqlStr, qb.params)

proc delete*(qb: QueryBuilder) =
  let tableCols = getColumns(qb.tableName)

  if "deleted_at" in tableCols:
    let nowStr = now().utc.format("yyyy-MM-dd HH:mm:ss")
    var sqlStr = "UPDATE " & qb.tableName & " SET deleted_at = ?"
    var vals: seq[DbValue] = @[dbValue(nowStr)]
    vals.add(qb.params)

    if qb.wheres.len > 0:
      sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

    withDB:
      database.getConn().exec(sqlStr, vals)
  else:
    qb.forceDelete()

proc restore*(qb: QueryBuilder) =
  let tableCols = getColumns(qb.tableName)
  if "deleted_at" in tableCols:
    var sqlStr = "UPDATE " & qb.tableName & " SET deleted_at = NULL"
    if qb.wheres.len > 0:
      sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

    withDB:
      database.getConn().exec(sqlStr, qb.params)

proc insert*(qb: QueryBuilder, data: JsonNode): int64 =
  if data.kind != JObject: return 0

  var cols: seq[string] = @[]
  var vals: seq[DbValue] = @[]
  var placeholders: seq[string] = @[]

  let tableCols = getColumns(qb.tableName)
  let nowStr = now().utc.format("yyyy-MM-dd HH:mm:ss")

  # Process columns and values
  for k, v in data:
    cols.add(sanitizeIdentifier(k))
    placeholders.add("?")
    case v.kind
    of JInt: vals.add(dbValue(v.getInt))
    of JString: vals.add(dbValue(v.getStr))
    of JBool: vals.add(dbValue(if v.getBool: 1 else: 0))
    else: vals.add(dbValue($v))

  # Auto-fill timestamps if they exist in schema but not in data
  if "created_at" in tableCols and not data.hasKey("created_at"):
    cols.add("created_at")
    placeholders.add("?")
    vals.add(dbValue(nowStr))

  if "updated_at" in tableCols and not data.hasKey("updated_at"):
    cols.add("updated_at")
    placeholders.add("?")
    vals.add(dbValue(nowStr))

  let sqlStr = "INSERT INTO " & qb.tableName & " (" & cols.join(", ") &
      ") VALUES (" & placeholders.join(", ") & ")"
  withDB:
    database.getConn().exec(sqlStr, vals)
    return database.getConn().lastInsertRowId()

proc update*(qb: QueryBuilder, data: JsonNode) =
  if data.kind != JObject: return

  var sets: seq[string] = @[]
  var vals: seq[DbValue] = @[]

  let tableCols = getColumns(qb.tableName)
  let nowStr = now().utc.format("yyyy-MM-dd HH:mm:ss")

  # Process provided data
  for k, v in data:
    sets.add(sanitizeIdentifier(k) & " = ?")
    case v.kind
    of JInt: vals.add(dbValue(v.getInt))
    of JString: vals.add(dbValue(v.getStr))
    of JBool: vals.add(dbValue(if v.getBool: 1 else: 0))
    else: vals.add(dbValue($v))

  # Auto-fill updated_at if exists in schema and not provided
  if "updated_at" in tableCols and not data.hasKey("updated_at"):
    sets.add("updated_at = ?")
    vals.add(dbValue(nowStr))

  vals.add(qb.params)

  var sqlStr = "UPDATE " & qb.tableName & " SET " & sets.join(", ")
  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  withDB:
    database.getConn().exec(sqlStr, vals)
