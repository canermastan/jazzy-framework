## Jazzy's optional, await-first ORM.
##
## It deliberately builds on the public Jazzy query builder. Models therefore
## share the configured driver, async pool, soft-delete behavior, timestamps,
## identifier safety, and PostgreSQL type handling with DB.table(...).

import std/[asyncdispatch, json, macros, options, sequtils, strutils, tables, times]
import jazzy/db/builder
export json
export tables
export options
export asyncdispatch

type
  ModelQuery*[T] = ref object
    builder: QueryBuilder
    relationNames: seq[string]

  ModelRelationKind* = enum
    relationBelongsTo, relationHasOne, relationHasMany, relationManyToMany

  ModelRelation* = object
    name*: string
    kind*: ModelRelationKind
    localColumn*: string
    relatedTable*: string
    relatedKey*: string
    pivotTable*: string
    pivotLocalKey*: string
    pivotRelatedKey*: string

  Page*[T] = object
    data*: seq[T]
    total*: int
    perPage*: int
    currentPage*: int
    lastPage*: int

const relationCacheKey = "__jazzy_relations"
const ormDateTimeFormat* = "yyyy-MM-dd'T'HH:mm:ss'.'fff"

proc emptyModelJson*(): JsonNode =
  newJObject()

proc ormToJson*(value: string): JsonNode = %value
proc ormToJson*(value: int): JsonNode = %value
proc ormToJson*(value: int64): JsonNode = %value
proc ormToJson*(value: float): JsonNode = %value
proc ormToJson*(value: bool): JsonNode = %value
proc ormToJson*(value: JsonNode): JsonNode = value
proc ormToJson*[T: enum](value: T): JsonNode = %($value)
proc ormToJson*(value: DateTime): JsonNode = %value.format(ormDateTimeFormat)
proc ormToJson*[T](value: Option[T]): JsonNode =
  if value.isSome: ormToJson(value.get()) else: newJNull()

proc ormFromJson*(value: JsonNode, _: typedesc[string]): string =
  case value.kind
  of JNull: ""
  of JString: value.getStr()
  else: $value

proc ormFromJson*(value: JsonNode, _: typedesc[int]): int =
  case value.kind
  of JInt: value.getInt()
  of JFloat: value.getFloat().int
  of JString: parseInt(value.getStr())
  else: 0

proc ormFromJson*(value: JsonNode, _: typedesc[int64]): int64 =
  case value.kind
  of JInt: value.getInt().int64
  of JFloat: value.getFloat().int64
  of JString: parseBiggestInt(value.getStr()).int64
  else: 0'i64

proc ormFromJson*(value: JsonNode, _: typedesc[float]): float =
  case value.kind
  of JFloat: value.getFloat()
  of JInt: value.getInt().float
  of JString: parseFloat(value.getStr())
  else: 0.0

proc ormFromJson*(value: JsonNode, _: typedesc[bool]): bool =
  case value.kind
  of JBool: value.getBool()
  of JInt: value.getInt() != 0
  of JString: value.getStr().toLowerAscii() in ["1", "true", "t", "yes", "on"]
  else: false

proc ormFromJson*(value: JsonNode, _: typedesc[JsonNode]): JsonNode = value
proc ormFromJson*[T: enum](value: JsonNode, _: typedesc[T]): T =
  case value.kind
  of JString:
    try:
      parseEnum[T](value.getStr())
    except ValueError:
      raise newException(ValueError, "Invalid " & $T & " value: " & value.getStr())
  of JInt:
    T(value.getInt())
  else:
    raise newException(ValueError, "Cannot read " & $T & " from database value")

proc ormFromJson*(value: JsonNode, _: typedesc[DateTime]): DateTime =
  if value.kind == JNull:
    raise newException(ValueError, "Cannot read a null DateTime into a non-nullable field")
  let text = if value.kind == JString: value.getStr() else: $value
  for layout in [ormDateTimeFormat, "yyyy-MM-dd HH:mm:ss'.'fff",
      "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"]:
    try:
      return parse(text, layout, utc())
    except TimeParseError:
      discard
  raise newException(ValueError, "Invalid DateTime value: " & text)

proc ormFromJson*[T](value: JsonNode, _: typedesc[Option[T]]): Option[T] =
  if value.kind == JNull: none(T) else: some(ormFromJson(value, T))

proc ormShouldInsertPrimaryKey*(value: string): bool = value.len > 0
proc ormShouldInsertPrimaryKey*(value: int): bool = value != 0
proc ormShouldInsertPrimaryKey*(value: int64): bool = value != 0
proc ormShouldInsertPrimaryKey*(value: float): bool = value != 0.0
proc ormShouldInsertPrimaryKey*(value: bool): bool = value
proc ormShouldInsertPrimaryKey*(value: JsonNode): bool = value.kind != JNull
proc ormShouldInsertPrimaryKey*[T](value: Option[T]): bool = value.isSome

proc ormHasValue*(row: JsonNode, key: string): bool =
  row.kind == JObject and row.hasKey(key) and row[key].kind != JNull

proc modelTableName*[T](model: typedesc[T]): string =
  ## A model declaration generates a typed overload. This fallback makes an
  ## accidental use with a non-model type fail with a useful error.
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelPrimaryKey*[T](model: typedesc[T]): string =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelFromRow*[T](model: typedesc[T], row: JsonNode): T =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelFromCachedRow*[T](model: typedesc[T], row: JsonNode): T =
  ## Typed models override this to restore nested eager-loaded relations.
  modelFromRow(model, row)

proc modelInsertData*[T](value: T): JsonNode =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelUpdateData*[T](value: T): JsonNode =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelDirtyData*[T](value: T): JsonNode =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelIsPersisted*[T](value: T): bool =
  false

proc modelData*[T](value: T): JsonNode =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelCachedRow*[T](value: T): JsonNode =
  ## Typed models override this to preserve their already-loaded relations
  ## while a parent relation is recursively eager-loaded.
  modelData(value)

proc modelColumnName*[T](model: typedesc[T], fieldOrColumn: string): string =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelPatchData*[T](model: typedesc[T], data: JsonNode): JsonNode =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelRelation*[T](model: typedesc[T], name: string): Option[ModelRelation] =
  none(ModelRelation)

proc modelRelationData*[T](value: T, name: string): JsonNode =
  newJNull()

proc modelHasRelationData*[T](value: T, name: string): bool =
  false

proc setModelRelationData*[T](value: var T, name: string, data: JsonNode) =
  raise newException(ValueError, "Type is not a Jazzy model")

proc modelRunBeforeCreate*[T](value: var T) = discard
proc modelRunAfterCreate*[T](value: T) = discard
proc modelRunBeforeUpdate*[T](value: var T) = discard
proc modelRunAfterUpdate*[T](value: T) = discard
proc modelRunBeforeDelete*[T, Id](model: typedesc[T], id: Id) = discard
proc modelRunAfterDelete*[T, Id](model: typedesc[T], id: Id) = discard

type ModelField = object
  name: string
  column: string
  typeSource: string
  primaryKey: bool

type RelationSpec = object
  name: string
  targetType: string
  kind: ModelRelationKind
  foreignKey: string
  localKey: string
  pivotTable: string
  pivotRelatedKey: string

type ScopeSpec = object
  name: string
  body: NimNode

# The model macro emits typed eager-load-path overloads which call this common
# batch loader. Forward declarations keep the generated source independent of
# declaration order inside this module.
proc eagerLoad*[T](models: seq[T], name: string): Future[seq[T]]
proc eagerLoadPath*[T](model: typedesc[T], models: seq[T],
  path: seq[string]): Future[seq[T]]

proc isCommandNamed(node: NimNode, name: string): bool =
  node.kind in {nnkCall, nnkCommand} and node.len >= 1 and
    node[0].kind in {nnkIdent, nnkSym} and node[0].strVal == name

