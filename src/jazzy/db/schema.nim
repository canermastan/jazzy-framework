import std/[strutils]
import tiny_sqlite
import database, builder

type
  ColumnDef = object
    name: string
    dataType: string
    primaryKey: bool
    autoIncrement: bool
    nullable: bool
    defaultVal: string # "0", "'text'", "NULL", etc.

  SchemaBuilder* = ref object
    tableName: string
    columns: seq[ColumnDef]
    ifNotExists: bool

proc createTable*(name: string): SchemaBuilder =
  new(result)
  result.tableName = sanitizeIdentifier(name)
  result.columns = @[]
  result.ifNotExists = true

proc ifNotExists*(sb: SchemaBuilder, val: bool = true): SchemaBuilder =
  sb.ifNotExists = val
  return sb

proc increments*(sb: SchemaBuilder, name: string): SchemaBuilder =
  sb.columns.add(ColumnDef(
    name: sanitizeIdentifier(name),
    dataType: "INTEGER",
    primaryKey: true,
    autoIncrement: true,
    nullable: false
  ))
  return sb

proc string*(sb: SchemaBuilder, name: string, length = 0, nullable = false,
    default = ""): SchemaBuilder =
  var d = if default.len > 0: "'" & default & "'" else: ""
  let typeStr = if length > 0: "TEXT(" & $length & ")" else: "TEXT"
  sb.columns.add(ColumnDef(
    name: sanitizeIdentifier(name),
    dataType: typeStr,
    nullable: nullable,
    defaultVal: d
  ))
  return sb

proc integer*(sb: SchemaBuilder, name: string, nullable = false,
    default = 0): SchemaBuilder =
  sb.columns.add(ColumnDef(
    name: sanitizeIdentifier(name),
    dataType: "INTEGER",
    nullable: nullable,
    defaultVal: $default
  ))
  return sb

proc boolean*(sb: SchemaBuilder, name: string, nullable = false,
    default = false): SchemaBuilder =
  let d = if default: "1" else: "0"
  sb.columns.add(ColumnDef(
    name: sanitizeIdentifier(name),
    dataType: "INTEGER",
    nullable: nullable,
    defaultVal: d
  ))
  return sb

proc timestamp*(sb: SchemaBuilder, name: string, nullable = false,
    default = ""): SchemaBuilder =
  var d = default
  if d.toUpperAscii == "CURRENT_TIMESTAMP":
    d = "CURRENT_TIMESTAMP"
  elif d.len > 0:
    d = "'" & d & "'"
    
  sb.columns.add(ColumnDef(
    name: sanitizeIdentifier(name),
    dataType: "DATETIME",
    nullable: nullable,
    defaultVal: d
  ))
  return sb

proc timestamps*(sb: SchemaBuilder): SchemaBuilder =
  discard sb.timestamp("created_at", default = "CURRENT_TIMESTAMP")
  discard sb.timestamp("updated_at", default = "CURRENT_TIMESTAMP")
  return sb

proc softDeletes*(sb: SchemaBuilder): SchemaBuilder =
  discard sb.timestamp("deleted_at", nullable = true)
  return sb

proc execute*(sb: SchemaBuilder) =
  var sqlParts: seq[string] = @[]

  for col in sb.columns:
    var line = col.name & " " & col.dataType

    if col.primaryKey:
      line.add(" PRIMARY KEY")

    if col.autoIncrement:
      line.add(" AUTOINCREMENT")

    if not col.nullable and not col.primaryKey:
      line.add(" NOT NULL")

    if col.defaultVal.len > 0:
      line.add(" DEFAULT " & col.defaultVal)

    sqlParts.add(line)

  var sql = "CREATE TABLE "
  if sb.ifNotExists:
    sql.add("IF NOT EXISTS ")

  sql.add(sb.tableName & " (\n  " & sqlParts.join(",\n  ") & "\n)")

  withDB:
    database.getConn().exec(sql)
