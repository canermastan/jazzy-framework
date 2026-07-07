import std/[json, strutils, tables, os]

# Melody template engine — Blade-like syntax, zero external dependencies.
#
# Supported syntax:
#   {{ $variable }}                     HTML-escaped output (XSS-safe)
#   {!! $variable !!}                   Raw/unescaped output
#   @if(var) ... @else ... @endif       Conditional (nestable)
#   @foreach(list as item) ...          Iterate a JSON array (nestable)
#   @endforeach
#   @for($i = 0; $i < N; $i++) ...     C-style counted loop
#   @endfor
#   @include("path/to/partial")         Embed another template inline
#   @extends("layouts/name")            Declare a parent layout (child templates)
#   @section("name") ... @endsection   Define a content block (child templates)
#   @yield("name")                      Emit a content block (layout templates)

type
  ViewError* = object of CatchableError

  # Maps section names to their raw (un-rendered) template content.
  # Used internally during the @extends two-pass render.
  SectionsTable* = Table[string, string]

const
  MAX_BLOCK_DEPTH = 64      ## Hard limit on recursive block nesting
  MAX_LOOP_ITER   = 10_000  ## Hard limit on loop iterations per @foreach/@for

# Public helpers

proc escapeHtml*(s: string): string =
  ## Escapes &, <, >, ", ' — equivalent to PHP's htmlspecialchars(ENT_QUOTES).
  result = newStringOfCap(s.len + (s.len shr 3))
  for c in s:
    case c
    of '&':  result.add("&amp;")
    of '<':  result.add("&lt;")
    of '>':  result.add("&gt;")
    of '"':  result.add("&quot;")
    of '\'': result.add("&#39;")
    else:    result.add(c)

proc resolvePath*(data: JsonNode, path: string): JsonNode =
  ## Walks a dot-separated path (e.g. "user.profile.name") through `data`.
  ## A leading '$' sigil is stripped automatically. Returns JNull for any
  ## missing segment — never raises.
  let start = if path.len > 0 and path[0] == '$': 1 else: 0
  if start >= path.len: return newJNull()
  var current  = data
  var segStart = start
  let n        = path.len
  var k        = start
  while k <= n:
    if k == n or path[k] == '.':
      if k > segStart:
        let key = path[segStart ..< k]
        if current.isNil or current.kind != JObject or not current.hasKey(key):
          return newJNull()
        current = current[key]
      segStart = k + 1
    inc k
  return current

proc resolveVar*(locals, data, globals: JsonNode, path: string): JsonNode =
  let cleanPath = if path.len > 0 and path[0] == '$': path[1..^1] else: path
  if cleanPath == "data": return data

  var res = resolvePath(locals, cleanPath)
  if res.kind != JNull: return res

  res = resolvePath(data, cleanPath)
  if res.kind != JNull: return res

  if not globals.isNil:
    res = resolvePath(globals, cleanPath)
    if res.kind != JNull: return res

  return newJNull()

proc resolveInt*(data: JsonNode, path: string, default: int = 0): int =
  ## Resolves a path and coerces the result to int.
  let n = resolvePath(data, path)
  case n.kind
  of JInt:   return n.getInt()
  of JFloat: return int(n.getFloat())
  of JBool:  return if n.getBool(): 1 else: 0
  else:      return default

proc isTruthy*(node: JsonNode): bool =
  ## Returns false for JNull, false bool, 0, 0.0, "", and empty objects/arrays.
  if node.isNil: return false
  case node.kind
  of JNull:           return false
  of JBool:           return node.getBool()
  of JInt:            return node.getInt() != 0
  of JFloat:          return node.getFloat() != 0.0
  of JString:         return node.getStr().len > 0
  of JObject, JArray: return node.len > 0

# Internal string helpers — no heap allocation, index-span based

proc matchAt(s, prefix: string, pos: int): bool {.inline.} =
  if pos + prefix.len > s.len: return false
  for i in 0 ..< prefix.len:
    if s[pos + i] != prefix[i]: return false
  return true

proc findFrom(s, sub: string, start: int): int {.inline.} =
  ## strutils.find starting from `start`. Returns -1 if not found.
  let sLen   = s.len
  let subLen = sub.len
  if subLen == 0 or start + subLen > sLen: return -1
  for i in start .. sLen - subLen:
    var ok = true
    for j in 0 ..< subLen:
      if s[i + j] != sub[j]: ok = false; break
    if ok: return i
  return -1