proc normalizeFieldType(typeSource: string): string =
  ## `schema.string` is exported by `import jazzy`, so generated code must
  ## qualify scalar types when they appear in an expression (typedesc input).
  case typeSource
  of "string": "system.string"
  of "int": "system.int"
  of "int64": "system.int64"
  of "float", "float64": "system.float"
  of "bool": "system.bool"
  of "Option[string]": "Option[system.string]"
  of "Option[int]": "Option[system.int]"
  of "Option[int64]": "Option[system.int64]"
  of "Option[float]", "Option[float64]": "Option[system.float]"
  of "Option[bool]": "Option[system.bool]"
  else: typeSource

proc compileModel(typeName, definition: NimNode): NimNode {.compileTime.} =
  if typeName.kind notin {nnkIdent, nnkSym}:
    error("model name must be an identifier", typeName)

  var tableName = ""
  var hasTimestamps = false
  var fields: seq[ModelField]
  var declaredPrimaryKey = ""
  var relations: seq[RelationSpec]
  var scopes: seq[ScopeSpec]

  for statement in definition:
    if isCommandNamed(statement, "table"):
      if statement.len != 2 or statement[1].kind notin {nnkStrLit, nnkTripleStrLit}:
        error("table expects one string literal, for example: table \"users\"", statement)
      if tableName.len > 0:
        error("a model can only declare table once", statement)
      tableName = statement[1].strVal
    elif isCommandNamed(statement, "timestamps"):
      if statement.len != 1:
        error("timestamps takes no arguments", statement)
      if hasTimestamps:
        error("a model can only declare timestamps once", statement)
      hasTimestamps = true
    elif isCommandNamed(statement, "primaryKey"):
      if statement.len != 2 or statement[1].kind notin {nnkStrLit, nnkTripleStrLit}:
        error("primaryKey expects one field name, for example: primaryKey \"uuid\"", statement)
      if declaredPrimaryKey.len > 0:
        error("a model can only declare one primary key", statement)
      declaredPrimaryKey = statement[1].strVal
    elif isCommandNamed(statement, "belongsTo") or isCommandNamed(statement, "hasOne") or
        isCommandNamed(statement, "hasMany") or isCommandNamed(statement, "belongsToMany"):
      if statement.len < 3 or statement[1].kind notin {nnkIdent, nnkSym}:
        error("relations use belongsTo name, Model, foreignKey = \"...\"", statement)
      var relation = RelationSpec(name: statement[1].strVal,
        targetType: statement[2].repr,
        kind: if statement[0].eqIdent("belongsTo"): relationBelongsTo
          elif statement[0].eqIdent("hasOne"): relationHasOne
          elif statement[0].eqIdent("hasMany"): relationHasMany
          else: relationManyToMany)
      for existing in relations:
        if existing.name == relation.name:
          error("duplicate model relation: " & relation.name, statement)
      if statement.len > 3:
        for index in 3 ..< statement.len:
          let modifier = statement[index]
          if modifier.kind != nnkExprEqExpr or modifier.len != 2 or
              modifier[0].kind notin {nnkIdent, nnkSym} or
              modifier[1].kind notin {nnkStrLit, nnkTripleStrLit}:
            error("relation options use foreignKey = \"...\" and relatedKey = \"...\"", modifier)
          let value = modifier[1].strVal
          if modifier[0].eqIdent("foreignKey"):
            relation.foreignKey = value
          elif modifier[0].eqIdent("localKey") or modifier[0].eqIdent("ownerKey"):
            relation.localKey = value
          elif modifier[0].eqIdent("through"):
            relation.pivotTable = value
          elif modifier[0].eqIdent("relatedKey"):
            relation.pivotRelatedKey = value
          else:
            error("unknown relation option: " & modifier[0].strVal, modifier)
      if relation.foreignKey.len == 0:
        error("relations require foreignKey = \"...\"", statement)
      if relation.kind == relationManyToMany and
          (relation.pivotTable.len == 0 or relation.pivotRelatedKey.len == 0):
        error("belongsToMany requires through = \"pivot_table\" and relatedKey = \"...\"", statement)
      relations.add(relation)
    elif isCommandNamed(statement, "scope"):
      if statement.len != 3 or statement[1].kind notin {nnkIdent, nnkSym}:
        error("scopes use scope name: followed by builder calls", statement)
      for existing in scopes:
        if existing.name == statement[1].strVal:
          error("duplicate model scope: " & statement[1].strVal, statement)
      scopes.add(ScopeSpec(name: statement[1].strVal, body: statement[2]))
    elif statement.kind in {nnkCall, nnkCommand} and statement.len >= 2 and
        statement[0].kind in {nnkIdent, nnkSym}:
      let fieldName = statement[0].strVal
      if fieldName in ["table", "timestamps", "primaryKey"]:
        error("invalid model declaration", statement)
      for field in fields:
        if field.name == fieldName:
          error("duplicate model field: " & fieldName, statement)
      var columnName = fieldName
      var isPrimaryKey = false
      if statement.len > 2:
        for index in 2 ..< statement.len:
          let modifier = statement[index]
          if modifier.kind != nnkExprEqExpr or modifier.len != 2 or
              modifier[0].kind notin {nnkIdent, nnkSym}:
            error("model field options use column = \"...\" or primaryKey = true", modifier)
          if modifier[0].eqIdent("column"):
            if modifier[1].kind notin {nnkStrLit, nnkTripleStrLit}:
              error("column must be a string literal", modifier)
            columnName = modifier[1].strVal
          elif modifier[0].eqIdent("primaryKey"):
            if modifier[1].kind != nnkIdent or not modifier[1].eqIdent("true"):
              error("primaryKey must be true", modifier)
            isPrimaryKey = true
          else:
            error("unknown model field option: " & modifier[0].strVal, modifier)
      fields.add(ModelField(name: fieldName, column: columnName,
        typeSource: normalizeFieldType(statement[1].repr), primaryKey: isPrimaryKey))
    else:
      error("model fields use '<name> <type>', for example: email string", statement)

  if tableName.len == 0:
    error("every model must declare its table, for example: table \"users\"", definition)
  if fields.len == 0:
    error("a model needs at least one field", definition)

  var primaryIndex = -1
  for index, field in fields:
    if field.primaryKey:
      if primaryIndex >= 0:
        error("a model can only declare one primary key", definition)
      primaryIndex = index
    if declaredPrimaryKey.len > 0 and field.name == declaredPrimaryKey:
      if primaryIndex >= 0 and primaryIndex != index:
        error("primaryKey is declared twice", definition)
      primaryIndex = index
  if primaryIndex < 0:
    for index, field in fields:
      if field.name == "id":
        primaryIndex = index
        break
  if primaryIndex < 0:
    error("a model needs an id field or a primaryKey declaration", definition)

  if hasTimestamps:
    for reserved in ["created_at", "updated_at"]:
      for field in fields:
        if field.name == reserved:
          error("timestamps() already creates the '" & reserved & "' field", definition)
      fields.add(ModelField(name: reserved, column: reserved,
        typeSource: "system.string"))

  proc resolveLocalColumn(value: string): string =
    if value.len == 0:
      return fields[primaryIndex].column
    for field in fields:
      if field.name == value or field.column == value:
        return field.column
    error("unknown model field used by relation: " & value, definition)

  let modelName = typeName.strVal
  var source = "type\n  " & modelName & "* = object\n"
  for field in fields:
    source.add("    " & field.name & "*: " & field.typeSource & "\n")
  source.add("    jazzyRelations: Table[system.string, JsonNode]\n")
  source.add("    jazzyOriginal: JsonNode\n")

  source.add("\nproc modelTableName*(model: typedesc[" & modelName & "]): string = \"" &
    tableName.replace("\\", "\\\\").replace("\"", "\\\"") & "\"\n")
  source.add("proc modelPrimaryKey*(model: typedesc[" & modelName & "]): string = \"" &
    fields[primaryIndex].column & "\"\n")
  source.add("proc modelColumnName*(model: typedesc[" & modelName & "], fieldOrColumn: string): string =\n")
  source.add("  case fieldOrColumn:\n")
  for field in fields:
    if field.name == field.column:
      source.add("  of \"" & field.name & "\": \"" & field.column & "\"\n")
    else:
      source.add("  of \"" & field.name & "\", \"" & field.column & "\": \"" & field.column & "\"\n")
  source.add("  else: raise newException(ValueError, \"Unknown " & modelName & " field or column: \" & fieldOrColumn)\n")
  source.add("proc modelRelationData*(value: " & modelName & ", name: string): JsonNode =\n")
  source.add("  if value.jazzyRelations.hasKey(name): value.jazzyRelations[name] else: newJNull()\n")
  source.add("proc modelHasRelationData*(value: " & modelName & ", name: string): bool =\n")
  source.add("  value.jazzyRelations.hasKey(name)\n")
  source.add("proc setModelRelationData*(value: var " & modelName & ", name: string, data: JsonNode) =\n")
  source.add("  value.jazzyRelations[name] = data\n")
  source.add("proc modelIsPersisted*(value: " & modelName & "): bool =\n")
  source.add("  not value.jazzyOriginal.isNil and value.jazzyOriginal.kind == JObject\n")

  let hookPrefix = "jazzy" & modelName
  source.add("var " & hookPrefix & "BeforeCreateHooks: seq[proc(value: var " & modelName & ")]\n")
  source.add("var " & hookPrefix & "AfterCreateHooks: seq[proc(value: " & modelName & ")]\n")
  source.add("var " & hookPrefix & "BeforeUpdateHooks: seq[proc(value: var " & modelName & ")]\n")
  source.add("var " & hookPrefix & "AfterUpdateHooks: seq[proc(value: " & modelName & ")]\n")
  source.add("var " & hookPrefix & "BeforeDeleteHooks: seq[proc(id: " &
    fields[primaryIndex].typeSource & ")]\n")
  source.add("var " & hookPrefix & "AfterDeleteHooks: seq[proc(id: " &
    fields[primaryIndex].typeSource & ")]\n")
  source.add("proc beforeCreate*(model: typedesc[" & modelName & "], hook: proc(value: var " & modelName & ")) =\n")
  source.add("  " & hookPrefix & "BeforeCreateHooks.add(hook)\n")
  source.add("proc afterCreate*(model: typedesc[" & modelName & "], hook: proc(value: " & modelName & ")) =\n")
  source.add("  " & hookPrefix & "AfterCreateHooks.add(hook)\n")
  source.add("proc beforeUpdate*(model: typedesc[" & modelName & "], hook: proc(value: var " & modelName & ")) =\n")
  source.add("  " & hookPrefix & "BeforeUpdateHooks.add(hook)\n")
  source.add("proc afterUpdate*(model: typedesc[" & modelName & "], hook: proc(value: " & modelName & ")) =\n")
  source.add("  " & hookPrefix & "AfterUpdateHooks.add(hook)\n")
  source.add("proc beforeDelete*(model: typedesc[" & modelName & "], hook: proc(id: " & fields[primaryIndex].typeSource & ")) =\n")
  source.add("  " & hookPrefix & "BeforeDeleteHooks.add(hook)\n")
  source.add("proc afterDelete*(model: typedesc[" & modelName & "], hook: proc(id: " & fields[primaryIndex].typeSource & ")) =\n")
  source.add("  " & hookPrefix & "AfterDeleteHooks.add(hook)\n")
  source.add("proc modelRunBeforeCreate*(value: var " & modelName & ") =\n")
  source.add("  for hook in " & hookPrefix & "BeforeCreateHooks: hook(value)\n")
  source.add("proc modelRunAfterCreate*(value: " & modelName & ") =\n")
  source.add("  for hook in " & hookPrefix & "AfterCreateHooks: hook(value)\n")
  source.add("proc modelRunBeforeUpdate*(value: var " & modelName & ") =\n")
  source.add("  for hook in " & hookPrefix & "BeforeUpdateHooks: hook(value)\n")
  source.add("proc modelRunAfterUpdate*(value: " & modelName & ") =\n")
  source.add("  for hook in " & hookPrefix & "AfterUpdateHooks: hook(value)\n")
  source.add("proc modelRunBeforeDelete*(model: typedesc[" & modelName & "], id: " & fields[primaryIndex].typeSource & ") =\n")
  source.add("  for hook in " & hookPrefix & "BeforeDeleteHooks: hook(id)\n")
  source.add("proc modelRunAfterDelete*(model: typedesc[" & modelName & "], id: " & fields[primaryIndex].typeSource & ") =\n")
  source.add("  for hook in " & hookPrefix & "AfterDeleteHooks: hook(id)\n")

  source.add("proc modelFromRow*(model: typedesc[" & modelName & "], row: JsonNode): " & modelName & " =\n")
  for field in fields:
    source.add("  if ormHasValue(row, \"" & field.column & "\"):\n")
    source.add("    result." & field.name & " = ormFromJson(row[\"" & field.column & "\"], " & field.typeSource & ")\n")
  source.add("  result.jazzyOriginal = emptyModelJson()\n")
  for field in fields:
    source.add("  if ormHasValue(row, \"" & field.column & "\"):\n")
    source.add("    result.jazzyOriginal[\"" & field.column & "\"] = ormToJson(result." & field.name & ")\n")

  source.add("proc modelFromCachedRow*(model: typedesc[" & modelName & "], row: JsonNode): " & modelName & " =\n")
  source.add("  result = modelFromRow(model, row)\n")
  source.add("  if row.kind == JObject and row.hasKey(\"" & relationCacheKey & "\") and " &
    "row[\"" & relationCacheKey & "\"].kind == JObject:\n")
  source.add("    for relationName, relationData in row[\"" & relationCacheKey & "\"]:\n")
  source.add("      setModelRelationData(result, relationName, relationData)\n")

  source.add("proc modelData*(value: " & modelName & "): JsonNode =\n")
  source.add("  result = emptyModelJson()\n")
  for field in fields:
    source.add("  result[\"" & field.column & "\"] = ormToJson(value." & field.name & ")\n")

  source.add("proc modelCachedRow*(value: " & modelName & "): JsonNode =\n")
  source.add("  result = modelData(value)\n")
  source.add("  let relationData = emptyModelJson()\n")
  for relation in relations:
    source.add("  if modelHasRelationData(value, \"" & relation.name & "\"):\n")
    source.add("    relationData[\"" & relation.name & "\"] = modelRelationData(value, \"" & relation.name & "\")\n")
  source.add("  if relationData.len > 0:\n")
  source.add("    result[\"" & relationCacheKey & "\"] = relationData\n")

  source.add("proc modelInsertData*(value: " & modelName & "): JsonNode =\n")
  source.add("  result = emptyModelJson()\n")
  for field in fields:
    if hasTimestamps and field.name in ["created_at", "updated_at"]:
      continue
    if field.primaryKey or fields[primaryIndex].name == field.name:
      source.add("  if ormShouldInsertPrimaryKey(value." & field.name & "):\n")
      source.add("    result[\"" & field.column & "\"] = ormToJson(value." & field.name & ")\n")
    else:
      source.add("  result[\"" & field.column & "\"] = ormToJson(value." & field.name & ")\n")

  source.add("proc modelUpdateData*(value: " & modelName & "): JsonNode =\n")
  source.add("  result = emptyModelJson()\n")
  for field in fields:
    if field.name == fields[primaryIndex].name or
        (hasTimestamps and field.name in ["created_at", "updated_at"]):
      continue
    source.add("  result[\"" & field.column & "\"] = ormToJson(value." & field.name & ")\n")

  source.add("proc modelDirtyData*(value: " & modelName & "): JsonNode =\n")
  source.add("  result = emptyModelJson()\n")
  source.add("  if not modelIsPersisted(value): return\n")
  source.add("  let current = modelData(value)\n")
  for field in fields:
    if field.name == fields[primaryIndex].name or
        (hasTimestamps and field.name in ["created_at", "updated_at"]):
      continue
    source.add("  if value.jazzyOriginal.hasKey(\"" & field.column & "\") and " &
      "current[\"" & field.column & "\"] != value.jazzyOriginal[\"" & field.column & "\"]:\n")
    source.add("    result[\"" & field.column & "\"] = current[\"" & field.column & "\"]\n")

  source.add("proc dirty*(value: " & modelName & "): seq[string] =\n")
  source.add("  let current = modelData(value)\n")
  for field in fields:
    if field.name == fields[primaryIndex].name:
      continue
    source.add("  if not modelIsPersisted(value) or (value.jazzyOriginal.hasKey(\"" & field.column &
      "\") and current[\"" & field.column & "\"] != value.jazzyOriginal[\"" & field.column & "\"]):\n")
    source.add("    result.add(\"" & field.name & "\")\n")
  source.add("proc isDirty*(value: " & modelName & ", field = \"\"): bool =\n")
  source.add("  if field.len == 0: return value.dirty().len > 0\n")
  source.add("  let column = modelColumnName(" & modelName & ", field)\n")
  source.add("  if not modelIsPersisted(value): return true\n")
  source.add("  let current = modelData(value)\n")
  source.add("  value.jazzyOriginal.hasKey(column) and current[column] != value.jazzyOriginal[column]\n")
  source.add("proc syncOriginal*(value: var " & modelName & ") =\n")
  source.add("  value.jazzyOriginal = modelData(value)\n")

  source.add("proc modelPatchData*(model: typedesc[" & modelName & "], data: JsonNode): JsonNode =\n")
  source.add("  if data.kind != JObject: raise newException(ValueError, \"Model patch data must be a JSON object\")\n")
  source.add("  result = emptyModelJson()\n")
  source.add("  for key, item in data:\n")
  source.add("    case key:\n")
  for field in fields:
    if field.name == fields[primaryIndex].name or
        (hasTimestamps and field.name in ["created_at", "updated_at"]):
      continue
    if field.name == field.column:
      source.add("    of \"" & field.name & "\": result[\"" & field.column & "\"] = item\n")
    else:
      source.add("    of \"" & field.name & "\", \"" & field.column & "\": result[\"" & field.column & "\"] = item\n")
  source.add("    else: raise newException(ValueError, \"Cannot patch " & modelName & " field: \" & key)\n")

  source.add("proc modelRelation*(model: typedesc[" & modelName & "], name: string): Option[ModelRelation] =\n")
  if relations.len == 0:
    source.add("  none(ModelRelation)\n")
  else:
    source.add("  case name:\n")
    for relation in relations:
      let localColumn = if relation.kind == relationBelongsTo:
        resolveLocalColumn(relation.foreignKey)
      else:
        resolveLocalColumn(relation.localKey)
      let targetPrimary = "modelPrimaryKey(" & relation.targetType & ")"
      let targetTable = "modelTableName(" & relation.targetType & ")"
      let targetForeignKey = "modelColumnName(" & relation.targetType & ", \"" &
        relation.foreignKey & "\")"
      let relatedKey = case relation.kind
        of relationBelongsTo:
          if relation.localKey.len > 0:
            "modelColumnName(" & relation.targetType & ", \"" & relation.localKey & "\")"
          else:
            targetPrimary
        of relationHasOne, relationHasMany:
          targetForeignKey
        of relationManyToMany:
          targetPrimary
      let relationKind = case relation.kind
        of relationBelongsTo: "relationBelongsTo"
        of relationHasOne: "relationHasOne"
        of relationHasMany: "relationHasMany"
        of relationManyToMany: "relationManyToMany"
      source.add("  of \"" & relation.name & "\": some(ModelRelation(name: \"" & relation.name &
        "\", kind: " & relationKind & ", localColumn: \"" & localColumn &
        "\", relatedTable: " & targetTable & ", relatedKey: " & relatedKey &
        ", pivotTable: \"" & relation.pivotTable & "\", pivotLocalKey: \"" &
        relation.foreignKey & "\", pivotRelatedKey: \"" & relation.pivotRelatedKey & "\"))\n")
    source.add("  else: none(ModelRelation)\n")

  for relation in relations:
    let localColumn = if relation.kind == relationBelongsTo:
      resolveLocalColumn(relation.foreignKey)
    else:
      resolveLocalColumn(relation.localKey)
    let targetKey = if relation.kind == relationBelongsTo and relation.localKey.len > 0:
      "modelColumnName(" & relation.targetType & ", \"" & relation.localKey & "\")"
    else:
      "modelPrimaryKey(" & relation.targetType & ")"
    if relation.kind == relationBelongsTo:
      source.add("proc " & relation.name & "*(value: " & modelName & "): Future[Option[" &
        relation.targetType & "]] {.async.} =\n")
      source.add("  if modelHasRelationData(value, \"" & relation.name & "\"):\n")
      source.add("    let cached = modelRelationData(value, \"" & relation.name & "\")\n")
      source.add("    if cached.kind == JNull: return none(" & relation.targetType & ")\n")
      source.add("    return some(modelFromCachedRow(" & relation.targetType & ", cached))\n")
      source.add("  await belongsTo(value, " & relation.targetType & ", \"" & localColumn & "\", " & targetKey & ")\n")
    elif relation.kind == relationHasOne:
      source.add("proc " & relation.name & "*(value: " & modelName & "): Future[Option[" &
        relation.targetType & "]] {.async.} =\n")
      source.add("  if modelHasRelationData(value, \"" & relation.name & "\"):\n")
      source.add("    let cached = modelRelationData(value, \"" & relation.name & "\")\n")
      source.add("    if cached.kind == JNull: return none(" & relation.targetType & ")\n")
      source.add("    return some(modelFromCachedRow(" & relation.targetType & ", cached))\n")
      source.add("  await hasOne(value, " & relation.targetType & ", \"" & localColumn &
        "\", modelColumnName(" & relation.targetType & ", \"" & relation.foreignKey & "\"))\n")
    elif relation.kind == relationHasMany:
      source.add("proc " & relation.name & "*(value: " & modelName & "): Future[seq[" &
        relation.targetType & "]] {.async.} =\n")
      source.add("  if modelHasRelationData(value, \"" & relation.name & "\"):\n")
      source.add("    for row in modelRelationData(value, \"" & relation.name & "\"): result.add(modelFromCachedRow(" & relation.targetType & ", row))\n")
      source.add("    return\n")
      source.add("  await hasMany(value, " & relation.targetType & ", \"" & localColumn &
        "\", modelColumnName(" & relation.targetType & ", \"" & relation.foreignKey & "\"))\n")
    else:
      source.add("proc " & relation.name & "*(value: " & modelName & "): Future[seq[" &
        relation.targetType & "]] {.async.} =\n")
      source.add("  if modelHasRelationData(value, \"" & relation.name & "\"):\n")
      source.add("    for row in modelRelationData(value, \"" & relation.name & "\"): result.add(modelFromCachedRow(" & relation.targetType & ", row))\n")
      source.add("    return\n")
      source.add("  await belongsToMany(value, " & relation.targetType & ", \"" & localColumn &
        "\", \"" & relation.pivotTable & "\", \"" & relation.foreignKey & "\", \"" &
        relation.pivotRelatedKey & "\", modelPrimaryKey(" & relation.targetType & "))\n")

  # Every path segment is eager-loaded in batches. The generated typed
  # overload restores child models from the first segment's cache, loads the
  # remaining path for all children at once, then writes the nested cache back
  # to the parent. That preserves `await user.posts()` / `comments()` DX with
  # no hidden N+1 query after `with("posts.comments")`.
  source.add("proc eagerLoadPath*(model: typedesc[" & modelName & "], models: seq[" &
    modelName & "], path: seq[string]): Future[seq[" & modelName & "]] {.async.} =\n")
  source.add("  if path.len == 0:\n    return models\n")
  source.add("  if modelRelation(model, path[0]).isNone:\n")
  source.add("    raise newException(ValueError, \"Unknown " & modelName &
    " relation: \" & path[0])\n")
  source.add("  result = await eagerLoad(models, path[0])\n")
  source.add("  if path.len == 1:\n    return\n")
  source.add("  let childPath = @path[1 .. ^1]\n")
  source.add("  case path[0]:\n")
  for relation in relations:
    source.add("  of \"" & relation.name & "\":\n")
    source.add("    var children: seq[" & relation.targetType & "]\n")
    if relation.kind in {relationBelongsTo, relationHasOne}:
      source.add("    for parent in result:\n")
      source.add("      let cached = modelRelationData(parent, \"" & relation.name & "\")\n")
      source.add("      if cached.kind != JNull:\n")
      source.add("        children.add(modelFromCachedRow(" & relation.targetType & ", cached))\n")
      source.add("    let loaded = await eagerLoadPath(" & relation.targetType & ", children, childPath)\n")
      source.add("    var childIndex = 0\n")
      source.add("    for index in 0 ..< result.len:\n")
      source.add("      let cached = modelRelationData(result[index], \"" & relation.name & "\")\n")
      source.add("      if cached.kind != JNull:\n")
      source.add("        setModelRelationData(result[index], \"" & relation.name & "\", modelCachedRow(loaded[childIndex]))\n")
      source.add("        inc childIndex\n")
    else:
      source.add("    for parent in result:\n")
      source.add("      for cached in modelRelationData(parent, \"" & relation.name & "\"):\n")
      source.add("        children.add(modelFromCachedRow(" & relation.targetType & ", cached))\n")
      source.add("    let loaded = await eagerLoadPath(" & relation.targetType & ", children, childPath)\n")
      source.add("    var childIndex = 0\n")
      source.add("    for index in 0 ..< result.len:\n")
      source.add("      var nested = newJArray()\n")
      source.add("      for cached in modelRelationData(result[index], \"" & relation.name & "\"):\n")
      source.add("        nested.add(modelCachedRow(loaded[childIndex]))\n")
      source.add("        inc childIndex\n")
      source.add("      setModelRelationData(result[index], \"" & relation.name & "\", nested)\n")
  source.add("  else:\n")
  source.add("    raise newException(ValueError, \"Unknown " & modelName & " relation: \" & path[0])\n")

  for scope in scopes:
    source.add("proc " & scope.name & "*(model: typedesc[" & modelName & "]): ModelQuery[" & modelName & "] =\n")
    source.add("  result = model.query()\n")
    for statement in scope.body:
      if statement.kind notin {nnkCall, nnkCommand} or statement.len < 1 or
          statement[0].kind notin {nnkIdent, nnkSym}:
        error("a scope may only contain query-builder calls", statement)
      let methodName = statement[0].strVal
      if methodName notin ["where", "orWhere", "whereNull", "whereNotNull",
          "orWhereNull", "orWhereNotNull", "whereIn", "whereNotIn",
          "orWhereIn", "orWhereNotIn", "orderBy", "limit", "offset",
          "withTrashed", "onlyTrashed"]:
        error("unsupported scope method: " & methodName, statement)
      var arguments: seq[string]
      for index in 1 ..< statement.len:
        arguments.add(statement[index].repr)
      source.add("  discard result." & methodName & "(" & arguments.join(", ") & ")\n")

  result = parseStmt(source)

