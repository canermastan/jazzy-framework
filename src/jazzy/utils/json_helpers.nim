import std/[json, macros]

proc toLenient*[T](node: JsonNode, t: typedesc[T]): T =
  ## Deserializes a JsonNode into object T, ignoring missing fields.
  ## Missing fields will retain their default values.
  result = default(T)

  when T is object or T is tuple:
    for key, val in fieldPairs(result):
      if node.hasKey(key):
        try:
          when typeof(val) is bool:
            if node[key].kind == JInt:
              val = node[key].getInt() != 0
            else:
              val = node[key].to(typeof(val))
          else:
            val = node[key].to(typeof(val))
        except JsonKindError:
          discard
  else:
    result = node.to(T)
