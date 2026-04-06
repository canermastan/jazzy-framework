import std/[json, strutils]
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
    params: seq[DbValue]

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

proc raw*(db: DatabaseHelper, sql: string, params: varargs[DbValue, dbValue]): JsonNode =
  result = newJArray()
  let p = @params # Convert varargs to seq
  withDB:
    for row in database.getConn().iterate(sql, p):
      var rowJson = newJObject()
      for i in 0 ..< row.len:
        rowJson[row.columns[i]] = valToJson(row[i])
      result.add(rowJson)

proc rawExec*(db: DatabaseHelper, sql: string, params: varargs[DbValue, dbValue]) =
  let p = @params # Convert varargs to seq
  withDB:
    database.getConn().exec(sql, p)

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

proc getColumns*(tableName: string): seq[string] =
  result = @[]
  withDB:
    for row in database.getConn().iterate("PRAGMA table_info(" & tableName & ")"):
      result.add(row[1].strVal)

proc get*(qb: QueryBuilder): JsonNode =
  var sqlStr = "SELECT * FROM " & qb.tableName

  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  if qb.limit > -1:
    sqlStr.add(" LIMIT " & $qb.limit)

  let cols = getColumns(qb.tableName)

  result = newJArray()
  withDB:
    for row in database.getConn().iterate(sqlStr, qb.params):
      var rowJson = newJObject()
      for i in 0 ..< min(row.len, cols.len):
        rowJson[cols[i]] = valToJson(row[i])
      result.add(rowJson)

proc first*(qb: QueryBuilder): JsonNode =
  qb.limit = 1
  let res = qb.get()
  if res.len > 0:
    return res[0]
  return newJNull()

proc count*(qb: QueryBuilder): int =
  var sqlStr = "SELECT COUNT(*) FROM " & qb.tableName
  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  withDB:
    for row in database.getConn().iterate(sqlStr, qb.params):
      return row[0].intVal
  return 0

proc delete*(qb: QueryBuilder) =
  var sqlStr = "DELETE FROM " & qb.tableName
  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  withDB:
    database.getConn().exec(sqlStr, qb.params)

proc insert*(qb: QueryBuilder, data: JsonNode): int64 =
  if data.kind != JObject: return 0

  var cols: seq[string] = @[]
  var vals: seq[DbValue] = @[]
  var placeholders: seq[string] = @[]

  for k, v in data:
    cols.add(sanitizeIdentifier(k))
    placeholders.add("?")
    case v.kind
    of JInt: vals.add(dbValue(v.getInt))
    of JString: vals.add(dbValue(v.getStr))
    of JBool: vals.add(dbValue(if v.getBool: 1 else: 0))
    else: vals.add(dbValue($v))

  let sqlStr = "INSERT INTO " & qb.tableName & " (" & cols.join(", ") &
      ") VALUES (" & placeholders.join(", ") & ")"
  withDB:
    database.getConn().exec(sqlStr, vals)
    return database.getConn().lastInsertRowId()

proc update*(qb: QueryBuilder, data: JsonNode) =
  if data.kind != JObject: return

  var sets: seq[string] = @[]
  var vals: seq[DbValue] = @[]

  for k, v in data:
    sets.add(sanitizeIdentifier(k) & " = ?")
    case v.kind
    of JInt: vals.add(dbValue(v.getInt))
    of JString: vals.add(dbValue(v.getStr))
    of JBool: vals.add(dbValue(if v.getBool: 1 else: 0))
    else: vals.add(dbValue($v))

  vals.add(qb.params)

  var sqlStr = "UPDATE " & qb.tableName & " SET " & sets.join(", ")
  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  withDB:
    database.getConn().exec(sqlStr, vals)