macro model*(typeName: untyped, definition: untyped): untyped =
  ## Define a model and its typed query helpers in one compact block.
  result = compileModel(typeName, definition)

proc jsonRelationKey(value: JsonNode): string =
  case value.kind
  of JNull: "<null>"
  of JString: "s:" & value.getStr()
  of JInt: "i:" & $value.getInt()
  of JFloat: "f:" & $value.getFloat()
  of JBool: "b:" & $value.getBool()
  else: "j:" & $value

proc relationColumnValue[T](value: T, column: string): JsonNode =
  mixin modelData
  let data = modelData(value)
  if data.kind != JObject or not data.hasKey(column):
    raise newException(ValueError, "Model does not have relation column: " & column)
  data[column]

proc belongsTo*[T, U](value: T, target: typedesc[U], foreignKey: string,
    ownerKey = ""): Future[Option[U]] {.async.} =
  ## Load one related record from a foreign key on `value`.
  mixin modelTableName, modelPrimaryKey, modelFromRow
  let foreignValue = relationColumnValue(value, foreignKey)
  if foreignValue.kind == JNull:
    return none(U)
  let targetKey = if ownerKey.len > 0: ownerKey else: modelPrimaryKey(target)
  let row = await DB.table(modelTableName(target)).where(targetKey, foreignValue).first()
  if row.kind == JNull: none(U) else: some(modelFromRow(target, row))

