import std/[json, strutils, tables, parseutils]
import types
import ../utils/json_helpers

proc parseRules(ruleStr: string): seq[tuple[name: string, args: seq[string]]] =
  result = @[]
  for part in ruleStr.split('|'):
    if part.contains(':'):
      let subParts = part.split(':', 1)
      let name = subParts[0]
      let args = subParts[1].split(',')
      result.add((name, args))
    else:
      result.add((part, @[]))

proc validate*(input: JsonNode, rules: JsonNode): JsonNode =
  var errors = newJObject()
  var hasError = false
  
  if rules.kind != JObject:
    return input

  for field, ruleVal in rules:
    var rulesStr = ruleVal.getStr()
    var parsedRules = parseRules(rulesStr)
    var fieldErrors: seq[string] = @[]
    
    var val: JsonNode = if input.hasKey(field): input[field] else: nil
    
    for rule in parsedRules:
      case rule.name
      of "required":
        if val == nil or val.kind == JNull or (val.kind == JString and val.getStr.len == 0):
          fieldErrors.add(field & " is required")
          break
          
      of "string":
        if val != nil and val.kind != JString:
          fieldErrors.add(field & " must be a string")
          
      of "int":
        if val != nil and val.kind != JInt:
          if val.kind == JString:
             try: discard parseInt(val.getStr); discard
             except: fieldErrors.add(field & " must be an integer")
          else:
             fieldErrors.add(field & " must be an integer")
             
      of "bool":
         if val != nil and val.kind != JBool:
            if val.kind == JInt and (val.getInt == 0 or val.getInt == 1): discard
            else: fieldErrors.add(field & " must be a boolean")

      of "min":
        if val != nil and rule.args.len > 0:
          let minVal = parseInt(rule.args[0])
          if val.kind == JString and val.getStr.len < minVal:
             fieldErrors.add(field & " must be at least " & $minVal & " chars")
          elif val.kind == JInt and val.getInt < minVal:
             fieldErrors.add(field & " must be at least " & $minVal)
             
      of "max":
        if val != nil and rule.args.len > 0:
          let maxVal = parseInt(rule.args[0])
          if val.kind == JString and val.getStr.len > maxVal:
             fieldErrors.add(field & " must not exceed " & $maxVal & " chars")
          elif val.kind == JInt and val.getInt > maxVal:
             fieldErrors.add(field & " must not exceed " & $maxVal)

      of "in":
        if val != nil and rule.args.len > 0:
           let sVal = $val
           let cleanVal = if val.kind == JString: val.getStr else: sVal
           if not rule.args.contains(cleanVal):
             fieldErrors.add(field & " is invalid")

    if fieldErrors.len > 0:
      hasError = true
      errors[field] = %fieldErrors

  if hasError:
    var e = new(ValidationError)
    e.msg = "Validation failed"
    e.errors = errors
    raise e
    
  return input