proc stripSlice(s: string, a, b: int): (int, int) {.inline.} =
  ## Returns (lo, hi) after trimming ASCII whitespace from s[a..<b].
  var lo = a
  var hi = b - 1
  while lo <= hi and s[lo] in {' ', '\t', '\r', '\n'}: inc lo
  while hi >= lo and s[hi] in {' ', '\t', '\r', '\n'}: dec hi
  return (lo, hi + 1)

proc extractStringArg(tmpl: string, startIdx: int, tagName: string): tuple[name: string, nextPos: int, isLegacy: bool] =
  ## Extracts the string argument from a @tag("argument") or @tag "argument" expression.
  var j = startIdx
  var isLegacy = false
  if j < tmpl.len and tmpl[j] == '(':
    isLegacy = true
    inc j
  else:
    while j < tmpl.len and tmpl[j] in {' ', '\t'}: inc j

  let q1 = findFrom(tmpl, "\"", j)
  if q1 == -1: return (name: "", nextPos: -1, isLegacy: false)
  let q2 = findFrom(tmpl, "\"", q1 + 1)
  if q2 == -1: return (name: "", nextPos: -1, isLegacy: false)
  
  var nextPos = q2 + 1
  if isLegacy:
    let cp = findFrom(tmpl, ")", nextPos)
    if cp == -1: return (name: "", nextPos: -1, isLegacy: true)
    nextPos = cp + 1

  return (name: tmpl[q1 + 1 ..< q2], nextPos: nextPos, isLegacy: isLegacy)

# Layout pre-processing — runs once before the main render pass

proc extractExtends*(tmpl: string): string =
  ## Scans the template for @extends("name") or @extends "name" and returns the layout name.
  ## Returns "" if no @extends directive is found.
  var i = 0
  while i < tmpl.len:
    if matchAt(tmpl, "@extends", i):
      let (name, nextPos, isLegacy) = extractStringArg(tmpl, i + 8, "@extends")
      if nextPos != -1:
        if isLegacy: stderr.writeLine("[Melody Warning] @extends(...) is deprecated. Please use Nim-style `@extends \"...\"` instead.")
        return name
    inc i
  return ""

proc extractSections*(tmpl: string): SectionsTable =
  ## Collects all @section blocks from a child template.
  result = initTable[string, string]()
  var i = 0
  while i < tmpl.len:
    if matchAt(tmpl, "@section", i):
      let (name, afterTag, isLegacy) = extractStringArg(tmpl, i + 8, "@section")
      if name.len == 0 or afterTag == -1: inc i; continue
      if isLegacy: stderr.writeLine("[Melody Warning] @section(...) is deprecated. Please use Nim-style `@section \"...\"` instead.")
      let endIdx = findFrom(tmpl, "@endsection", afterTag)
      if endIdx == -1: inc i; continue
      result[name] = tmpl[afterTag ..< endIdx]
      i = endIdx + "@endsection".len
    else:
      inc i

# Forward declaration for the core recursive renderer

proc renderSpanImpl(tmpl: string, data, globals, locals: JsonNode, spanStart, spanEnd: int,
                    depth: int, viewsDir: string, sections: SectionsTable,
                    res: var string)

# Variable emitter

proc emitVar(tmpl: string, nameA, nameZ: int, data, globals, locals: JsonNode,
             escaped: bool, res: var string) {.inline.} =
  let (a, z) = stripSlice(tmpl, nameA, nameZ)
  if z <= a: return
  let node = resolveVar(locals, data, globals, tmpl[a ..< z])
  case node.kind
  of JNull: discard
  of JString:
    let s = node.getStr()
    if escaped: res.add(escapeHtml(s)) else: res.add(s)
  else:
    let s = $node
    if escaped: res.add(escapeHtml(s)) else: res.add(s)

# Block boundary scanner

type BlockInfo = object
  elsePos:   int  ## Position of @else (-1 if absent)
  endPos:    int  ## Position of the closing tag (-1 = unterminated)
  endTagLen: int