proc hasMany*[T, U](value: T, target: typedesc[U], localKey,
    foreignKey: string): Future[seq[U]] {.async.} =
  ## Load every `target` whose foreign key matches `value.localKey`.
  mixin modelTableName, modelFromRow
  let localValue = relationColumnValue(value, localKey)
  if localValue.kind == JNull:
    return @[]
  let rows = await DB.table(modelTableName(target)).where(foreignKey, localValue).get()
  for row in rows:
    result.add(modelFromRow(target, row))

proc hasOne*[T, U](value: T, target: typedesc[U], localKey,
    foreignKey: string): Future[Option[U]] {.async.} =
  ## Load the first `target` whose foreign key matches `value.localKey`.
  ##
  ## `hasOne` deliberately returns `Option[U]`: an absent related record is
  ## normal and must not be confused with a zero-valued model.
  mixin modelTableName, modelFromRow
  let localValue = relationColumnValue(value, localKey)
  if localValue.kind == JNull:
    return none(U)
  let row = await DB.table(modelTableName(target)).where(foreignKey, localValue).first()
  if row.kind == JNull: none(U) else: some(modelFromRow(target, row))

proc belongsToMany*[T, U](value: T, target: typedesc[U], localKey,
    pivotTable, pivotLocalKey, pivotRelatedKey, relatedKey: string): Future[seq[U]] {.async.} =
  ## Load a many-to-many relation through a pivot table without interpolating
  ## user input into SQL structure.
  mixin modelTableName, modelFromRow
  let localValue = relationColumnValue(value, localKey)
  if localValue.kind == JNull:
    return @[]
  let relatedTable = modelTableName(target)
  let sql = "SELECT related.* FROM " & quoteIdentifier(relatedTable) & " AS related " &
    "INNER JOIN " & quoteIdentifier(pivotTable) & " AS pivot ON pivot." &
    quoteIdentifier(pivotRelatedKey) & " = related." & quoteIdentifier(relatedKey) &
    " WHERE pivot." & quoteIdentifier(pivotLocalKey) & " = ?"
  let rows = await DB.raw(sql, localValue)
  for row in rows:
    result.add(modelFromRow(target, row))

