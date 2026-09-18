## CLI generators for conventional application source files.

import std/[os, strutils]
import templates

proc normalizeModelName*(name: string): string =
  ## Turn `task` or `blog_post` into a valid, conventional Nim type name.
  var capitalizeNext = true
  for character in name:
    if character in {'a' .. 'z', 'A' .. 'Z', '0' .. '9'}:
      if capitalizeNext:
        result.add(character.toUpperAscii())
        capitalizeNext = false
      else:
        result.add(character)
    else:
      capitalizeNext = true
  if result.len == 0 or result[0] notin {'A' .. 'Z'}:
    result.setLen(0)

proc snakeCase*(name: string): string =
  for index, character in name:
    if character in {'A' .. 'Z'}:
      let precededByWord = index > 0 and
        (name[index - 1] in {'a' .. 'z', '0' .. '9'} or
        (name[index - 1] in {'A' .. 'Z'} and index + 1 < name.len and
          name[index + 1] in {'a' .. 'z'}))
      if precededByWord:
        result.add('_')
      result.add(character.toLowerAscii())
    else:
      result.add(character)

proc pluralizeTableName(name: string): string =
  if name.endsWith("y") and name.len > 1 and name[^2] notin {'a', 'e', 'i', 'o', 'u'}:
    return name[0 .. ^2] & "ies"
  if name.endsWith("s") or name.endsWith("x") or name.endsWith("z") or
      name.endsWith("ch") or name.endsWith("sh"):
    return name & "es"
  name & "s"

proc requireSourceDirectory(root: string): bool =
  if dirExists(root / "src"):
    return true
  echo "  Error: src/ was not found. Run this inside a Jazzy project."
  false

proc makeModel*(name: string, root = "."): int =
  let typeName = normalizeModelName(name)
  if typeName.len == 0:
    echo "  Error: Please provide a PascalCase model name, for example Task."
    return 1
  if not requireSourceDirectory(root):
    return 1
  let directory = root / "src" / "models"
  let fileName = snakeCase(typeName)
  let path = directory / (fileName & ".nim")
  if fileExists(path):
    echo "  Error: A model already exists at " & path
    return 1
  createDir(directory)
  writeFile(path, modelTemplate(typeName, pluralizeTableName(fileName)))
  echo "  Created " & path
  0

proc normalizeControllerName*(name: string): string =
  result = normalizeModelName(name)
  if result.len > 0 and not result.endsWith("Controller"):
    result.add("Controller")

proc makeController*(name: string, root = "."): int =
  let controllerName = normalizeControllerName(name)
  if controllerName.len == 0:
    echo "  Error: Please provide a controller name, for example TaskController."
    return 1
  if not requireSourceDirectory(root):
    return 1
  let directory = root / "src" / "controllers"
  let path = directory / (snakeCase(controllerName) & ".nim")
  if fileExists(path):
    echo "  Error: A controller already exists at " & path
    return 1
  createDir(directory)
  writeFile(path, controllerTemplate(controllerName))
  echo "  Created " & path
  0