proc scanBlock(tmpl: string, pos: int, openTags: openArray[string], elseTag, closeTag: string): BlockInfo =
  ## Scans forward from `pos` to find the matching closing tag, correctly
  ## tracking nested open/close pairs (e.g. @if inside @if).
  result = BlockInfo(elsePos: -1, endPos: -1, endTagLen: closeTag.len)
  var depth = 1
  var j     = pos
  while j < tmpl.len:
    var matchedOpen = false
    for ot in openTags:
      if matchAt(tmpl, ot, j):
        inc depth; j += ot.len
        matchedOpen = true
        break
    if matchedOpen: continue

    if elseTag.len > 0 and depth == 1 and matchAt(tmpl, elseTag, j):
      result.elsePos = j; j += elseTag.len
    elif matchAt(tmpl, closeTag, j):
      dec depth
      if depth == 0: result.endPos = j; return
      j += closeTag.len
    else:
      inc j

# @for header parser

proc parseForHeader(tmpl: string, a, z: int): tuple[varName: string,
                                                      initVal: int,
                                                      limit:   int,
                                                      step:    int,
                                                      ok:      bool] =
  ## Parses a C-style for header: `$i = 0; $i < 10; $i++`
  ## Supports <, <=, >, >= comparisons and ++, --, +=N, -=N steps.
  let (sa, sz) = stripSlice(tmpl, a, z)
  let parts    = tmpl[sa ..< sz].split(';')
  if parts.len != 3:
    return (varName: "", initVal: 0, limit: 0, step: 0, ok: false)

  let initParts = parts[0].split('=')
  if initParts.len != 2:
    return (varName: "", initVal: 0, limit: 0, step: 0, ok: false)

  let varName = initParts[0].strip().strip(chars = {'$'})
  let initVal = try: parseInt(initParts[1].strip()) except: 0

  var limitOp  = ""
  var limitVal = 0
  let cond     = parts[1].strip()
  for op in ["<=", ">=", "<", ">"]:
    let idx = cond.find(op)
    if idx != -1:
      limitOp  = op
      limitVal = try: parseInt(cond[idx + op.len .. ^1].strip()) except: 0
      break
  if limitOp == "":
    return (varName: "", initVal: 0, limit: 0, step: 0, ok: false)

  let limit = case limitOp
    of "<":  limitVal
    of "<=": limitVal + 1
    of ">":  limitVal
    of ">=": limitVal - 1
    else:    limitVal

  let stepExpr = parts[2].strip()
  var step = 1
  if   stepExpr.endsWith("++"):    step = 1
  elif stepExpr.endsWith("--"):    step = -1
  elif stepExpr.contains("+="):
    let p = stepExpr.split("+="); step =   try: parseInt(p[1].strip()) except: 1
  elif stepExpr.contains("-="):
    let p = stepExpr.split("-="); step = -(try: parseInt(p[1].strip()) except: 1)

  return (varName: varName, initVal: initVal, limit: limit, step: step, ok: true)

# Core recursive renderer

proc resolveViewPath(viewsDir, name: string): string {.inline.} =
  if name.endsWith(".html"): viewsDir / name
  else:                      viewsDir / name & ".html"