proc writableManyToMany[T](value: T, name: string): tuple[
    relation: ModelRelation, localValue: JsonNode] =
  mixin modelRelation
  let definition = modelRelation(T, name)
  if definition.isNone:
    raise newException(ValueError, "Unknown " & $T & " relation: " & name)
  result.relation = definition.get()
  if result.relation.kind != relationManyToMany:
    raise newException(ValueError, "Relation '" & name & "' is not belongsToMany")
  result.localValue = relationColumnValue(value, result.relation.localColumn)
  if result.localValue.kind == JNull:
    raise newException(ValueError,
      "Cannot write a relation for a model with a null local key")

proc attach*[T, Id](value: T, name: string, relatedId: Id): Future[bool] {.async.} =
  ## Attach one existing model to a `belongsToMany` relation.
  ##
  ## The check makes the common call idempotent. Applications which require
  ## cross-process duplicate protection should also create a composite UNIQUE
  ## index on the two pivot columns in their migration.
  let writable = writableManyToMany(value, name)
  let relatedValue = ormToJson(relatedId)
  if relatedValue.kind == JNull:
    raise newException(ValueError, "Cannot attach a null related key")
  let existing = await DB.table(writable.relation.pivotTable)
    .where(writable.relation.pivotLocalKey, writable.localValue)
    .where(writable.relation.pivotRelatedKey, relatedValue).first()
  if existing.kind != JNull:
    return false
  var data = emptyModelJson()
  data[writable.relation.pivotLocalKey] = writable.localValue
  data[writable.relation.pivotRelatedKey] = relatedValue
  let inserted = await DB.table(writable.relation.pivotTable)
    .returning(writable.relation.pivotLocalKey).insert(data)
  inserted.kind != JNull

