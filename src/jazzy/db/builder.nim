## Portable, await-first query builder for Jazzy.
##
## The public API deliberately stays small and Laravel-like.  The builder owns
## SQL generation while the SQLite and PostgreSQL adapters own execution.

import std/[asyncdispatch, json, options, sequtils, strutils, tables]
import tiny_sqlite
import database, postgres

type
  ParamKind = enum
    paramInteger, paramReal, paramText, paramBlob, paramNull, paramBoolean

  QueryParam = object
    kind: ParamKind
    intVal: int64
    realVal: float
    textVal: string
    blobVal: seq[byte]
    boolVal: bool

  ColumnInfo = object
    name: string
    dataType: string
    udtName: string

  ConditionKind = enum
    conditionComparison, conditionNull, conditionIn

  Condition = object
    kind: ConditionKind
    connector: string
    column: string
    operator: string
    values: seq[QueryParam]
    negated: bool

  BuiltFilter = object
    sql: string
    parameters: seq[QueryParam]

  SqlStatement = object
    sql: string
    parameters: seq[QueryParam]
    hasId: bool

  QueryBuilder* = ref object
    tableName: string
    conditions: seq[Condition]
    limitValue: int
    offsetValue: int
    columns: seq[string]
    orderColumn: string
    orderDirection: string
    withTrashedBool: bool
    onlyTrashedBool: bool

  DatabaseHelper* = object

  ReturningBuilder* = ref object
    query: QueryBuilder
    columns: seq[string]

var
  DB*: DatabaseHelper
  columnCache {.threadvar.}: Table[string, seq[ColumnInfo]]