proc renderSpanImpl(tmpl: string, data, globals, locals: JsonNode, spanStart, spanEnd: int,
                    depth: int, viewsDir: string, sections: SectionsTable,
                    res: var string) =
  ## Renders tmpl[spanStart..<spanEnd] into `res`.
  ## viewsDir enables @include and @extends. sections is the pre-extracted
  ## content map used to resolve @yield slots.
  if depth > MAX_BLOCK_DEPTH:
    raise newException(ViewError,
      "Template nesting exceeds MAX_BLOCK_DEPTH (" & $MAX_BLOCK_DEPTH & ")")

  var i = spanStart
  while i < spanEnd:

    # @extends("layout") or @extends "layout" — already processed before this call; skip silently.
    if matchAt(tmpl, "@extends", i):
      let (_, nextPos, _) = extractStringArg(tmpl, i + 8, "@extends")
      i = if nextPos != -1: nextPos else: i + 1
      continue

    # @section("name")..@endsection — already extracted; skip silently.
    elif matchAt(tmpl, "@section", i):
      let (_, afterTag, _) = extractStringArg(tmpl, i + 8, "@section")
      if afterTag != -1:
        let endIdx = findFrom(tmpl, "@endsection", afterTag)
        if endIdx != -1:
          i = endIdx + "@endsection".len; continue
      res.add(tmpl[i]); inc i; continue

    # @yield("name") or @yield "name" — emit the matching section content from the child template.
    elif matchAt(tmpl, "@yield", i):
      let (name, nextPos, isLegacy) = extractStringArg(tmpl, i + 6, "@yield")
      if name.len > 0 and nextPos != -1:
        if isLegacy: stderr.writeLine("[Melody Warning] @yield(...) is deprecated. Please use Nim-style `@yield \"...\"` instead.")
        if sections.hasKey(name):
          let sc = sections[name]
          renderSpanImpl(sc, data, globals, locals, 0, sc.len, depth + 1, viewsDir, sections, res)
        i = nextPos; continue
      res.add(tmpl[i]); inc i; continue

    # @include("path") or @include "path" — embed a partial template, rendered with current data.
    elif matchAt(tmpl, "@include", i):
      let (name, nextPos, isLegacy) = extractStringArg(tmpl, i + 8, "@include")
      if name.len > 0 and nextPos != -1:
        if isLegacy: stderr.writeLine("[Melody Warning] @include(...) is deprecated. Please use Nim-style `@include \"...\"` instead.")
        if viewsDir.len == 0:
          raise newException(ViewError,
            "@include requires a viewsDir (use ctx.render instead of renderString)")
        let path = resolveViewPath(viewsDir, name)
        if not fileExists(path):
          raise newException(ViewError, "@include: partial not found: " & path)
        let content = try: readFile(path)
                      except IOError as e:
                        raise newException(ViewError,
                          "@include read error '" & name & "': " & e.msg)
        renderSpanImpl(content, data, globals, locals, 0, content.len, depth + 1, viewsDir, sections, res)
        i = nextPos; continue
      res.add(tmpl[i]); inc i; continue

    # {!! $variable !!} — raw (unescaped) output
    elif matchAt(tmpl, "{!!", i):
      let endIdx = findFrom(tmpl, "!!}", i + 3)
      if endIdx != -1 and endIdx < spanEnd:
        emitVar(tmpl, i + 3, endIdx, data, globals, locals, escaped = false, res)
        i = endIdx + 3; continue

    # {{ $variable }} — HTML-escaped output
    elif matchAt(tmpl, "{{", i):
      let endIdx = findFrom(tmpl, "}}", i + 2)
      if endIdx != -1 and endIdx < spanEnd:
        emitVar(tmpl, i + 2, endIdx, data, globals, locals, escaped = true, res)
        i = endIdx + 2; continue

    # @if(condition) or @if condition ... [@else ...] @endif
    elif matchAt(tmpl, "@if", i):
      let isParen = matchAt(tmpl, "@if(", i)
      let isSpace = matchAt(tmpl, "@if ", i)
      if not (isParen or isSpace):
        res.add(tmpl[i]); inc i; continue
        
      if isParen: stderr.writeLine("[Melody Warning] @if(...) is deprecated. Please use Nim-style `@if cond` instead.")
        
      var condStart = if isParen: i + 4 else: i + 4
      var condEnd = -1
      var exprEnd = -1
      
      if isSpace:
        while condStart < spanEnd and tmpl[condStart] in {' ', '\t'}: inc condStart
        var j = condStart
        while j < spanEnd and tmpl[j] in {'a'..'z', 'A'..'Z', '0'..'9', '_', '.', '$'}: inc j
        condEnd = j
        exprEnd = j
      else:
        condEnd = findFrom(tmpl, ")", condStart)
        if condEnd != -1: exprEnd = condEnd + 1
        
      if condEnd == -1 or exprEnd == -1 or condEnd >= spanEnd:
        res.add(tmpl[i]); inc i; continue
        
      let (ca, cz) = stripSlice(tmpl, condStart, condEnd)
      let isTrue   = isTruthy(resolveVar(locals, data, globals, tmpl[ca ..< cz]))
      let blk      = scanBlock(tmpl, exprEnd, ["@if(", "@if "], "@else", "@endif")
      if blk.endPos == -1 or blk.endPos > spanEnd:
        res.add(tmpl[i]); inc i; continue
        
      if blk.elsePos != -1:
        if isTrue: renderSpanImpl(tmpl, data, globals, locals, exprEnd,    blk.elsePos, depth + 1, viewsDir, sections, res)
        else:      renderSpanImpl(tmpl, data, globals, locals, blk.elsePos + 5, blk.endPos, depth + 1, viewsDir, sections, res)
      elif isTrue:
        renderSpanImpl(tmpl, data, globals, locals, exprEnd, blk.endPos, depth + 1, viewsDir, sections, res)
      i = blk.endPos + blk.endTagLen; continue

    # @foreach(list as item) or @foreach(item in list) ... @endforeach
    elif matchAt(tmpl, "@foreach(", i):
      stderr.writeLine("[Melody Warning] @foreach is deprecated. Please use Nim-style `@for item in list` loops instead.")
      let exprStart = i + 9
      let exprEnd   = findFrom(tmpl, ")", exprStart)
      if exprEnd == -1 or exprEnd >= spanEnd:
        res.add(tmpl[i]); inc i; continue
      let expr    = tmpl[exprStart ..< exprEnd].strip()
      let asIdx   = expr.find(" as ")
      let inIdx   = expr.find(" in ")
      var listVar, itemVar: string
      if asIdx != -1:
        listVar = expr[0 ..< asIdx].strip()
        itemVar = expr[asIdx + 4 .. ^1].strip()
      elif inIdx != -1:
        itemVar = expr[0 ..< inIdx].strip()
        listVar = expr[inIdx + 4 .. ^1].strip()
      else:
        res.add(tmpl[i]); inc i; continue
      let listNode = resolveVar(locals, data, globals, listVar)
      let blk      = scanBlock(tmpl, exprEnd + 1, ["@foreach("], "", "@endforeach")
      if blk.endPos == -1 or blk.endPos > spanEnd:
        res.add(tmpl[i]); inc i; continue
      if listNode.kind == JArray:
        var iterCount = 0
        for item in listNode.getElems():
          inc iterCount
          if iterCount > MAX_LOOP_ITER:
            raise newException(ViewError,
              "@foreach exceeded MAX_LOOP_ITER (" & $MAX_LOOP_ITER & ")")
          # Temporarily inject the loop variable into locals, then restore the original value.
          let hadKey = locals.hasKey(itemVar)
          let oldVal = if hadKey: locals[itemVar] else: nil
          locals[itemVar] = item
          renderSpanImpl(tmpl, data, globals, locals, exprEnd + 1, blk.endPos, depth + 1, viewsDir, sections, res)
          if hadKey and not oldVal.isNil: locals[itemVar] = oldVal
          else: locals.delete(itemVar)
      i = blk.endPos + blk.endTagLen; continue

    # Nim-style @for user in users ... @endfor
    # OR C-style @for($i = 0; $i < N; $i++) ... @endfor
    elif matchAt(tmpl, "@for", i) and not matchAt(tmpl, "@foreach", i):
      let isParen = matchAt(tmpl, "@for(", i)
      let isSpace = matchAt(tmpl, "@for ", i)
      if not (isParen or isSpace):
        res.add(tmpl[i]); inc i; continue
      
      var parseAsIter = false
      var itemVar = ""
      var listVar = ""
      var exprEnd = -1
      
      var j = if isParen: i + 5 else: i + 5
      while j < spanEnd and tmpl[j] in {' ', '\t'}: inc j
      let itemStart = j
      while j < spanEnd and tmpl[j] notin {' ', '\t', '\n', '\r', ')'}: inc j
      itemVar = tmpl[itemStart ..< j]
      
      while j < spanEnd and tmpl[j] in {' ', '\t'}: inc j
      let inStart = j
      while j < spanEnd and tmpl[j] notin {' ', '\t', '\n', '\r', ')'}: inc j
      let inKeyword = tmpl[inStart ..< j]
      
      if inKeyword == "in":
        while j < spanEnd and tmpl[j] in {' ', '\t'}: inc j
        let listStart = j
        while j < spanEnd and tmpl[j] in {'a'..'z', 'A'..'Z', '0'..'9', '_', '.', '$'}: inc j
        listVar = tmpl[listStart ..< j]
        
        while j < spanEnd and tmpl[j] in {' ', '\t'}: inc j
        if isParen and j < spanEnd and tmpl[j] == ')':
          exprEnd = j + 1
          parseAsIter = true
        elif not isParen:
          exprEnd = j
          parseAsIter = true
          
      if parseAsIter:
        let listNode = resolveVar(locals, data, globals, listVar)
        let blk = scanBlock(tmpl, exprEnd, ["@for(", "@for "], "", "@endfor")
        if blk.endPos == -1 or blk.endPos > spanEnd:
          res.add(tmpl[i]); inc i; continue
        if listNode.kind == JArray:
          var iterCount = 0
          for item in listNode.getElems():
            inc iterCount
            if iterCount > MAX_LOOP_ITER:
              raise newException(ViewError, "@for exceeded MAX_LOOP_ITER (" & $MAX_LOOP_ITER & ")")
            let hadKey = locals.hasKey(itemVar)
            let oldVal = if hadKey: locals[itemVar] else: nil
            locals[itemVar] = item
            renderSpanImpl(tmpl, data, globals, locals, exprEnd, blk.endPos, depth + 1, viewsDir, sections, res)
            if hadKey and not oldVal.isNil: locals[itemVar] = oldVal
            else: locals.delete(itemVar)
        i = blk.endPos + blk.endTagLen; continue
        
      # If not iterator, try C-style counted loop, which requires parens
      if isParen:
        let hdrStart = i + 5
        let hdrEnd   = findFrom(tmpl, ")", hdrStart)
        if hdrEnd != -1 and hdrEnd < spanEnd:
          let hdr = parseForHeader(tmpl, hdrStart, hdrEnd)
          if hdr.ok:
            let blk = scanBlock(tmpl, hdrEnd + 1, ["@for(", "@for "], "", "@endfor")
            if blk.endPos != -1 and blk.endPos <= spanEnd:
              var counter   = hdr.initVal
              var iterCount = 0
              while true:
                let done = if hdr.step > 0: counter >= hdr.limit else: counter <= hdr.limit
                if done: break
                inc iterCount
                if iterCount > MAX_LOOP_ITER:
                  raise newException(ViewError, "@for exceeded MAX_LOOP_ITER (" & $MAX_LOOP_ITER & ")")
                let hadKey = locals.hasKey(hdr.varName)
                let oldVal = if hadKey: locals[hdr.varName] else: nil
                locals[hdr.varName] = %counter
                renderSpanImpl(tmpl, data, globals, locals, hdrEnd + 1, blk.endPos, depth + 1, viewsDir, sections, res)
                if hadKey and not oldVal.isNil: locals[hdr.varName] = oldVal
                else: locals.delete(hdr.varName)
                counter += hdr.step
              i = blk.endPos + blk.endTagLen; continue

      # Fallback if both fail
      res.add(tmpl[i]); inc i; continue

    res.add(tmpl[i])
    inc i

