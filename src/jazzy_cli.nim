## Jazzy CLI - Project scaffolding tool
## Usage: jazzy new <project_name>

import std/[os, strutils, strformat, sysrand]
import jazzy/cli/[db_async_upgrade, migrations, templates]
import jazzy/core/version

const VERSION = JAZZY_VERSION

const BANNER = """
     ██╗ █████╗ ███████╗███████╗██╗   ██╗
     ██║██╔══██╗╚══███╔╝╚══███╔╝╚██╗ ██╔╝
     ██║███████║  ███╔╝   ███╔╝  ╚████╔╝
██   ██║██╔══██║ ███╔╝   ███╔╝    ╚██╔╝
╚█████╔╝██║  ██║███████╗███████╗   ██║
 ╚════╝ ╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝
  Productive web framework for Nim 🎷
"""

proc showHelp() =
  echo BANNER
  echo fmt"  Version: {VERSION}"
  echo ""
  echo "  Usage:"
  echo "    jazzy new <project_name>    Create a new Jazzy project"
  echo "    jazzy upgrade db-async      Preview the await-first DB migration"
  echo "      --apply                   Apply safe changes"
  echo "      --check                   Exit non-zero if migration work remains"
  echo "    jazzy make:migration <name> Create a versioned database migration"
  echo "    jazzy make:seeder <name>    Create an explicit database seeder"
  echo "    jazzy migrate [--step]      Apply pending migrations"
  echo "    jazzy migrate --pretend     Read-only pending-migration preview"
  echo "    jazzy migrate:status        Show applied migrations"
  echo "    jazzy migrate:rollback      Roll back the latest migration batch"
  echo "    jazzy migrate:reset         Roll back every migration batch"
  echo "    jazzy migrate:fresh         Drop tables and run all migrations"
  echo "    jazzy db:seed               Run explicit database seeders"
  echo "      --force                   Required for DB-changing commands in production"
  echo "    jazzy --version             Show version"
  echo "    jazzy --help                Show this help"
  echo ""

proc createFile(path, content: string) =
  let dir = parentDir(path)
  if dir.len > 0:
    createDir(dir)
  writeFile(path, content)
  echo fmt"    ✓ {path}"

proc generateJwtSecret(): string =
  var bytes: array[32, byte]
  discard urandom(bytes)
  for b in bytes:
    result.add(toHex(int(b), 2))
  result = result.toLowerAscii()

proc newProject(name: string) =
  if name.len == 0:
    echo "  Error: Please provide a project name."
    echo "  Usage: jazzy new <project_name>"
    quit(1)

  if dirExists(name):
    echo fmt"  Error: Directory '{name}' already exists."
    quit(1)

  echo BANNER
  echo fmt"  Creating new Jazzy project: {name}"
  echo ""

  createDir(name)

  let pkgName = name.replace('-', '_')

  # Core files
  createFile(name / fmt"{pkgName}.nimble", nimbleTemplate(pkgName))
  createFile(name / "config.nims", configNimsTemplate())
  createFile(name / ".gitignore", gitignoreTemplate())
  createFile(name / ".env", envTemplate(generateJwtSecret()))

  # Source files
  createFile(name / "src" / "app.nim", appTemplate(pkgName))
  createFile(name / "src" / "router.nim", routerTemplate())
  createFile(name / "src" / "migrations" / "m00000000000000_create_todos.nim",
      todoMigrationTemplate())
  createFile(name / "src" / "controllers" / "todo_controller.nim",
      todoControllerTemplate())

  # Tests
  createFile(name / "tests" / "config.nims", testConfigTemplate())

  echo ""
  echo "  ✅ Project created successfully!"
  echo ""
  echo "  Next steps:"
  echo fmt"    cd {name}"
  echo "    jazzy migrate"
  echo "    nimble c -r src/app.nim"

  echo ""
  echo "  🎷 Happy coding with Jazzy!"
  echo ""

when isMainModule:
  let args = commandLineParams()

  if args.len == 0:
    showHelp()
    quit(0)

  case args[0].toLowerAscii()
  of "new":
    if args.len < 2:
      echo "  Error: Please provide a project name."
      echo "  Usage: jazzy new <project_name>"
      quit(1)
    newProject(args[1])
  of "upgrade":
    if args.len < 2 or args[1].toLowerAscii() != "db-async":
      echo "  Error: Usage: jazzy upgrade db-async [--apply|--check] [path]"
      quit(1)
    var apply = false
    var check = false
    var target = "."
    var hasTarget = false
    if args.len > 2:
      for argument in args[2 .. ^1]:
        case argument
        of "--apply":
          apply = true
        of "--check":
          check = true
        of "--dry-run":
          discard
        else:
          if argument.startsWith("-"):
            echo "  Error: Unknown upgrade option: " & argument
            quit(1)
          elif not hasTarget:
            target = argument
            hasTarget = true
          else:
            echo "  Error: Only one upgrade target directory may be provided."
            quit(1)
    quit(runDbAsyncUpgrade(target, apply, check))
  of "make:migration":
    if args.len != 2:
      echo "  Error: Usage: jazzy make:migration <name>"
      quit(1)
    quit(makeMigration(args[1]))
  of "make:seeder":
    if args.len != 2:
      echo "  Error: Usage: jazzy make:seeder <name>"
      quit(1)
    quit(makeSeeder(args[1]))
  of "migrations:init":
    quit(initializeMigrations())
  of "migrate", "migrate:status", "migrate:rollback", "migrate:reset", "migrate:fresh", "db:seed":
    let command = args[0].toLowerAscii()
    var action = case command
      of "migrate": "up"
      of "migrate:status": "status"
      of "migrate:rollback": "rollback"
      of "migrate:reset": "reset"
      of "migrate:fresh": "fresh"
      else: "seed"
    var force = false
    if args.len > 1:
      for argument in args[1 .. ^1]:
        case argument
        of "--force":
          force = true
        of "--step":
          if command != "migrate" or action != "up":
            echo "  Error: --step is only valid with jazzy migrate."
            quit(1)
          action = "step"
        of "--pretend":
          if command != "migrate" or action != "up":
            echo "  Error: --pretend is only valid with jazzy migrate."
            quit(1)
          action = "pretend"
        of "--seed":
          if command != "migrate:fresh" or action != "fresh":
            echo "  Error: --seed is only valid with jazzy migrate:fresh."
            quit(1)
          action = "fresh-seed"
        else:
          echo "  Error: Unknown migration option: " & argument
          quit(1)
    quit(runMigrationCommand(action, force = force))
  of "--version", "-v":
    echo fmt"Jazzy v{VERSION}"
  of "--help", "-h":
    showHelp()
  else:
    echo fmt"  Unknown command: {args[0]}"
    echo ""
    showHelp()
    quit(1)
