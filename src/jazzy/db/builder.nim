import std/[json, strutils]
import tiny_sqlite
import database

type
  QueryBuilder* = ref object
    tableName: string
    wheres: seq[string]
    limit: int
    params: seq[DbValue]

  DatabaseHelper* = object

var DB*: DatabaseHelper

proc makeDbValue(v: string): DbValue = DbValue(kind: sqliteText, strVal: v)
proc makeDbValue(v: int): DbValue = DbValue(kind: sqliteInteger, intVal: v)

# Builder Methods
proc table*(db: DatabaseHelper, name: string): QueryBuilder =
  new(result)
  result.tableName = name
  result.wheres = @[]
  result.params = @[]
  result.limit = -1

proc where*(qb: QueryBuilder, col: string, val: string): QueryBuilder =
  qb.wheres.add(col & " = ?")
  qb.params.add(makeDbValue(val))
  return qb

proc where*(qb: QueryBuilder, col: string, val: int): QueryBuilder =
  qb.wheres.add(col & " = ?")
  qb.params.add(makeDbValue(val))
  return qb

proc where*(qb: QueryBuilder, col: string, op: string,
    val: string): QueryBuilder =
  qb.wheres.add(col & " " & op & " ?")
  qb.params.add(makeDbValue(val))
  return qb

proc limit*(qb: QueryBuilder, n: int): QueryBuilder =
  qb.limit = n
  return qb

proc valToJson(val: DbValue): JsonNode =
  case val.kind
  of sqliteInteger: return %val.intVal
  of sqliteReal: return %val.floatVal
  of sqliteText: return %val.strVal
  of sqliteBlob: return %"<blob>"
  of sqliteNull: return newJNull()

proc getColumns(tableName: string): seq[string] =
  result = @[]
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
  for row in database.getConn().iterate(sqlStr, qb.params):
    var rowJson = newJObject()
    # row is indexed 0..cols.len
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

  # Execute one row, first column
  for row in database.getConn().iterate(sqlStr, qb.params):
    return row[0].intVal
  return 0

proc delete*(qb: QueryBuilder) =
  var sqlStr = "DELETE FROM " & qb.tableName
  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  database.getConn().exec(sqlStr, qb.params)

proc insert*(qb: QueryBuilder, data: JsonNode): int64 =
  if data.kind != JObject: return 0

  var cols: seq[string] = @[]
  var vals: seq[DbValue] = @[]
  var placeholders: seq[string] = @[]

  for k, v in data:
    cols.add(k)
    placeholders.add("?")
    case v.kind
    of JInt: vals.add(makeDbValue(v.getInt))
    of JString: vals.add(makeDbValue(v.getStr))
    of JBool: vals.add(makeDbValue(if v.getBool: 1 else: 0))
    else: vals.add(makeDbValue($v))

  let sqlStr = "INSERT INTO " & qb.tableName & " (" & cols.join(", ") &
      ") VALUES (" & placeholders.join(", ") & ")"
  database.getConn().exec(sqlStr, vals)
  return database.getConn().lastInsertRowId()

proc update*(qb: QueryBuilder, data: JsonNode) =
  if data.kind != JObject: return

  var sets: seq[string] = @[]
  var vals: seq[DbValue] = @[]

  for k, v in data:
    sets.add(k & " = ?")
    case v.kind
    of JInt: vals.add(makeDbValue(v.getInt))
    of JString: vals.add(makeDbValue(v.getStr))
    of JBool: vals.add(makeDbValue(if v.getBool: 1 else: 0))
    else: vals.add(makeDbValue($v))

  vals.add(qb.params)

  var sqlStr = "UPDATE " & qb.tableName & " SET " & sets.join(", ")
  if qb.wheres.len > 0:
    sqlStr.add(" WHERE " & qb.wheres.join(" AND "))

  database.getConn().exec(sqlStr, vals)
