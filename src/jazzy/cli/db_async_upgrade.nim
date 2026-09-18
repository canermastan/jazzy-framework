## Safe source migration for Jazzy's await-first database API.
##
## This deliberately recognises only direct DB/createTable chains. It uses a
## small Nim-aware lexer to ignore comments and strings, and never changes a
## call unless it is inside a proc explicitly marked {.async.}.

import std/[algorithm, options, os, strformat, strutils]

type
  UpgradeKind* = enum
    databaseTerminal,
    schemaTerminal

  UpgradeFinding* = object
    file*: string
    line*: int
    column*: int
    snippet*: string
    operation*: string
    reason*: string
    safe*: bool
    kind*: UpgradeKind
    offset*: int

  UpgradeAnalysis* = object
    findings*: seq[UpgradeFinding]

  Candidate = object
    start: int
    stop: int
    operation: string
    kind: UpgradeKind

  ProcScope = object
    bodyStart: int
    stop: int
    isAsync: bool

const terminalMethods = [
  "get", "first", "count", "insert", "update", "delete", "restore",
  "forceDelete", "raw", "rawExec"
]

proc isWhitespace(c: char): bool =
  c in {' ', '\t', '\r', '\n'}

proc isIdentifierChar(c: char): bool =
  c in {'a'..'z', 'A'..'Z', '0'..'9', '_'}

proc isWordAt(source: string, code: openArray[bool], position: int,
    word: string): bool =
  if position < 0 or position + word.len > source.len:
    return false
  if position > 0 and isIdentifierChar(source[position - 1]):
    return false
  if position + word.len < source.len and isIdentifierChar(source[position + word.len]):
    return false
  for index, ch in word:
    if source[position + index] != ch or not code[position + index]:
      return false
  true

proc buildCodeMask(source: string): seq[bool] =
  type LexerState = enum
    normal, lineComment, blockComment, quoted, tripleQuoted, character

  result = newSeq[bool](source.len)
  var state = normal
  var blockDepth = 0
  var index = 0
  while index < source.len:
    case state
    of normal:
      if source[index] == '#' and index + 1 < source.len and source[index + 1] == '[':
        state = blockComment
        blockDepth = 1
        index += 2
      elif source[index] == '#':
        state = lineComment
        inc index
      elif source[index] == '"' and index + 2 < source.len and
          source[index + 1] == '"' and source[index + 2] == '"':
        state = tripleQuoted
        index += 3
      elif source[index] == '"':
        state = quoted
        inc index
      elif source[index] == '\'':
        state = character
        inc index
      else:
        result[index] = true
        inc index
    of lineComment:
      if source[index] == '\n':
        state = normal
      inc index
    of blockComment:
      if source[index] == '#' and index + 1 < source.len and source[index + 1] == '[':
        inc blockDepth
        index += 2
      elif source[index] == ']' and index + 1 < source.len and source[index + 1] == '#':
        dec blockDepth
        index += 2
        if blockDepth == 0:
          state = normal
      else:
        inc index
    of quoted, character:
      if source[index] == '\\' and index + 1 < source.len:
        index += 2
      elif (state == quoted and source[index] == '"') or
          (state == character and source[index] == '\''):
        state = normal
        inc index
      else:
        inc index
    of tripleQuoted:
      if source[index] == '"' and index + 2 < source.len and
          source[index + 1] == '"' and source[index + 2] == '"':
        state = normal
        index += 3
      else:
        inc index

proc skipWhitespace(source: string, code: openArray[bool], position: int): int =
  result = position
  while result < source.len and code[result] and isWhitespace(source[result]):
    inc result

proc identifierEnd(source: string, code: openArray[bool], position: int): int =
  result = position
  while result < source.len and code[result] and isIdentifierChar(source[result]):
    inc result

proc matchingParen(source: string, code: openArray[bool], opening: int): int =
  var depth = 0
  for index in opening ..< source.len:
    if not code[index]:
      continue
    case source[index]
    of '(':
      inc depth
    of ')':
      dec depth
      if depth == 0:
        return index
    else:
      discard
  -1

proc parseDbChain(source: string, code: openArray[bool], start: int): Option[Candidate] =
  var position = start + 2
  var isFirstMethod = true
  while true:
    position = skipWhitespace(source, code, position)
    if position >= source.len or not code[position] or source[position] != '.':
      return none(Candidate)
    position = skipWhitespace(source, code, position + 1)
    let methodStart = position
    position = identifierEnd(source, code, position)
    if methodStart == position:
      return none(Candidate)
    let operation = source[methodStart ..< position]
    if isFirstMethod and operation notin ["table", "raw", "rawExec"]:
      return none(Candidate)
    position = skipWhitespace(source, code, position)
    if position >= source.len or not code[position] or source[position] != '(':
      return none(Candidate)
    let closing = matchingParen(source, code, position)
    if closing < 0:
      return none(Candidate)
    if operation in terminalMethods:
      return some(Candidate(start: start, stop: closing + 1, operation: operation,
        kind: databaseTerminal))
    position = closing + 1
    isFirstMethod = false