proc detach*[T, Id](value: T, name: string, relatedId: Id): Future[int] {.async.} =
  ## Detach one related record from a `belongsToMany` relation.
  let writable = writableManyToMany(value, name)
  let relatedValue = ormToJson(relatedId)
  if relatedValue.kind == JNull:
    return 0
  await DB.table(writable.relation.pivotTable)
    .where(writable.relation.pivotLocalKey, writable.localValue)
    .where(writable.relation.pivotRelatedKey, relatedValue).delete()

proc detach*[T](value: T, name: string): Future[int] {.async.} =
  ## Detach every record from a `belongsToMany` relation.
  let writable = writableManyToMany(value, name)
  await DB.table(writable.relation.pivotTable)
    .where(writable.relation.pivotLocalKey, writable.localValue).delete()

proc syncImpl[T, Id](value: T, name: string, relatedIds: seq[Id]): Future[int] {.async.} =
  ## Make a `belongsToMany` relation exactly match `relatedIds`.
  ##
  ## The returned count is the number of pivot rows inserted or removed.
  let writable = writableManyToMany(value, name)
  var requested = initTable[string, JsonNode]()
  for relatedId in relatedIds:
    let relatedValue = ormToJson(relatedId)
    if relatedValue.kind == JNull:
      raise newException(ValueError, "Cannot sync a null related key")
    requested[jsonRelationKey(relatedValue)] = relatedValue

  let current = await DB.table(writable.relation.pivotTable)
    .where(writable.relation.pivotLocalKey, writable.localValue).get()
  var existing = initTable[string, JsonNode]()
  for row in current:
    if not row.hasKey(writable.relation.pivotRelatedKey):
      continue
    let relatedValue = row[writable.relation.pivotRelatedKey]
    let key = jsonRelationKey(relatedValue)
    if requested.hasKey(key):
      existing[key] = relatedValue
    else:
      result += await DB.table(writable.relation.pivotTable)
        .where(writable.relation.pivotLocalKey, writable.localValue)
        .where(writable.relation.pivotRelatedKey, relatedValue).delete()

  for key, relatedValue in requested:
    if not existing.hasKey(key):
      var data = emptyModelJson()
      data[writable.relation.pivotLocalKey] = writable.localValue
      data[writable.relation.pivotRelatedKey] = relatedValue
      let inserted = await DB.table(writable.relation.pivotTable)
        .returning(writable.relation.pivotLocalKey).insert(data)
      if inserted.kind != JNull:
        inc result

proc sync*[T, Id](value: T, name: string, relatedIds: openArray[Id]): Future[int] =
  ## Copy `openArray` before the async state machine retains it.
  syncImpl(value, name, @relatedIds)

proc createRelated*[T, U](value: T, name: string, related: U): Future[U] {.async.} =
  ## Create a related `hasOne` or `hasMany` record and fill its foreign key.
  ## This is the typed equivalent of Laravel's relation `create` helper.
  mixin modelRelation, modelTableName, modelInsertData, modelFromRow
  let definition = modelRelation(T, name)
  if definition.isNone:
    raise newException(ValueError, "Unknown " & $T & " relation: " & name)
  let relation = definition.get()
  if relation.kind notin {relationHasOne, relationHasMany}:
    raise newException(ValueError, "Relation '" & name & "' does not create child records")
  if relation.relatedTable != modelTableName(U):
    raise newException(ValueError, "Related model does not match relation '" & name & "'")
  let localValue = relationColumnValue(value, relation.localColumn)
  if localValue.kind == JNull:
    raise newException(ValueError,
      "Cannot create a relation for a model with a null local key")
  let data = modelInsertData(related)
  data[relation.relatedKey] = localValue
  let row = await DB.table(relation.relatedTable).returning("*").insert(data)
  if row.kind == JNull:
    raise newException(ValueError, "Could not create related " & $U)
  modelFromRow(U, row)

