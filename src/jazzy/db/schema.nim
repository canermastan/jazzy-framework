## Schema builder shared by SQLite and PostgreSQL.

import std/[asyncdispatch, json, sequtils, strutils]
import database, builder

type
  ColumnKind = enum
    columnIncrement, columnString, columnInteger, columnBigInteger,
    columnBoolean, columnTimestamp

  IndexDef = object
    name: string
    columns: seq[string]
    unique: bool

  ForeignKeyDef = object
    column: string
    referencesColumn: string
    referencesTable: string
    onDelete: string
    onUpdate: string

  ColumnDef = object
    name: string
    kind: ColumnKind
    length: int
    nullable: bool
    defaultValue: string

  SchemaBuilder* = ref object
    tableName: string
    columns: seq[ColumnDef]
    indexes: seq[IndexDef]
    foreignKeys: seq[ForeignKeyDef]
    ifNotExists: bool

  AlterActionKind = enum
    alterAddColumn, alterRenameColumn, alterDropColumn

  AlterAction = object
    kind: AlterActionKind
    column: ColumnDef
    oldName: string
    newName: string

  AlterTableBuilder* = ref object
    tableName: string
    actions: seq[AlterAction]

proc createTable*(name: string): SchemaBuilder =
  new(result)
  result.tableName = sanitizeIdentifier(name)
  result.ifNotExists = true

proc ifNotExists*(sb: SchemaBuilder, value = true): SchemaBuilder =
  sb.ifNotExists = value
  sb

proc increments*(sb: SchemaBuilder, name: string): SchemaBuilder =
  sb.columns.add(ColumnDef(name: sanitizeIdentifier(name), kind: columnIncrement))
  sb

proc string*(sb: SchemaBuilder, name: string, length = 0, nullable = false,
    default = ""): SchemaBuilder =
  sb.columns.add(ColumnDef(name: sanitizeIdentifier(name), kind: columnString,
    length: length, nullable: nullable, defaultValue: default))
  sb

proc integer*(sb: SchemaBuilder, name: string, nullable = false,
    default = 0): SchemaBuilder =
  sb.columns.add(ColumnDef(name: sanitizeIdentifier(name), kind: columnInteger,
    nullable: nullable, defaultValue: $default))
  sb