proc parseSchemaChain(source: string, code: openArray[bool], start: int): Option[Candidate] =
  var position = skipWhitespace(source, code, start + "createTable".len)
  if position >= source.len or not code[position] or source[position] != '(':
    return none(Candidate)
  let firstClosing = matchingParen(source, code, position)
  if firstClosing < 0:
    return none(Candidate)
  position = firstClosing + 1
  while true:
    position = skipWhitespace(source, code, position)
    if position >= source.len or not code[position] or source[position] != '.':
      return none(Candidate)
    position = skipWhitespace(source, code, position + 1)
    let methodStart = position
    position = identifierEnd(source, code, position)
    if methodStart == position:
      return none(Candidate)
    let operation = source[methodStart ..< position]
    position = skipWhitespace(source, code, position)
    if position >= source.len or not code[position] or source[position] != '(':
      return none(Candidate)
    let closing = matchingParen(source, code, position)
    if closing < 0:
      return none(Candidate)
    if operation == "execute":
      return some(Candidate(start: start, stop: closing + 1, operation: operation,
        kind: schemaTerminal))
    position = closing + 1

proc lineStart(source: string, position: int): int =
  result = position
  while result > 0 and source[result - 1] != '\n':
    dec result

proc lineEnd(source: string, position: int): int =
  result = position
  while result < source.len and source[result] != '\n':
    inc result

proc lineIndent(source: string, start: int): int =
  result = 0
  var position = start
  while position < source.len and source[position] in {' ', '\t'}:
    inc result
    inc position

proc findHeaderEquals(source: string, code: openArray[bool], start: int): int =
  var parentheses = 0
  var braces = 0
  var brackets = 0
  for position in start ..< source.len:
    if not code[position]:
      continue
    case source[position]
    of '(':
      inc parentheses
    of ')':
      dec parentheses
    of '{':
      inc braces
    of '}':
      dec braces
    of '[':
      inc brackets
    of ']':
      dec brackets
    of '=':
      if parentheses == 0 and braces == 0 and brackets == 0 and
          (position + 1 >= source.len or source[position + 1] != '='):
        return position
    else:
      discard
  -1

proc hasAsyncPragma(source: string, code: openArray[bool], first, last: int): bool =
  var position = first
  while position + "async".len <= last:
    if isWordAt(source, code, position, "async"):
      return true
    inc position
  false

proc findScopeEnd(source: string, code: openArray[bool], bodyStart, baseIndent: int): int =
  var position = lineEnd(source, bodyStart)
  while position < source.len:
    if source[position] == '\n':
      inc position
    let currentLine = position
    let endOfCurrentLine = lineEnd(source, currentLine)
    var firstCode = currentLine
    while firstCode < endOfCurrentLine and isWhitespace(source[firstCode]):
      inc firstCode
    if firstCode < endOfCurrentLine and code[firstCode] and
        lineIndent(source, currentLine) <= baseIndent:
      return currentLine
    position = endOfCurrentLine
  source.len

proc findProcScopes(source: string, code: openArray[bool]): seq[ProcScope] =
  var position = 0
  while position < source.len:
    if isWordAt(source, code, position, "proc"):
      let equals = findHeaderEquals(source, code, position + 4)
      if equals >= 0:
        let bodyStart = equals + 1
        let scopeStart = lineStart(source, position)
        result.add(ProcScope(
          bodyStart: bodyStart,
          stop: findScopeEnd(source, code, bodyStart, lineIndent(source, scopeStart)),
          isAsync: hasAsyncPragma(source, code, position, equals)
        ))
        position = bodyStart
      else:
        inc position
    else:
      inc position

proc nearestScope(scopes: openArray[ProcScope], position: int): Option[ProcScope] =
  var bestIndex = -1
  for index, scope in scopes:
    if position >= scope.bodyStart and position < scope.stop and
        (bestIndex < 0 or scope.bodyStart > scopes[bestIndex].bodyStart):
      bestIndex = index
  if bestIndex >= 0:
    some(scopes[bestIndex])
  else:
    none(ProcScope)

proc alreadyAwaited(source: string, code: openArray[bool], position: int): bool =
  var index = position - 1
  while index >= 0 and code[index] and isWhitespace(source[index]):
    dec index
  let wordEnd = index + 1
  while index >= 0 and code[index] and isIdentifierChar(source[index]):
    dec index
  let preceding = source[index + 1 ..< wordEnd]
  preceding in ["await", "waitFor"]