proc eagerLoad*[T](models: seq[T], name: string): Future[seq[T]] {.async.} =
  mixin modelRelation, modelData, setModelRelationData
  result = models
  if result.len == 0:
    return
  let definition = modelRelation(T, name)
  if definition.isNone:
    raise newException(ValueError, "Unknown " & $T & " relation: " & name)
  let relation = definition.get()
  var sourceValues: seq[JsonNode]
  var sourceKeys: seq[string]
  for model in result:
    let value = relationColumnValue(model, relation.localColumn)
    sourceKeys.add(jsonRelationKey(value))
    if value.kind != JNull:
      sourceValues.add(value)

  case relation.kind
  of relationBelongsTo:
    var relatedByKey = initTable[string, JsonNode]()
    if sourceValues.len > 0:
      let rows = await DB.table(relation.relatedTable)
        .whereIn(relation.relatedKey, sourceValues).get()
      for row in rows:
        if row.hasKey(relation.relatedKey):
          relatedByKey[jsonRelationKey(row[relation.relatedKey])] = row
    for index in 0 ..< result.len:
      let key = sourceKeys[index]
      if key != "<null>" and relatedByKey.hasKey(key):
        setModelRelationData(result[index], name, relatedByKey[key])
      else:
        setModelRelationData(result[index], name, newJNull())
  of relationHasOne:
    var relatedByKey = initTable[string, JsonNode]()
    if sourceValues.len > 0:
      let rows = await DB.table(relation.relatedTable)
        .whereIn(relation.relatedKey, sourceValues).get()
      for row in rows:
        if row.hasKey(relation.relatedKey):
          let key = jsonRelationKey(row[relation.relatedKey])
          # A malformed has-one relation can contain more than one row. Keep
          # the first deterministic result; a UNIQUE migration is the right
          # way to enforce the database invariant.
          if not relatedByKey.hasKey(key):
            relatedByKey[key] = row
    for index in 0 ..< result.len:
      let key = sourceKeys[index]
      if key != "<null>" and relatedByKey.hasKey(key):
        setModelRelationData(result[index], name, relatedByKey[key])
      else:
        setModelRelationData(result[index], name, newJNull())
  of relationHasMany:
    var grouped = initTable[string, JsonNode]()
    if sourceValues.len > 0:
      let rows = await DB.table(relation.relatedTable)
        .whereIn(relation.relatedKey, sourceValues).get()
      for row in rows:
        if row.hasKey(relation.relatedKey):
          let key = jsonRelationKey(row[relation.relatedKey])
          if not grouped.hasKey(key):
            grouped[key] = newJArray()
          grouped[key].add(row)
    for index in 0 ..< result.len:
      let key = sourceKeys[index]
      if key != "<null>" and grouped.hasKey(key):
        setModelRelationData(result[index], name, grouped[key])
      else:
        setModelRelationData(result[index], name, newJArray())
  of relationManyToMany:
    var pivotGroups = initTable[string, seq[JsonNode]]()
    var relatedValues: seq[JsonNode]
    if sourceValues.len > 0:
      let pivots = await DB.table(relation.pivotTable)
        .whereIn(relation.pivotLocalKey, sourceValues).get()
      for pivot in pivots:
        if pivot.hasKey(relation.pivotLocalKey) and pivot.hasKey(relation.pivotRelatedKey):
          let sourceKey = jsonRelationKey(pivot[relation.pivotLocalKey])
          if not pivotGroups.hasKey(sourceKey):
            pivotGroups[sourceKey] = @[]
          pivotGroups[sourceKey].add(pivot[relation.pivotRelatedKey])
          relatedValues.add(pivot[relation.pivotRelatedKey])
    var relatedByKey = initTable[string, JsonNode]()
    if relatedValues.len > 0:
      let rows = await DB.table(relation.relatedTable)
        .whereIn(relation.relatedKey, relatedValues).get()
      for row in rows:
        if row.hasKey(relation.relatedKey):
          relatedByKey[jsonRelationKey(row[relation.relatedKey])] = row
    for index in 0 ..< result.len:
      let key = sourceKeys[index]
      var related = newJArray()
      if key != "<null>" and pivotGroups.hasKey(key):
        for relatedValue in pivotGroups[key]:
          let relatedKey = jsonRelationKey(relatedValue)
          if relatedByKey.hasKey(relatedKey):
            related.add(relatedByKey[relatedKey])
      setModelRelationData(result[index], name, related)

proc eagerLoadPath*[T](model: typedesc[T], models: seq[T],
    path: seq[string]): Future[seq[T]] {.async.} =
  ## Fallback for non-model values. `model` declarations generate a typed
  ## overload which performs recursive, batched loading.
  discard model
  discard models
  discard path
  raise newException(ValueError, "Type is not a Jazzy model")

proc query*[T](model: typedesc[T]): ModelQuery[T] =
  mixin modelTableName
  new(result)
  result.builder = DB.table(modelTableName(model))

proc all*[T](model: typedesc[T]): Future[seq[T]] {.async.} =
  await model.query().get()

proc where*[T, V](model: typedesc[T], column: string, value: V): ModelQuery[T] =
  mixin modelColumnName
  result = model.query()
  discard result.builder.where(modelColumnName(model, column), value)

proc where*[T, V](model: typedesc[T], column, operator: string, value: V): ModelQuery[T] =
  mixin modelColumnName
  result = model.query()
  discard result.builder.where(modelColumnName(model, column), operator, value)

proc orWhere*[T, V](model: typedesc[T], column: string, value: V): ModelQuery[T] =
  mixin modelColumnName
  result = model.query()
  discard result.builder.orWhere(modelColumnName(model, column), value)

proc whereNull*[T](model: typedesc[T], column: string): ModelQuery[T] =
  mixin modelColumnName
  result = model.query()
  discard result.builder.whereNull(modelColumnName(model, column))

proc whereNotNull*[T](model: typedesc[T], column: string): ModelQuery[T] =
  mixin modelColumnName
  result = model.query()
  discard result.builder.whereNotNull(modelColumnName(model, column))

proc whereIn*[T, V](model: typedesc[T], column: string,
    values: openArray[V]): ModelQuery[T] =
  mixin modelColumnName
  result = model.query()
  discard result.builder.whereIn(modelColumnName(model, column), values)

proc whereNotIn*[T, V](model: typedesc[T], column: string,
    values: openArray[V]): ModelQuery[T] =
  mixin modelColumnName
  result = model.query()
  discard result.builder.whereNotIn(modelColumnName(model, column), values)

proc where*[T, V](query: ModelQuery[T], column: string, value: V): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.where(modelColumnName(T, column), value)
  query

proc where*[T, V](query: ModelQuery[T], column, operator: string, value: V): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.where(modelColumnName(T, column), operator, value)
  query

proc orWhere*[T, V](query: ModelQuery[T], column: string, value: V): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.orWhere(modelColumnName(T, column), value)
  query

proc orWhere*[T, V](query: ModelQuery[T], column, operator: string,
    value: V): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.orWhere(modelColumnName(T, column), operator, value)
  query

proc whereNull*[T](query: ModelQuery[T], column: string): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.whereNull(modelColumnName(T, column))
  query

proc whereNotNull*[T](query: ModelQuery[T], column: string): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.whereNotNull(modelColumnName(T, column))
  query

proc orWhereNull*[T](query: ModelQuery[T], column: string): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.orWhereNull(modelColumnName(T, column))
  query

proc orWhereNotNull*[T](query: ModelQuery[T], column: string): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.orWhereNotNull(modelColumnName(T, column))
  query

proc whereIn*[T, V](query: ModelQuery[T], column: string, values: openArray[V]): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.whereIn(modelColumnName(T, column), values)
  query

proc whereNotIn*[T, V](query: ModelQuery[T], column: string,
    values: openArray[V]): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.whereNotIn(modelColumnName(T, column), values)
  query

proc orWhereIn*[T, V](query: ModelQuery[T], column: string,
    values: openArray[V]): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.orWhereIn(modelColumnName(T, column), values)
  query

proc orWhereNotIn*[T, V](query: ModelQuery[T], column: string,
    values: openArray[V]): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.orWhereNotIn(modelColumnName(T, column), values)
  query

proc orderBy*[T](query: ModelQuery[T], column: string, direction = "ASC"): ModelQuery[T] =
  mixin modelColumnName
  discard query.builder.orderBy(modelColumnName(T, column), direction)
  query

proc limit*[T](query: ModelQuery[T], value: int): ModelQuery[T] =
  discard query.builder.limit(value)
  query

proc offset*[T](query: ModelQuery[T], value: int): ModelQuery[T] =
  discard query.builder.offset(value)
  query

proc select*[T](query: ModelQuery[T], columns: varargs[string]): ModelQuery[T] =
  mixin modelColumnName
  var mapped: seq[string]
  for column in columns:
    mapped.add(if column == "*": "*" else: modelColumnName(T, column))
  discard query.builder.select(mapped)
  query

proc withTrashed*[T](query: ModelQuery[T]): ModelQuery[T] =
  discard query.builder.withTrashed()
  query

proc onlyTrashed*[T](query: ModelQuery[T]): ModelQuery[T] =
  discard query.builder.onlyTrashed()
  query

proc `with`*[T](query: ModelQuery[T], names: varargs[string]): ModelQuery[T] =
  ## Eager-load declared relations, including dot-separated nested paths.
  ## Root relation names are checked up front so a typo cannot silently turn
  ## into an N+1 query later; typed path loaders validate every child segment.
  mixin modelRelation
  for name in names:
    let path = name.split('.')
    if path.len == 0 or path[0].len == 0 or path.anyIt(it.len == 0):
      raise newException(ValueError, "Invalid eager-load path: " & name)
    if modelRelation(T, path[0]).isNone:
      raise newException(ValueError, "Unknown " & $T & " relation: " & path[0])
    if name notin query.relationNames:
      query.relationNames.add(name)
  query