proc bigInteger*(sb: SchemaBuilder, name: string, nullable = false,
    default = 0'i64): SchemaBuilder =
  sb.columns.add(ColumnDef(name: sanitizeIdentifier(name), kind: columnBigInteger,
    nullable: nullable, defaultValue: $default))
  sb

proc foreignId*(sb: SchemaBuilder, name: string, nullable = false): SchemaBuilder =
  ## Add a BIGINT-compatible foreign-key column. Call `constrained()` after it
  ## to define the referenced table.
  discard sb.bigInteger(name, nullable = nullable)
  sb.foreignKeys.add(ForeignKeyDef(column: sanitizeIdentifier(name),
    referencesColumn: "id"))
  sb

proc lastForeignKey(sb: SchemaBuilder): var ForeignKeyDef =
  if sb.foreignKeys.len == 0:
    raise newException(ValueError, "references()/constrained() requires foreignId() first")
  sb.foreignKeys[^1]

proc references*(sb: SchemaBuilder, column: string): SchemaBuilder =
  sb.lastForeignKey().referencesColumn = sanitizeIdentifier(column)
  sb

proc onTable*(sb: SchemaBuilder, table: string): SchemaBuilder =
  sb.lastForeignKey().referencesTable = sanitizeIdentifier(table)
  sb

proc constrained*(sb: SchemaBuilder, table: string): SchemaBuilder =
  ## `foreignId("user_id").constrained("users")`.
  sb.onTable(table)

proc sanitizeForeignAction(action: string): string =
  let normalized = action.strip().toUpperAscii()
  if normalized notin ["CASCADE", "RESTRICT", "SET NULL", "SET DEFAULT", "NO ACTION"]:
    raise newException(ValueError,
      "Foreign-key action must be CASCADE, RESTRICT, SET NULL, SET DEFAULT, or NO ACTION")
  normalized

proc onDelete*(sb: SchemaBuilder, action: string): SchemaBuilder =
  sb.lastForeignKey().onDelete = sanitizeForeignAction(action)
  sb

proc onUpdate*(sb: SchemaBuilder, action: string): SchemaBuilder =
  sb.lastForeignKey().onUpdate = sanitizeForeignAction(action)
  sb

proc addIndex(sb: SchemaBuilder, columns: openArray[string], unique: bool,
    name = ""): SchemaBuilder =
  if columns.len == 0:
    raise newException(ValueError, "An index needs at least one column")
  var sanitized: seq[string]
  for column in columns:
    sanitized.add(sanitizeIdentifier(column))
  let generatedName = if name.len > 0:
    sanitizeIdentifier(name)
  else:
    sanitizeIdentifier(sb.tableName & "_" & sanitized.join("_") &
      (if unique: "_unique" else: "_index"))
  sb.indexes.add(IndexDef(name: generatedName, columns: sanitized, unique: unique))
  sb

proc index*(sb: SchemaBuilder, columns: varargs[string]): SchemaBuilder =
  sb.addIndex(columns, false)

proc unique*(sb: SchemaBuilder, columns: varargs[string]): SchemaBuilder =
  sb.addIndex(columns, true)

proc boolean*(sb: SchemaBuilder, name: string, nullable = false,
    default = false): SchemaBuilder =
  sb.columns.add(ColumnDef(name: sanitizeIdentifier(name), kind: columnBoolean,
    nullable: nullable, defaultValue: if default: "true" else: "false"))
  sb

proc timestamp*(sb: SchemaBuilder, name: string, nullable = false,
    default = ""): SchemaBuilder =
  sb.columns.add(ColumnDef(name: sanitizeIdentifier(name), kind: columnTimestamp,
    nullable: nullable, defaultValue: default))
  sb

proc timestamps*(sb: SchemaBuilder): SchemaBuilder =
  discard sb.timestamp("created_at", default = "CURRENT_TIMESTAMP")
  discard sb.timestamp("updated_at", default = "CURRENT_TIMESTAMP")
  sb

proc softDeletes*(sb: SchemaBuilder): SchemaBuilder =
  discard sb.timestamp("deleted_at", nullable = true)
  sb

proc columnSql(column: ColumnDef, driver: DatabaseDriver): string =
  case column.kind
  of columnIncrement:
    if driver == dbPostgres:
      return quoteIdentifier(column.name) & " BIGSERIAL PRIMARY KEY"
    return quoteIdentifier(column.name) & " INTEGER PRIMARY KEY AUTOINCREMENT"
  of columnString:
    result = quoteIdentifier(column.name) & " " &
      (if column.length > 0: "VARCHAR(" & $column.length & ")" else: "TEXT")
  of columnInteger:
    result = quoteIdentifier(column.name) & " INTEGER"
  of columnBigInteger:
    result = quoteIdentifier(column.name) & " " &
      (if driver == dbPostgres: "BIGINT" else: "INTEGER")
  of columnBoolean:
    result = quoteIdentifier(column.name) & " " & (if driver == dbPostgres: "BOOLEAN" else: "INTEGER")
  of columnTimestamp:
    result = quoteIdentifier(column.name) & " " & (if driver == dbPostgres: "TIMESTAMP" else: "DATETIME")

  if not column.nullable:
    result.add(" NOT NULL")
  if column.defaultValue.len > 0:
    var value = column.defaultValue
    if column.kind == columnString:
      value = "'" & value.replace("'", "''") & "'"
    elif column.kind == columnBoolean and driver == dbSqlite:
      value = if value == "true": "1" else: "0"
    elif column.kind == columnTimestamp and value.toUpperAscii != "CURRENT_TIMESTAMP":
      value = "'" & value.replace("'", "''") & "'"
    result.add(" DEFAULT " & value)

proc foreignKeySql(foreignKey: ForeignKeyDef): string =
  if foreignKey.referencesTable.len == 0:
    raise newException(ValueError,
      "foreignId(\"" & foreignKey.column & "\") needs constrained(\"table\") or onTable(\"table\")")
  result = "FOREIGN KEY (" & quoteIdentifier(foreignKey.column) & ") REFERENCES " &
    quoteIdentifier(foreignKey.referencesTable) & " (" &
    quoteIdentifier(foreignKey.referencesColumn) & ")"
  if foreignKey.onDelete.len > 0:
    result.add(" ON DELETE " & foreignKey.onDelete)
  if foreignKey.onUpdate.len > 0:
    result.add(" ON UPDATE " & foreignKey.onUpdate)

proc indexSql(tableName: string, index: IndexDef): string =
  let columns = index.columns.mapIt(quoteIdentifier(it)).join(", ")
  "CREATE " & (if index.unique: "UNIQUE " else: "") & "INDEX IF NOT EXISTS " &
    quoteIdentifier(index.name) & " ON " & quoteIdentifier(tableName) & " (" & columns & ")"

proc execute*(sb: SchemaBuilder): Future[void] {.async, gcsafe.} =
  ## Create the table on the database selected by DB_CONNECTION.
  {.cast(gcsafe).}:
    ensureDatabaseConfigured()
  var definitions: seq[string]
  for column in sb.columns:
    definitions.add(column.columnSql(databaseDriver()))
  for foreignKey in sb.foreignKeys:
    definitions.add(foreignKey.foreignKeySql())
  var sql = "CREATE TABLE "
  if sb.ifNotExists:
    sql.add("IF NOT EXISTS ")
  sql.add(quoteIdentifier(sb.tableName) & " (\n  " & definitions.join(",\n  ") & "\n)")
  discard await DB.rawExec(sql)
  for index in sb.indexes:
    discard await DB.rawExec(indexSql(sb.tableName, index))
  clearColumnCache()

proc dropTable*(name: string, ifExists = true): Future[void] {.async, gcsafe.} =
  let table = sanitizeIdentifier(name)
  discard await DB.rawExec("DROP TABLE " & (if ifExists: "IF EXISTS " else: "") &
    quoteIdentifier(table))
  clearColumnCache()

proc renameTable*(fromName, toName: string): Future[void] {.async, gcsafe.} =
  let oldTable = sanitizeIdentifier(fromName)
  let newTable = sanitizeIdentifier(toName)
  discard await DB.rawExec("ALTER TABLE " & quoteIdentifier(oldTable) & " RENAME TO " &
    quoteIdentifier(newTable))
  clearColumnCache()

proc renameColumn*(table, fromName, toName: string): Future[void] {.async, gcsafe.} =
  let tableName = sanitizeIdentifier(table)
  discard await DB.rawExec("ALTER TABLE " & quoteIdentifier(tableName) & " RENAME COLUMN " &
    quoteIdentifier(fromName) & " TO " & quoteIdentifier(toName))
  clearColumnCache()

proc alterTable*(name: string): AlterTableBuilder =
  new(result)
  result.tableName = sanitizeIdentifier(name)

proc addColumn(sb: AlterTableBuilder, column: ColumnDef): AlterTableBuilder =
  sb.actions.add(AlterAction(kind: alterAddColumn, column: column))
  sb

proc addString*(sb: AlterTableBuilder, name: string, length = 0,
    nullable = false, default = ""): AlterTableBuilder =
  sb.addColumn(ColumnDef(name: sanitizeIdentifier(name), kind: columnString,
    length: length, nullable: nullable, defaultValue: default))

proc addInteger*(sb: AlterTableBuilder, name: string, nullable = false,
    default = 0): AlterTableBuilder =
  sb.addColumn(ColumnDef(name: sanitizeIdentifier(name), kind: columnInteger,
    nullable: nullable, defaultValue: $default))

proc addBigInteger*(sb: AlterTableBuilder, name: string, nullable = false,
    default = 0'i64): AlterTableBuilder =
  sb.addColumn(ColumnDef(name: sanitizeIdentifier(name), kind: columnBigInteger,
    nullable: nullable, defaultValue: $default))

proc addBoolean*(sb: AlterTableBuilder, name: string, nullable = false,
    default = false): AlterTableBuilder =
  sb.addColumn(ColumnDef(name: sanitizeIdentifier(name), kind: columnBoolean,
    nullable: nullable, defaultValue: if default: "true" else: "false"))

proc addTimestamp*(sb: AlterTableBuilder, name: string, nullable = false,
    default = ""): AlterTableBuilder =
  sb.addColumn(ColumnDef(name: sanitizeIdentifier(name), kind: columnTimestamp,
    nullable: nullable, defaultValue: default))

proc renameColumn*(sb: AlterTableBuilder, fromName, toName: string): AlterTableBuilder =
  sb.actions.add(AlterAction(kind: alterRenameColumn,
    oldName: sanitizeIdentifier(fromName), newName: sanitizeIdentifier(toName)))
  sb

proc dropColumn*(sb: AlterTableBuilder, name: string): AlterTableBuilder =
  ## Remove a column from an existing table. Put this in a new migration and
  ## restore the old column shape explicitly in its `down:` block if needed.
  sb.actions.add(AlterAction(kind: alterDropColumn,
    oldName: sanitizeIdentifier(name)))
  sb

proc matchingParenthesis(sql: string, openAt: int): int =
  ## Locate the matching closing parenthesis while respecting SQL strings and
  ## quoted identifiers. Schema-builder SQL only uses double-quoted names, but
  ## supporting single quotes here also makes defaults safe to carry through.
  var depth = 0
  var quote = '\0'
  var index = openAt
  while index < sql.len:
    let ch = sql[index]
    if quote != '\0':
      if ch == quote:
        if index + 1 < sql.len and sql[index + 1] == quote:
          index.inc(2)
          continue
        quote = '\0'
    else:
      if ch == '\'' or ch == '"':
        quote = ch
      elif ch == '(':
        depth.inc
      elif ch == ')':
        depth.dec
        if depth == 0:
          return index
    index.inc
  raise newException(ValueError, "Could not parse SQLite CREATE TABLE statement")

proc splitTopLevelDefinitions(sql: string): seq[string] =
  var quote = '\0'
  var depth = 0
  var start = 0
  var index = 0
  while index < sql.len:
    let ch = sql[index]
    if quote != '\0':
      if ch == quote:
        if index + 1 < sql.len and sql[index + 1] == quote:
          index.inc(2)
          continue
        quote = '\0'
    else:
      if ch == '\'' or ch == '"':
        quote = ch
      elif ch == '(':
        depth.inc
      elif ch == ')':
        depth.dec
      elif ch == ',' and depth == 0:
        result.add(sql[start ..< index].strip())
        start = index + 1
    index.inc
  let finalDefinition = sql[start .. ^1].strip()
  if finalDefinition.len > 0:
    result.add(finalDefinition)

proc leadingIdentifier(definition: string): string =
  let value = definition.strip()
  if value.len == 0:
    return
  if value[0] == '"':
    let endQuote = value.find('"', 1)
    if endQuote <= 1:
      raise newException(ValueError, "Could not parse SQLite column identifier")
    return value[1 ..< endQuote]
  for ch in value:
    if ch in {' ', '\t', '\r', '\n', '('}:
      break
    result.add(ch)

proc tableConstraint(definition: string): bool =
  let keyword = leadingIdentifier(definition).toUpperAscii()
  keyword in ["CONSTRAINT", "FOREIGN", "PRIMARY", "UNIQUE", "CHECK"]

proc mentionsColumn(definition, column: string): bool =
  ## Identifiers emitted by Jazzy are quoted. The plain-name check makes an
  ## explicit, reviewed SQLite DDL definition behave sensibly too.
  let lowered = definition.toLowerAscii()
  let quoted = quoteIdentifier(column).toLowerAscii()
  if quoted in lowered:
    return true
  let needle = column.toLowerAscii()
  var start = 0
  while true:
    let found = lowered.find(needle, start)
    if found < 0:
      return false
    let before = if found == 0: '\0' else: lowered[found - 1]
    let afterIndex = found + needle.len
    let after = if afterIndex >= lowered.len: '\0' else: lowered[afterIndex]
    if not (before in {'a'..'z', '0'..'9', '_'}) and
        not (after in {'a'..'z', '0'..'9', '_'}):
      return true
    start = found + needle.len

proc rebuildSqliteWithoutColumn(table, column: string): Future[void] {.async, gcsafe.} =
  ## SQLite installations older than 3.35 do not understand `DROP COLUMN`.
  ## Rebuild the table using its stored CREATE statement so Jazzy keeps the
  ## public schema API portable without asking applications to ship a newer
  ## SQLite DLL. The generated builder's indexes and triggers are restored.
  let schemaRows = await DB.raw(
    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?", table)
  if schemaRows.len != 1 or schemaRows[0]["sql"].kind != JString:
    raise newException(ValueError, "SQLite table not found: " & table)
  let createSql = schemaRows[0]["sql"].getStr()
  let openAt = createSql.find('(')
  if openAt < 0:
    raise newException(ValueError, "Could not parse SQLite CREATE TABLE statement for " & table)
  let closeAt = matchingParenthesis(createSql, openAt)

  let tableInfo = await DB.raw("PRAGMA table_info(" & quoteIdentifier(table) & ")")
  var retainedColumns: seq[string]
  var foundColumn = false
  for field in tableInfo:
    let name = field["name"].getStr()
    if name == column:
      foundColumn = true
      if field["pk"].getInt() != 0:
        raise newException(ValueError,
          "dropColumn cannot remove the SQLite primary key column: " & column)
    else:
      retainedColumns.add(name)
  if not foundColumn:
    raise newException(ValueError, "SQLite column not found: " & table & "." & column)
  if retainedColumns.len == 0:
    raise newException(ValueError, "dropColumn cannot remove the last SQLite column")

  var definitions: seq[string]
  for definition in splitTopLevelDefinitions(createSql[openAt + 1 ..< closeAt]):
    if leadingIdentifier(definition) == column:
      continue
    # Constraints depending on the removed field must disappear with it, just
    # like an engine with native DROP COLUMN removes dependent constraints.
    if tableConstraint(definition) and mentionsColumn(definition, column):
      continue
    definitions.add(definition)

  let temporary = sanitizeIdentifier("jazzy_rebuild_" & table & "_without_" & column)
  let temporaryQuoted = quoteIdentifier(temporary)
  let tableQuoted = quoteIdentifier(table)
  let prefix = createSql[0 ..< openAt].replace(tableQuoted, temporaryQuoted)
  let rebuiltSql = prefix & "(" & definitions.join(", ") & createSql[closeAt .. ^1]

  let indexRows = await DB.raw(
    "SELECT sql FROM sqlite_master WHERE type = 'index' AND tbl_name = ? AND sql IS NOT NULL", table)
  let triggerRows = await DB.raw(
    "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ? AND sql IS NOT NULL", table)

  discard await DB.rawExec("DROP TABLE IF EXISTS " & temporaryQuoted)
  discard await DB.rawExec(rebuiltSql)
  let names = retainedColumns.mapIt(quoteIdentifier(it)).join(", ")
  discard await DB.rawExec("INSERT INTO " & temporaryQuoted & " (" & names & ") SELECT " &
    names & " FROM " & tableQuoted)
  discard await DB.rawExec("DROP TABLE " & tableQuoted)
  discard await DB.rawExec("ALTER TABLE " & temporaryQuoted & " RENAME TO " & tableQuoted)

  for row in indexRows:
    let sql = row["sql"].getStr()
    if not mentionsColumn(sql, column):
      discard await DB.rawExec(sql)
  for row in triggerRows:
    let sql = row["sql"].getStr()
    if not mentionsColumn(sql, column):
      discard await DB.rawExec(sql)

proc execute*(sb: AlterTableBuilder): Future[void] {.async, gcsafe.} =
  {.cast(gcsafe).}:
    ensureDatabaseConfigured()
  let driver = databaseDriver()
  for action in sb.actions:
    case action.kind
    of alterAddColumn:
      discard await DB.rawExec("ALTER TABLE " & quoteIdentifier(sb.tableName) &
        " ADD COLUMN " & action.column.columnSql(driver))
    of alterRenameColumn:
      discard await DB.rawExec("ALTER TABLE " & quoteIdentifier(sb.tableName) &
        " RENAME COLUMN " & quoteIdentifier(action.oldName) & " TO " &
        quoteIdentifier(action.newName))
    of alterDropColumn:
      if driver == dbSqlite:
        await rebuildSqliteWithoutColumn(sb.tableName, action.oldName)
      else:
        discard await DB.rawExec("ALTER TABLE " & quoteIdentifier(sb.tableName) &
          " DROP COLUMN " & quoteIdentifier(action.oldName))
  clearColumnCache()