# Public API

proc renderSpan*(tmpl: string, data: JsonNode, spanStart, spanEnd: int,
                 depth: int, res: var string) =
  ## Public single-string render without layout support.
  ## Kept for backward compatibility and direct use in tests.
  renderSpanImpl(tmpl, data, newJObject(), newJObject(), spanStart, spanEnd, depth, "", initTable[string, string](), res)

proc renderString*(tmpl: string, data: JsonNode, globals: JsonNode = nil, viewsDir: string = ""): string

proc renderString*(tmpl: string, data: JsonNode, viewsDir: string): string =
  ## Backward compatibility overload for existing code that passed viewsDir as 3rd arg.
  renderString(tmpl, data, nil, viewsDir)

proc renderString*(tmpl: string, data: JsonNode, globals: JsonNode = nil, viewsDir: string = ""): string =
  ## Renders `tmpl` with `data` as the variable context.
  ##
  ## If `viewsDir` is provided, enables @extends (layout inheritance) and @include.
  ## When @extends is detected, performs a two-pass render:
  ##   Pass 1: extract all @section blocks from the child template.
  ##   Pass 2: render the layout file, filling @yield slots with section content.
  ##
  ## Thread-safe: all state is stack-local.
  let layoutName = extractExtends(tmpl)
  let safeGlobals = if globals.isNil: newJObject() else: globals
  var locals = newJObject()

  if layoutName.len > 0 and viewsDir.len > 0:
    let sections = extractSections(tmpl)
    let layoutPath = resolveViewPath(viewsDir, layoutName)
    if not fileExists(layoutPath):
      raise newException(ViewError, "@extends: layout not found: " & layoutPath)
    let layoutContent =
      try:   readFile(layoutPath)
      except IOError as e:
        raise newException(ViewError, "@extends read error: " & e.msg)
    result = newStringOfCap(layoutContent.len * 2)
    renderSpanImpl(layoutContent, data, safeGlobals, locals, 0, layoutContent.len, 0, viewsDir, sections, result)
  else:
    result = newStringOfCap(tmpl.len + (tmpl.len shr 1))
    renderSpanImpl(tmpl, data, safeGlobals, locals, 0, tmpl.len, 0, viewsDir, initTable[string, string](), result)