proc `with`*[T](model: typedesc[T], names: varargs[string]): ModelQuery[T] =
  result = model.query()
  for name in names:
    discard result.`with`(name)

proc get*[T](query: ModelQuery[T]): Future[seq[T]] {.async.} =
  mixin modelFromRow, eagerLoadPath
  let rows = await query.builder.get()
  for row in rows:
    result.add(modelFromRow(T, row))
  for name in query.relationNames:
    result = await eagerLoadPath(T, result, name.split('.'))

proc first*[T](query: ModelQuery[T]): Future[Option[T]] {.async.} =
  mixin modelFromRow, eagerLoadPath
  let row = await query.builder.first()
  if row.kind == JNull:
    return none(T)
  var records = @[modelFromRow(T, row)]
  for name in query.relationNames:
    records = await eagerLoadPath(T, records, name.split('.'))
  some(records[0])

proc count*[T](query: ModelQuery[T]): Future[int] {.async.} =
  await query.builder.count()

proc update*[T](query: ModelQuery[T], value: T): Future[int] {.async.} =
  ## Update every model matched by this query with all writable fields.
  mixin modelUpdateData
  await query.builder.update(modelUpdateData(value))

proc patch*[T](query: ModelQuery[T], data: JsonNode): Future[int] {.async.} =
  ## Update only supplied writable fields on every model matched by this query.
  mixin modelPatchData
  await query.builder.update(modelPatchData(T, data))

proc delete*[T](query: ModelQuery[T]): Future[int] {.async.} =
  await query.builder.delete()

proc forceDelete*[T](query: ModelQuery[T]): Future[int] {.async.} =
  await query.builder.forceDelete()

proc restore*[T](query: ModelQuery[T]): Future[int] {.async.} =
  await query.builder.restore()

proc paginate*[T](query: ModelQuery[T], page = 1, perPage = 15): Future[Page[T]] {.async.} =
  if page < 1:
    raise newException(ValueError, "Page must be at least 1")
  if perPage < 1:
    raise newException(ValueError, "perPage must be at least 1")
  result.total = await query.count()
  result.perPage = perPage
  result.currentPage = page
  result.lastPage = max(1, (result.total + perPage - 1) div perPage)
  discard query.limit(perPage).offset((page - 1) * perPage)
  result.data = await query.get()

proc find*[T, Id](model: typedesc[T], id: Id): Future[Option[T]] {.async.} =
  mixin modelPrimaryKey
  await model.where(modelPrimaryKey(model), id).first()

proc findOrFail*[T, Id](model: typedesc[T], id: Id): Future[T] {.async.} =
  mixin modelPrimaryKey
  let record = await model.find(id)
  if record.isNone:
    raise newException(ValueError, "No " & $T & " found for " & modelPrimaryKey(model))
  record.get()

proc create*[T](model: typedesc[T], value: T): Future[T] {.async.} =
  mixin modelTableName, modelInsertData, modelFromRow, modelRunBeforeCreate,
    modelRunAfterCreate
  var candidate = value
  modelRunBeforeCreate(candidate)
  let row = await DB.table(modelTableName(model)).returning("*").insert(modelInsertData(candidate))
  if row.kind == JNull:
    raise newException(ValueError, "Could not create " & $T)
  result = modelFromRow(model, row)
  modelRunAfterCreate(result)

proc make*[T](model: typedesc[T], build: proc(): T): T =
  ## Build one in-memory model without issuing a query.
  build()

proc make*[T](model: typedesc[T], count: int,
    build: proc(index: int): T): seq[T] =
  ## Build several in-memory models without issuing a query.
  if count < 0:
    raise newException(ValueError, "Factory count cannot be negative")
  for index in 0 ..< count:
    result.add(build(index))

proc factory*[T](model: typedesc[T], build: proc(): T): Future[T] {.async.} =
  ## Build and persist one model. Use `make` for an unsaved value.
  await model.create(build())

proc factory*[T](model: typedesc[T], count: int,
    build: proc(index: int): T): Future[seq[T]] {.async.} =
  ## Build and persist several models in a straightforward, typed loop.
  if count < 0:
    raise newException(ValueError, "Factory count cannot be negative")
  for index in 0 ..< count:
    result.add(await model.create(build(index)))

proc update*[T, Id](model: typedesc[T], id: Id, value: T): Future[Option[T]] {.async.} =
  mixin modelTableName, modelPrimaryKey, modelUpdateData, modelFromRow,
    modelRunBeforeUpdate, modelRunAfterUpdate
  var candidate = value
  modelRunBeforeUpdate(candidate)
  let row = await DB.table(modelTableName(model)).where(modelPrimaryKey(model), id)
    .returning("*").update(modelUpdateData(candidate))
  if row.kind == JNull:
    return none(T)
  let record = modelFromRow(model, row)
  modelRunAfterUpdate(record)
  some(record)

proc patch*[T, Id](model: typedesc[T], id: Id, data: JsonNode): Future[Option[T]] {.async.} =
  ## Apply only the supplied model fields. Keys may use their Nim field name
  ## or mapped database column name; primary and managed timestamp fields are
  ## rejected to prevent accidental identity changes.
  mixin modelTableName, modelPrimaryKey, modelPatchData, modelFromRow
  let row = await DB.table(modelTableName(model)).where(modelPrimaryKey(model), id)
    .returning("*").update(modelPatchData(model, data))
  if row.kind == JNull:
    return none(T)
  some(modelFromRow(model, row))

proc delete*[T, Id](model: typedesc[T], id: Id): Future[int] {.async.} =
  mixin modelTableName, modelPrimaryKey, modelRunBeforeDelete, modelRunAfterDelete
  modelRunBeforeDelete(model, id)
  result = await DB.table(modelTableName(model)).where(modelPrimaryKey(model), id).delete()
  if result > 0:
    modelRunAfterDelete(model, id)

proc save*[T](value: T): Future[T] {.async.} =
  ## Insert a new model or persist only the fields changed on a loaded model.
  ##
  ## Loaded columns are tracked individually, so a model read through
  ## `select(...)` cannot accidentally overwrite columns it did not load.
  ## Nim value objects cannot safely mutate a caller-owned `var` across an
  ## `await`, so save returns the refreshed model: `user = await user.save()`.
  mixin modelIsPersisted, modelDirtyData, modelData, modelTableName,
    modelPrimaryKey, modelInsertData, modelFromRow, modelRunBeforeCreate,
    modelRunAfterCreate, modelRunBeforeUpdate, modelRunAfterUpdate
  if not modelIsPersisted(value):
    var candidate = value
    modelRunBeforeCreate(candidate)
    let row = await DB.table(modelTableName(T)).returning("*").insert(modelInsertData(candidate))
    if row.kind == JNull:
      raise newException(ValueError, "Could not create " & $T)
    result = modelFromRow(T, row)
    modelRunAfterCreate(result)
    return

  if modelDirtyData(value).len == 0:
    return value
  var candidate = value
  modelRunBeforeUpdate(candidate)
  let data = modelDirtyData(candidate)
  if data.len == 0:
    return candidate
  let current = modelData(candidate)
  let primaryKey = modelPrimaryKey(T)
  if not current.hasKey(primaryKey) or current[primaryKey].kind == JNull:
    raise newException(ValueError, "Cannot save a model without its primary key")
  let row = await DB.table(modelTableName(T)).where(primaryKey, current[primaryKey])
    .returning("*").update(data)
  if row.kind == JNull:
    raise newException(ValueError, "Could not save " & $T)
  result = modelFromRow(T, row)
  modelRunAfterUpdate(result)

proc destroy*[T, Id](model: typedesc[T], id: Id): Future[int] {.async.} =
  await model.delete(id)