proc collectCandidates(source: string, code: openArray[bool]): seq[Candidate] =
  var position = 0
  while position < source.len:
    var candidate = none(Candidate)
    if isWordAt(source, code, position, "DB"):
      candidate = parseDbChain(source, code, position)
    elif isWordAt(source, code, position, "createTable"):
      candidate = parseSchemaChain(source, code, position)
    if candidate.isSome:
      result.add(candidate.get())
      position = candidate.get().stop
    else:
      inc position

proc analyzeDbAsyncSource*(source: string, file = ""): UpgradeAnalysis =
  let code = buildCodeMask(source)
  let scopes = findProcScopes(source, code)
  for candidate in collectCandidates(source, code):
    if alreadyAwaited(source, code, candidate.start):
      continue
    let scope = nearestScope(scopes, candidate.start)
    let startOfLine = lineStart(source, candidate.start)
    let endOfLine = lineEnd(source, candidate.start)
    var finding = UpgradeFinding(
      file: file,
      line: source[0 ..< candidate.start].count('\n') + 1,
      column: candidate.start - startOfLine + 1,
      snippet: source[startOfLine ..< endOfLine].strip(),
      operation: candidate.operation,
      kind: candidate.kind,
      offset: candidate.start
    )
    if scope.isSome and scope.get().isAsync:
      finding.safe = true
    elif scope.isSome:
      finding.reason = "This call is inside a synchronous proc. Its signature and callers may need to become async."
    else:
      finding.reason = "This call is outside a proc explicitly marked {.async.}."
    result.findings.add(finding)

proc applyDbAsyncUpgrade*(source: string, analysis: UpgradeAnalysis): string =
  ## Add await only for findings that analysis marked safe.
  var offsets: seq[int]
  for finding in analysis.findings:
    if finding.safe:
      offsets.add(finding.offset)
  offsets.sort(SortOrder.Descending)
  result = source
  for offset in offsets:
    result.insert("await ", offset)

proc isIgnoredPath(path: string): bool =
  for part in path.replace('\\', '/').split('/'):
    if part in [".git", ".jazzy", "nimcache", "nimblecache", "vendor"]:
      return true
  false

proc nimFiles(root: string): seq[string] =
  for path in walkDirRec(root):
    if path.endsWith(".nim") and not isIgnoredPath(path):
      result.add(path)
  result.sort()

proc displayPath(path, root: string): string =
  try:
    relativePath(path, root)
  except OSError:
    path

proc printFinding(finding: UpgradeFinding, root: string) =
  let location = displayPath(finding.file, root) & ":" & $finding.line & ":" & $finding.column
  if finding.safe:
    echo fmt"  + {location}  add `await` before .{finding.operation}()"
    let before = finding.snippet.strip()
    let callStart = if finding.kind == databaseTerminal: "DB" else: "createTable"
    var after = before
    let insertionPoint = after.find(callStart)
    if insertionPoint >= 0:
      after.insert("await ", insertionPoint)
    echo "    - " & before
    echo "    + " & after
  else:
    echo fmt"  ! {location}  manual action required"
    echo "    " & finding.snippet
    echo "    " & finding.reason

proc runDbAsyncUpgrade*(target = ".", apply = false, check = false): int =
  if apply and check:
    echo "  Error: --apply and --check cannot be used together."
    return 2

  let root = expandFilename(target)
  if not dirExists(root):
    echo "  Error: Upgrade target is not a directory: " & target
    return 2

  echo ""
  echo "  Jazzy DB Async Upgrade"
  echo "  " & root
  echo ""

  var safeCount = 0
  var manualCount = 0
  var changedFiles = 0
  for path in nimFiles(root):
    let source = readFile(path)
    let analysis = analyzeDbAsyncSource(source, path)
    if analysis.findings.len == 0:
      continue
    for finding in analysis.findings:
      printFinding(finding, root)
      if finding.safe:
        inc safeCount
      else:
        inc manualCount
    if apply and safeCount > 0:
      let updated = applyDbAsyncUpgrade(source, analysis)
      if updated != source:
        writeFile(path, updated)
        inc changedFiles

  echo ""
  echo fmt"  Summary: {safeCount} safe change(s), {manualCount} manual change(s)."
  if apply:
    echo fmt"  Applied changes to {changedFiles} file(s). Review with `git diff`."
  elif safeCount > 0:
    echo "  Run `jazzy upgrade db-async --apply` to apply the safe changes."
  if manualCount > 0:
    echo "  Manual locations were left untouched."

  if check and safeCount + manualCount > 0:
    return 1
  0
