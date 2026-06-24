import std/[json, strutils]

proc isNull*(node: JsonNode): bool =
  ## Checks if a JsonNode itself is nil or JNull
  node.isNil or node.kind == JNull

proc isNull*(node: JsonNode, key: string): bool =
  ## Checks if a key does not exist or its value is JNull
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return true
  return node[key].kind == JNull

proc has*(node: JsonNode, key: string): bool =
  ## Checks if a key exists and is not null
  if node.isNil or node.kind != JObject: return false
  return node.hasKey(key) and node[key].kind != JNull

proc getString*(node: JsonNode, key: string, default: string = ""): string =
  ## Gets a string value, safely falling back to default if missing or invalid
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return default
  let val = node[key]
  case val.kind
  of JString: return val.getStr()
  of JInt: return $val.getInt()
  of JFloat: return $val.getFloat()
  of JBool: return $val.getBool()
  of JNull: return default
  else: return $val

proc getInt*(node: JsonNode, key: string, default: int = 0): int =
  ## Gets an integer value, converting from string if necessary
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return default
  let val = node[key]
  case val.kind
  of JInt: return val.getInt()
  of JFloat: return val.getFloat().toInt()
  of JString:
    try: return parseInt(val.getStr())
    except ValueError: return default
  of JBool: return if val.getBool(): 1 else: 0
  else: return default

proc getFloat*(node: JsonNode, key: string, default: float = 0.0): float =
  ## Gets a float value, converting from string or int if necessary
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return default
  let val = node[key]
  case val.kind
  of JFloat: return val.getFloat()
  of JInt: return val.getInt().toFloat()
  of JString:
    try: return parseFloat(val.getStr())
    except ValueError: return default
  else: return default

proc getBool*(node: JsonNode, key: string, default: bool = false): bool =
  ## Gets a boolean value. Handles "true", "1", "false", "0" correctly.
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return default
  let val = node[key]
  case val.kind
  of JBool: return val.getBool()
  of JInt: return val.getInt() != 0
  of JString:
    let s = val.getStr().toLowerAscii()
    if s == "true" or s == "1": return true
    if s == "false" or s == "0": return false
    return default
  else: return default

proc getArray*(node: JsonNode, key: string): JsonNode =
  ## Gets a JSON Array, returns empty JArray if not found or invalid
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return newJArray()
  let val = node[key]
  if val.kind == JArray: return val
  return newJArray()

proc getObject*(node: JsonNode, key: string): JsonNode =
  ## Gets a JSON Object, returns empty JObject if not found or invalid
  if node.isNil or node.kind != JObject or not node.hasKey(key):
    return newJObject()
  let val = node[key]
  if val.kind == JObject: return val
  return newJObject()
