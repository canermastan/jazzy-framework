## CLI support for self-healing, compiled Jazzy migrations.
##
## Nim needs a source entrypoint to compile a migration command. Jazzy creates
## that entrypoint beneath `.jazzy/` for the duration of each CLI invocation;
## projects only keep their reviewed migration files in `src/migrations/`.

import std/[algorithm, os, osproc, strutils, times]
import templates

const jazzySourceDirectory = parentDir(parentDir(parentDir(currentSourcePath())))

proc normalizeMigrationName*(name: string): string =
  for character in name.toLowerAscii():
    if character in {'a' .. 'z', '0' .. '9'}:
      result.add(character)
    elif result.len == 0 or result[^1] != '_':
      result.add('_')
  result = result.strip(chars = {'_'})

proc migrationDirectory(root: string): string = root / "src" / "migrations"
proc seederDirectory(root: string): string = root / "src" / "seeders"
proc internalDirectory(root: string): string = root / ".jazzy"
proc runnerPath(root: string): string = internalDirectory(root) / "migration_runner.nim"

proc migrationModules(root: string): seq[string] =
  let directory = migrationDirectory(root)
  if not dirExists(directory):
    return
  for path in walkFiles(directory / "m*.nim"):
    result.add(splitFile(path).name)
  result.sort()

proc seederModules(root: string): seq[string] =
  let directory = seederDirectory(root)
  if not dirExists(directory):
    return
  for path in walkFiles(directory / "s*.nim"):
    result.add(splitFile(path).name)
  result.sort()

proc initializeMigrations*(root = ".", announce = true): int =
  ## Create only the visible migration directory. The generated runner is
  ## recreated inside `.jazzy/` when a migration command actually runs.
  let srcDirectory = root / "src"
  if not dirExists(srcDirectory):
    echo "  Error: src/ was not found. Run this inside a Jazzy project."
    return 1
  createDir(migrationDirectory(root))
  if announce:
    echo "  Migration directory is ready."
  0

proc makeMigration*(name: string, root = "."): int =
  let normalized = normalizeMigrationName(name)
  if normalized.len == 0:
    echo "  Error: Please provide a migration name, for example create_users."
    return 1
  if initializeMigrations(root) != 0:
    return 1

  let timestamp = now().format("yyyyMMddHHmmss")
  let migrationName = timestamp & "_" & normalized
  let path = migrationDirectory(root) / ("m" & migrationName & ".nim")
  if fileExists(path):
    echo "  Error: A migration with that timestamp already exists. Try again."
    return 1
  writeFile(path, migrationTemplate(migrationName))
  echo "  Created " & path
  0

proc makeSeeder*(name: string, root = "."): int =
  let normalized = normalizeMigrationName(name)
  if normalized.len == 0:
    echo "  Error: Please provide a seeder name, for example demo_users."
    return 1
  let srcDirectory = root / "src"
  if not dirExists(srcDirectory):
    echo "  Error: src/ was not found. Run this inside a Jazzy project."
    return 1
  createDir(seederDirectory(root))
  let timestamp = now().format("yyyyMMddHHmmss")
  let seederName = timestamp & "_" & normalized
  let path = seederDirectory(root) / ("s" & seederName & ".nim")
  if fileExists(path):
    echo "  Error: A seeder with that timestamp already exists. Try again."
    return 1
  writeFile(path, seederTemplate(seederName))
  echo "  Created " & path
  0

proc runMigrationCommand*(action: string, root = ".", force = false): int =
  if initializeMigrations(root, announce = false) != 0:
    return 1
  createDir(internalDirectory(root))
  let runner = absolutePath(runnerPath(root))
  writeFile(runner, migrationRunnerTemplate(migrationModules(root), seederModules(root)))
  let sourcePath = absolutePath(root / "src")
  let executable = runner & (when defined(windows): ".exe" else: "")
  let compileArguments = @[
    "nim", "c", "--hints:off", "--path:" & sourcePath,
    "--path:" & jazzySourceDirectory, "-o:" & executable, runner
  ]
  # `root` is normally the user's current directory. Keeping this helper
  # root-aware as well makes it safe for IDEs and tests to invoke it against a
  # concrete project path: `.env`, relative SQLite paths and generated output
  # all stay in that project.
  let previousDirectory = getCurrentDir()
  setCurrentDir(absolutePath(root))
  try:
    let compilation = execCmdEx(quoteShellCommand(compileArguments))
    if compilation.output.len > 0:
      stdout.write(compilation.output)
    if compilation.exitCode != 0:
      return compilation.exitCode
    var runArguments = @[executable, action]
    if force:
      runArguments.add("--force")
    let execution = execCmdEx(quoteShellCommand(runArguments))
    if execution.output.len > 0:
      stdout.write(execution.output)
    execution.exitCode
  finally:
    setCurrentDir(previousDirectory)