proc sanitizeIdentifier*(name: string): string =
  ## Jazzy identifiers are simple, lower-case SQL identifiers.  Restricting
  ## this input keeps identifier interpolation safe; quoting below handles
  ## reserved words such as `order` and `user`.
  if name.len == 0:
    raise newException(ValueError, "SQL identifier cannot be empty")
  for c in name:
    if c notin {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
      raise newException(ValueError, "Invalid SQL identifier: " & name)
  name.toLowerAscii()

proc quoteIdentifier*(name: string): string =
  "\"" & sanitizeIdentifier(name) & "\""

proc quoteSelectedIdentifier(name: string): string =
  if name == "*": "*" else: quoteIdentifier(name)

proc queryParam*(value: string): QueryParam =
  QueryParam(kind: paramText, textVal: value)

proc queryParam*(value: int): QueryParam =
  QueryParam(kind: paramInteger, intVal: value.int64)

proc queryParam*(value: int64): QueryParam =
  QueryParam(kind: paramInteger, intVal: value)

proc queryParam*(value: float): QueryParam =
  QueryParam(kind: paramReal, realVal: value)

proc queryParam*(value: bool): QueryParam =
  QueryParam(kind: paramBoolean, boolVal: value)

proc queryParam*(value: seq[byte]): QueryParam =
  QueryParam(kind: paramBlob, blobVal: value)

proc nullParam*(): QueryParam =
  QueryParam(kind: paramNull)

proc queryParam*(value: DbValue): QueryParam =
  ## Keep raw-query call sites that explicitly used the pre-v0.5 `dbValue`
  ## helper source-compatible while routing them through the portable binder.
  case value.kind
  of sqliteInteger:
    queryParam(value.intVal)
  of sqliteReal:
    queryParam(value.floatVal)
  of sqliteText:
    queryParam(value.strVal)
  of sqliteBlob:
    queryParam(value.blobVal)
  of sqliteNull:
    nullParam()

proc queryParam*(value: JsonNode): QueryParam =
  case value.kind
  of JNull:
    nullParam()
  of JInt:
    queryParam(value.getInt())
  of JFloat:
    queryParam(value.getFloat())
  of JString:
    queryParam(value.getStr())
  of JBool:
    queryParam(value.getBool())
  of JObject, JArray:
    queryParam($value)

proc toSqlite(value: QueryParam): DbValue =
  case value.kind
  of paramInteger:
    DbValue(kind: sqliteInteger, intVal: value.intVal)
  of paramReal:
    DbValue(kind: sqliteReal, floatVal: value.realVal)
  of paramText:
    DbValue(kind: sqliteText, strVal: value.textVal)
  of paramBlob:
    DbValue(kind: sqliteBlob, blobVal: value.blobVal)
  of paramNull:
    DbValue(kind: sqliteNull)
  of paramBoolean:
    DbValue(kind: sqliteInteger, intVal: if value.boolVal: 1 else: 0)

proc toSqlite(values: seq[QueryParam]): seq[DbValue] =
  for value in values:
    result.add(value.toSqlite())

proc toPostgres(value: QueryParam): PgParam =
  case value.kind
  of paramInteger:
    value.intVal.toPgParam
  of paramReal:
    value.realVal.toPgParam
  of paramText:
    value.textVal.toPgParam
  of paramBlob:
    value.blobVal.toPgParam
  of paramNull:
    none(string).toPgParam
  of paramBoolean:
    value.boolVal.toPgParam

proc toPostgres(values: seq[QueryParam]): seq[PgParam] =
  for value in values:
    result.add(value.toPostgres())

proc valToJson*(val: DbValue): JsonNode =
  case val.kind
  of sqliteInteger: %val.intVal
  of sqliteReal: %val.floatVal
  of sqliteText: %val.strVal
  of sqliteBlob: %"<blob>"
  of sqliteNull: newJNull()

proc postgresPlaceholders*(sql: string): string =
  ## Convert portable `?` placeholders to PostgreSQL `$1`, `$2`, ... .
  ## `??` is a literal question mark, useful for PostgreSQL JSON operators.
  ## Quoted strings, quoted identifiers and comments are left untouched.
  var index = 0
  var i = 0
  var inString = false
  var inIdentifier = false
  var inLineComment = false
  var blockDepth = 0
  var dollarQuoteDelimiter = ""
  while i < sql.len:
    let c = sql[i]
    if dollarQuoteDelimiter.len > 0:
      if i + dollarQuoteDelimiter.len <= sql.len and
          sql[i ..< i + dollarQuoteDelimiter.len] == dollarQuoteDelimiter:
        result.add(dollarQuoteDelimiter)
        i += dollarQuoteDelimiter.len
        dollarQuoteDelimiter = ""
      else:
        result.add(c)
        inc i
    elif inLineComment:
      result.add(c)
      if c == '\n': inLineComment = false
      inc i
    elif blockDepth > 0:
      if c == '/' and i + 1 < sql.len and sql[i + 1] == '*':
        result.add("/*")
        inc blockDepth
        i += 2
      elif c == '*' and i + 1 < sql.len and sql[i + 1] == '/':
        result.add("*/")
        dec blockDepth
        i += 2
      else:
        result.add(c)
        inc i
    elif inString:
      result.add(c)
      if c == '\\' and i + 1 < sql.len:
        result.add(sql[i + 1])
        i += 2
      elif c == '\'' and i + 1 < sql.len and sql[i + 1] == '\'':
        result.add(sql[i + 1])
        i += 2
      elif c == '\'':
        inString = false
        inc i
      else:
        inc i
    elif inIdentifier:
      result.add(c)
      if c == '"' and i + 1 < sql.len and sql[i + 1] == '"':
        result.add(sql[i + 1])
        i += 2
      elif c == '"':
        inIdentifier = false
        inc i
      else:
        inc i
    elif c == '-' and i + 1 < sql.len and sql[i + 1] == '-':
      result.add("--")
      inLineComment = true
      i += 2
    elif c == '/' and i + 1 < sql.len and sql[i + 1] == '*':
      result.add("/*")
      blockDepth = 1
      i += 2
    elif c == '\'':
      result.add(c)
      inString = true
      inc i
    elif c == '"':
      result.add(c)
      inIdentifier = true
      inc i
    elif c == '$':
      # PostgreSQL dollar-quoted functions/strings may legitimately contain
      # question marks. Recognize $$...$$ and $tag$...$tag$ delimiters.
      var delimiterEnd = i + 1
      while delimiterEnd < sql.len and
          sql[delimiterEnd] in {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
        inc delimiterEnd
      if delimiterEnd < sql.len and sql[delimiterEnd] == '$' and
          (delimiterEnd == i + 1 or sql[i + 1] in {'a'..'z', 'A'..'Z', '_'}):
        dollarQuoteDelimiter = sql[i .. delimiterEnd]
        result.add(dollarQuoteDelimiter)
        i = delimiterEnd + 1
      else:
        result.add(c)
        inc i
    elif c == '?':
      if i + 1 < sql.len and sql[i + 1] == '?':
        result.add('?')
        i += 2
      else:
        inc index
        result.add("$" & $index)
        inc i
    else:
      result.add(c)
      inc i

proc postgresResultToJson(queryResult: QueryResult): JsonNode =
  result = newJArray()
  for row in queryResult:
    var rowJson = newJObject()
    for i, field in queryResult.fields:
      if row.isNull(i):
        rowJson[field.name] = newJNull()
      else:
        case field.typeOid
        of OidBool:
          rowJson[field.name] = %row.get(i, bool)
        of OidInt2:
          rowJson[field.name] = %int(row.get(i, int16))
        of OidInt4:
          rowJson[field.name] = %int(row.get(i, int32))
        of OidInt8:
          rowJson[field.name] = %row.get(i, int64)
        of OidFloat4:
          rowJson[field.name] = %float(row.get(i, float32))
        of OidFloat8:
          rowJson[field.name] = %row.get(i, float64)
        of OidJson, OidJsonb:
          rowJson[field.name] = row.get(i, JsonNode)
        of OidBytea:
          rowJson[field.name] = %"<blob>"
        else:
          rowJson[field.name] = %row.get(i, string)
    result.add(rowJson)

proc clearColumnCache*() =
  columnCache = initTable[string, seq[ColumnInfo]]()
  database.markSqliteSchemaChanged()

proc cacheKey(tableName: string): string =
  $databaseDriver() & ":" & sanitizeIdentifier(tableName)

proc tableInfo(tableName: string): Future[seq[ColumnInfo]] {.async, gcsafe.} =
  {.cast(gcsafe).}:
    ensureDatabaseConfigured()
  let normalizedName = sanitizeIdentifier(tableName)
  let key = cacheKey(normalizedName)
  if columnCache.hasKey(key):
    return columnCache[key]

  case databaseDriver()
  of dbSqlite:
    let sql = "PRAGMA table_info(" & quoteIdentifier(normalizedName) & ")"
    withDB:
      for row in database.getConn().iterate(sql):
        result.add(ColumnInfo(name: row[1].strVal.toLowerAscii(),
          dataType: row[2].strVal.toLowerAscii(), udtName: ""))
  of dbPostgres:
    let db = await postgresForCurrentWorker()
    let queryResult = await db.query("""
      SELECT column_name, data_type, udt_name
      FROM information_schema.columns
      WHERE table_schema = current_schema() AND table_name = $1
      ORDER BY ordinal_position
    """, @[normalizedName.toPgParam])
    for row in queryResult:
      result.add(ColumnInfo(name: row.get(0, string).toLowerAscii(),
        dataType: row.get(1, string).toLowerAscii(),
        udtName: row.get(2, string).toLowerAscii()))
  of dbMySql:
    raise newException(ValueError, "MySQL/MariaDB support is not available yet")
  columnCache[key] = result

proc getColumns*(tableName: string): Future[seq[string]] {.async, gcsafe.} =
  ## Public asynchronous schema lookup retained from the original builder.
  for column in await tableInfo(tableName):
    result.add(column.name)

proc findColumn(columns: seq[ColumnInfo], name: string): ColumnInfo =
  let normalizedName = sanitizeIdentifier(name)
  for column in columns:
    if column.name == normalizedName:
      return column

proc hasColumn(columns: seq[ColumnInfo], name: string): bool =
  let normalizedName = sanitizeIdentifier(name)
  for column in columns:
    if column.name == normalizedName:
      return true

proc postgresTypeCast(column: ColumnInfo): string =
  ## A string URL parameter has PostgreSQL's `text` type.  Adding a cast from
  ## schema metadata means `where("id", ctx.param("id"))` also works for
  ## BIGINT, UUID, booleans, JSON and timestamp columns.
  let typeName = if column.udtName.len > 0: column.udtName else: column.dataType
  case typeName
  of "int2": "smallint"
  of "int4", "integer": "integer"
  of "int8", "bigint": "bigint"
  of "float4", "real": "real"
  of "float8", "double precision": "double precision"
  of "numeric", "decimal": "numeric"
  of "bool", "boolean": "boolean"
  of "uuid": "uuid"
  of "json": "json"
  of "jsonb": "jsonb"
  of "date": "date"
  of "timestamp": "timestamp"
  of "timestamptz", "timestamp with time zone": "timestamptz"
  of "time": "time"
  of "timetz", "time with time zone": "timetz"
  of "bytea": "bytea"
  else: ""

proc placeholderFor(column: ColumnInfo): string =
  if databaseDriver() != dbPostgres:
    return "?"
  let castName = postgresTypeCast(column)
  if castName.len == 0: "?" else: "?::" & castName

proc sanitizeOperator(operator: string): string =
  let normalized = operator.strip().toUpperAscii()
  if normalized notin ["=", "!=", "<>", "<", ">", "<=", ">=", "LIKE"]:
    raise newException(ValueError, "Unsupported SQL comparison operator: " & operator)
  normalized

proc table*(db: DatabaseHelper, name: string): QueryBuilder =
  new(result)
  result.tableName = sanitizeIdentifier(name)
  result.limitValue = -1
  result.offsetValue = -1
  result.orderDirection = "ASC"

proc addComparison[T](qb: QueryBuilder, connector, column, operator: string,
    value: T): QueryBuilder =
  qb.conditions.add(Condition(kind: conditionComparison, connector: connector,
    column: sanitizeIdentifier(column), operator: sanitizeOperator(operator),
    values: @[queryParam(value)]))
  qb

proc where*[T](qb: QueryBuilder, column: string, value: T): QueryBuilder =
  qb.addComparison("AND", column, "=", value)

proc where*[T](qb: QueryBuilder, column, operator: string, value: T): QueryBuilder =
  qb.addComparison("AND", column, operator, value)

proc orWhere*[T](qb: QueryBuilder, column: string, value: T): QueryBuilder =
  qb.addComparison("OR", column, "=", value)

proc orWhere*[T](qb: QueryBuilder, column, operator: string, value: T): QueryBuilder =
  qb.addComparison("OR", column, operator, value)

proc addNull(qb: QueryBuilder, connector, column: string, negated: bool): QueryBuilder =
  qb.conditions.add(Condition(kind: conditionNull, connector: connector,
    column: sanitizeIdentifier(column), negated: negated))
  qb

proc whereNull*(qb: QueryBuilder, column: string): QueryBuilder =
  qb.addNull("AND", column, false)

proc whereNotNull*(qb: QueryBuilder, column: string): QueryBuilder =
  qb.addNull("AND", column, true)

proc orWhereNull*(qb: QueryBuilder, column: string): QueryBuilder =
  qb.addNull("OR", column, false)

proc orWhereNotNull*(qb: QueryBuilder, column: string): QueryBuilder =
  qb.addNull("OR", column, true)

proc addIn[T](qb: QueryBuilder, connector, column: string, values: openArray[T],
    negated: bool): QueryBuilder =
  var params: seq[QueryParam]
  for value in values:
    params.add(queryParam(value))
  qb.conditions.add(Condition(kind: conditionIn, connector: connector,
    column: sanitizeIdentifier(column), values: params, negated: negated))
  qb

proc whereIn*[T](qb: QueryBuilder, column: string, values: openArray[T]): QueryBuilder =
  qb.addIn("AND", column, values, false)

proc whereNotIn*[T](qb: QueryBuilder, column: string, values: openArray[T]): QueryBuilder =
  qb.addIn("AND", column, values, true)

proc orWhereIn*[T](qb: QueryBuilder, column: string, values: openArray[T]): QueryBuilder =
  qb.addIn("OR", column, values, false)

proc orWhereNotIn*[T](qb: QueryBuilder, column: string, values: openArray[T]): QueryBuilder =
  qb.addIn("OR", column, values, true)

proc select*(qb: QueryBuilder, columns: varargs[string]): QueryBuilder =
  for column in columns:
    qb.columns.add(if column == "*": "*" else: sanitizeIdentifier(column))
  qb

proc limit*(qb: QueryBuilder, value: int): QueryBuilder =
  if value < 0:
    raise newException(ValueError, "LIMIT cannot be negative")
  qb.limitValue = value
  qb

proc offset*(qb: QueryBuilder, value: int): QueryBuilder =
  if value < 0:
    raise newException(ValueError, "OFFSET cannot be negative")
  qb.offsetValue = value
  qb

proc orderBy*(qb: QueryBuilder, column: string, direction = "ASC"): QueryBuilder =
  let normalizedDirection = direction.toUpperAscii()
  if normalizedDirection notin ["ASC", "DESC"]:
    raise newException(ValueError, "ORDER BY direction must be ASC or DESC")
  qb.orderColumn = sanitizeIdentifier(column)
  qb.orderDirection = normalizedDirection
  qb

proc withTrashed*(qb: QueryBuilder): QueryBuilder =
  qb.withTrashedBool = true
  qb.onlyTrashedBool = false
  qb

proc onlyTrashed*(qb: QueryBuilder): QueryBuilder =
  qb.onlyTrashedBool = true
  qb.withTrashedBool = false
  qb

proc buildConditions(qb: QueryBuilder, columns: seq[ColumnInfo]): BuiltFilter =
  var fragments: seq[string]
  for condition in qb.conditions:
    var fragment: string
    let column = findColumn(columns, condition.column)
    case condition.kind
    of conditionComparison:
      fragment = quoteIdentifier(condition.column) & " " & condition.operator & " " &
        placeholderFor(column)
      result.parameters.add(condition.values)
    of conditionNull:
      fragment = quoteIdentifier(condition.column) & " IS " &
        (if condition.negated: "NOT NULL" else: "NULL")
    of conditionIn:
      if condition.values.len == 0:
        fragment = if condition.negated: "1 = 1" else: "1 = 0"
      else:
        var placeholders: seq[string]
        for _ in condition.values:
          placeholders.add(placeholderFor(column))
        fragment = quoteIdentifier(condition.column) &
          (if condition.negated: " NOT IN (" else: " IN (") & placeholders.join(", ") & ")"
        result.parameters.add(condition.values)
    if fragments.len == 0:
      fragments.add(fragment)
    else:
      fragments.add(condition.connector & " " & fragment)
  result.sql = fragments.join(" ")

proc buildFilter(qb: QueryBuilder, includeSoftDelete = true): Future[BuiltFilter] {.async, gcsafe.} =
  let columns = await tableInfo(qb.tableName)
  result = qb.buildConditions(columns)
  if includeSoftDelete and columns.hasColumn("deleted_at") and not qb.withTrashedBool:
    let softDelete = quoteIdentifier("deleted_at") & " IS " &
      (if qb.onlyTrashedBool: "NOT NULL" else: "NULL")
    if result.sql.len > 0:
      result.sql = "(" & result.sql & ") AND " & softDelete
    else:
      result.sql = softDelete

proc queryStatement(sql: string, params: seq[QueryParam]): Future[JsonNode] {.async, gcsafe.} =
  {.cast(gcsafe).}:
    ensureDatabaseConfigured()
  case databaseDriver()
  of dbSqlite:
    result = newJArray()
    let sqliteParams = params.toSqlite()
    withDB:
      let schemaSafeSql = database.sqliteSchemaStatement(sql)
      for row in database.getConn().iterate(schemaSafeSql, sqliteParams):
        var rowJson = newJObject()
        for i in 0 ..< row.len:
          rowJson[row.columns[i]] = valToJson(row[i])
        result.add(rowJson)
  of dbPostgres:
    let db = await postgresForCurrentWorker()
    let pgSql = if params.len == 0: sql else: postgresPlaceholders(sql)
    result = postgresResultToJson(await db.query(pgSql, params.toPostgres()))
  of dbMySql:
    raise newException(ValueError, "MySQL/MariaDB support is not available yet")

proc executeStatement(sql: string, params: seq[QueryParam]): Future[int] {.async, gcsafe.} =
  {.cast(gcsafe).}:
    ensureDatabaseConfigured()
  case databaseDriver()
  of dbSqlite:
    let sqliteParams = params.toSqlite()
    withDB:
      let conn = database.getConn()
      conn.exec(database.sqliteSchemaStatement(sql), sqliteParams)
      result = conn.changes()
  of dbPostgres:
    let db = await postgresForCurrentWorker()
    let pgSql = if params.len == 0: sql else: postgresPlaceholders(sql)
    result = int((await db.exec(pgSql, params.toPostgres())).affectedRows())
  of dbMySql:
    raise newException(ValueError, "MySQL/MariaDB support is not available yet")

proc raw*(db: DatabaseHelper, sql: string,
    params: varargs[QueryParam, queryParam]): Future[JsonNode] {.gcsafe.} =
  let queryParams = @params
  queryStatement(sql, queryParams)

proc rawExec*(db: DatabaseHelper, sql: string,
    params: varargs[QueryParam, queryParam]): Future[int] {.gcsafe.} =
  let queryParams = @params
  executeStatement(sql, queryParams)

proc get*(qb: QueryBuilder): Future[JsonNode] {.async, gcsafe.} =
  let selected = if qb.columns.len == 0: "*" else:
    qb.columns.mapIt(quoteSelectedIdentifier(it)).join(", ")
  var sql = "SELECT " & selected & " FROM " & quoteIdentifier(qb.tableName)
  let filter = await qb.buildFilter()
  if filter.sql.len > 0:
    sql.add(" WHERE " & filter.sql)
  if qb.orderColumn.len > 0:
    sql.add(" ORDER BY " & quoteIdentifier(qb.orderColumn) & " " & qb.orderDirection)
  if qb.limitValue >= 0:
    sql.add(" LIMIT " & $qb.limitValue)
  if qb.offsetValue >= 0:
    if qb.limitValue < 0 and databaseDriver() == dbSqlite:
      sql.add(" LIMIT -1")
    sql.add(" OFFSET " & $qb.offsetValue)
  await queryStatement(sql, filter.parameters)

proc first*(qb: QueryBuilder): Future[JsonNode] {.async, gcsafe.} =
  qb.limitValue = 1
  let rows = await qb.get()
  if rows.len > 0: rows[0] else: newJNull()

proc count*(qb: QueryBuilder): Future[int] {.async, gcsafe.} =
  var sql = "SELECT COUNT(*) AS \"jazzy_count\" FROM " & quoteIdentifier(qb.tableName)
  let filter = await qb.buildFilter()
  if filter.sql.len > 0:
    sql.add(" WHERE " & filter.sql)
  let rows = await queryStatement(sql, filter.parameters)
  if rows.len == 0: return 0
  let value = rows[0]["jazzy_count"]
  case value.kind
  of JInt: value.getInt()
  of JString: parseInt(value.getStr())
  else: 0

proc buildInsert(qb: QueryBuilder, data: JsonNode): Future[SqlStatement] {.async, gcsafe.} =
  if data.kind != JObject:
    return
  let tableColumns = await tableInfo(qb.tableName)
  var columns: seq[string]
  var values: seq[string]
  for key, value in data:
    let column = sanitizeIdentifier(key)
    columns.add(quoteIdentifier(column))
    values.add(placeholderFor(tableColumns.findColumn(column)))
    result.parameters.add(queryParam(value))
    if column == "id": result.hasId = true
  if tableColumns.hasColumn("created_at") and not data.hasKey("created_at"):
    columns.add(quoteIdentifier("created_at"))
    values.add("CURRENT_TIMESTAMP")
  if tableColumns.hasColumn("updated_at") and not data.hasKey("updated_at"):
    columns.add(quoteIdentifier("updated_at"))
    values.add("CURRENT_TIMESTAMP")
  if columns.len == 0:
    result.sql = "INSERT INTO " & quoteIdentifier(qb.tableName) & " DEFAULT VALUES"
  else:
    result.sql = "INSERT INTO " & quoteIdentifier(qb.tableName) & " (" &
      columns.join(", ") & ") VALUES (" & values.join(", ") & ")"

proc buildUpdate(qb: QueryBuilder, data: JsonNode): Future[SqlStatement] {.async, gcsafe.} =
  if data.kind != JObject:
    return
  let tableColumns = await tableInfo(qb.tableName)
  var sets: seq[string]
  for key, value in data:
    let column = sanitizeIdentifier(key)
    sets.add(quoteIdentifier(column) & " = " & placeholderFor(tableColumns.findColumn(column)))
    result.parameters.add(queryParam(value))
  if tableColumns.hasColumn("updated_at") and not data.hasKey("updated_at"):
    sets.add(quoteIdentifier("updated_at") & " = CURRENT_TIMESTAMP")
  if sets.len == 0:
    return
  result.sql = "UPDATE " & quoteIdentifier(qb.tableName) & " SET " & sets.join(", ")
  let filter = await qb.buildFilter(includeSoftDelete = false)
  if filter.sql.len > 0:
    result.sql.add(" WHERE " & filter.sql)
    result.parameters.add(filter.parameters)

proc buildForceDelete(qb: QueryBuilder): Future[SqlStatement] {.async, gcsafe.} =
  result.sql = "DELETE FROM " & quoteIdentifier(qb.tableName)
  let filter = await qb.buildFilter(includeSoftDelete = false)
  if filter.sql.len > 0:
    result.sql.add(" WHERE " & filter.sql)
    result.parameters = filter.parameters

proc buildSoftDelete(qb: QueryBuilder): Future[SqlStatement] {.async, gcsafe.} =
  let columns = await tableInfo(qb.tableName)
  if not columns.hasColumn("deleted_at"):
    return await qb.buildForceDelete()
  result.sql = "UPDATE " & quoteIdentifier(qb.tableName) & " SET " &
    quoteIdentifier("deleted_at") & " = CURRENT_TIMESTAMP"
  let filter = await qb.buildFilter(includeSoftDelete = false)
  if filter.sql.len > 0:
    result.sql.add(" WHERE " & filter.sql)
    result.parameters = filter.parameters

proc buildRestore(qb: QueryBuilder): Future[SqlStatement] {.async, gcsafe.} =
  let columns = await tableInfo(qb.tableName)
  if not columns.hasColumn("deleted_at"):
    return
  result.sql = "UPDATE " & quoteIdentifier(qb.tableName) & " SET " &
    quoteIdentifier("deleted_at") & " = NULL"
  let filter = await qb.buildFilter(includeSoftDelete = false)
  if filter.sql.len > 0:
    result.sql.add(" WHERE " & filter.sql)
    result.parameters = filter.parameters

proc insert*(qb: QueryBuilder, data: JsonNode): Future[int64] {.async, gcsafe.} =
  let statement = await qb.buildInsert(data)
  if statement.sql.len == 0: return 0
  case databaseDriver()
  of dbSqlite:
    discard await executeStatement(statement.sql, statement.parameters)
    withDB:
      return database.getConn().lastInsertRowId()
  of dbPostgres:
    let columns = await tableInfo(qb.tableName)
    if statement.hasId or not columns.hasColumn("id"):
      raise newException(ValueError,
        "PostgreSQL insert() needs an implicit numeric id column; use returning(...).insert(...) for explicit or custom primary keys")
    let rows = await queryStatement(statement.sql & " RETURNING " & quoteIdentifier("id"),
      statement.parameters)
    if rows.len == 0 or rows[0]["id"].kind == JNull:
      raise newException(ValueError,
        "PostgreSQL insert() could not return id; use returning(...) for a custom primary key")
    let id = rows[0]["id"]
    if id.kind == JInt: return id.getInt().int64
    try:
      return parseBiggestInt(id.getStr()).int64
    except ValueError:
      raise newException(ValueError,
        "PostgreSQL insert() returned a non-numeric id; use returning(...) instead")
  of dbMySql:
    raise newException(ValueError, "MySQL/MariaDB support is not available yet")

proc update*(qb: QueryBuilder, data: JsonNode): Future[int] {.async, gcsafe.} =
  let statement = await qb.buildUpdate(data)
  if statement.sql.len == 0: return 0
  await executeStatement(statement.sql, statement.parameters)

proc forceDelete*(qb: QueryBuilder): Future[int] {.async, gcsafe.} =
  let statement = await qb.buildForceDelete()
  await executeStatement(statement.sql, statement.parameters)

proc delete*(qb: QueryBuilder): Future[int] {.async, gcsafe.} =
  let statement = await qb.buildSoftDelete()
  await executeStatement(statement.sql, statement.parameters)

proc restore*(qb: QueryBuilder): Future[int] {.async, gcsafe.} =
  let statement = await qb.buildRestore()
  if statement.sql.len == 0: return 0
  await executeStatement(statement.sql, statement.parameters)

proc returning*(qb: QueryBuilder, columns: varargs[string]): ReturningBuilder =
  if columns.len == 0:
    raise newException(ValueError, "returning() requires at least one column")
  new(result)
  result.query = qb
  for column in columns:
    result.columns.add(if column == "*": "*" else: sanitizeIdentifier(column))

proc returningSql(rb: ReturningBuilder): string =
  rb.columns.mapIt(quoteSelectedIdentifier(it)).join(", ")

proc sqliteRows(sql: string, params: seq[DbValue]): JsonNode =
  ## The caller owns dbLock.  Keeping a SQLite RETURNING emulation inside the
  ## same critical section prevents another request from changing
  ## last_insert_rowid() or the selected rows in between its two statements.
  result = newJArray()
  for row in database.getConn().iterate(sql, params):
    var rowJson = newJObject()
    for i in 0 ..< row.len:
      rowJson[row.columns[i]] = valToJson(row[i])
    result.add(rowJson)

proc sqliteReturning(rb: ReturningBuilder, statement: SqlStatement): Future[JsonNode] {.async, gcsafe.} =
  ## tiny_sqlite is linked with a SQLite version which predates RETURNING.
  ## Emulate it with rowids while holding Jazzy's existing connection lock.
  ## Jazzy-created tables are rowid tables, so this retains the same public API
  ## without requiring applications to ship a different SQLite DLL.
  let filter = await rb.query.buildFilter(includeSoftDelete = false)
  let table = quoteIdentifier(rb.query.tableName)
  let selectedColumns = rb.returningSql()
  let sqliteStatementParams = statement.parameters.toSqlite()
  let sqliteFilterParams = filter.parameters.toSqlite()
  withDB:
    let conn = database.getConn()
    if statement.sql.startsWith("INSERT "):
      conn.exec(statement.sql, sqliteStatementParams)
      let rows = sqliteRows("SELECT " & selectedColumns & " FROM " & table &
        " WHERE rowid = last_insert_rowid()", @[])
      if rows.len == 0: result = newJNull() else: result = rows[0]
    else:
      var matchingRows = "SELECT " & selectedColumns & " FROM " & table
      var rowIdSql = "SELECT rowid FROM " & table
      if filter.sql.len > 0:
        matchingRows.add(" WHERE " & filter.sql)
        rowIdSql.add(" WHERE " & filter.sql)

      if statement.sql.startsWith("DELETE "):
        # SQL RETURNING on DELETE exposes the old row values.
        let rows = sqliteRows(matchingRows, sqliteFilterParams)
        conn.exec(statement.sql, sqliteStatementParams)
        if rows.len == 0: result = newJNull() else: result = rows[0]
      else:
        # UPDATE / soft-delete / restore expose values after the mutation.
        var rowIds: seq[DbValue]
        for row in conn.iterate(rowIdSql, sqliteFilterParams):
          rowIds.add(row[0])
        conn.exec(statement.sql, sqliteStatementParams)
        if rowIds.len == 0:
          result = newJNull()
        else:
          let placeholders = repeat("?", rowIds.len).join(", ")
          let rows = sqliteRows("SELECT " & selectedColumns & " FROM " & table &
            " WHERE rowid IN (" & placeholders & ")", rowIds)
          if rows.len == 0: result = newJNull() else: result = rows[0]

proc returningResult(rb: ReturningBuilder, statement: SqlStatement): Future[JsonNode] {.async, gcsafe.} =
  if statement.sql.len == 0: return newJArray()
  if databaseDriver() == dbSqlite:
    return await rb.sqliteReturning(statement)
  let rows = await queryStatement(statement.sql & " RETURNING " & rb.returningSql(),
    statement.parameters)
  if rows.len == 0: newJNull() else: rows[0]

proc insert*(rb: ReturningBuilder, data: JsonNode): Future[JsonNode] {.async, gcsafe.} =
  await rb.returningResult(await rb.query.buildInsert(data))

proc update*(rb: ReturningBuilder, data: JsonNode): Future[JsonNode] {.async, gcsafe.} =
  await rb.returningResult(await rb.query.buildUpdate(data))

proc delete*(rb: ReturningBuilder): Future[JsonNode] {.async, gcsafe.} =
  await rb.returningResult(await rb.query.buildSoftDelete())

proc forceDelete*(rb: ReturningBuilder): Future[JsonNode] {.async, gcsafe.} =
  await rb.returningResult(await rb.query.buildForceDelete())

proc restore*(rb: ReturningBuilder): Future[JsonNode] {.async, gcsafe.} =
  await rb.returningResult(await rb.query.buildRestore())
