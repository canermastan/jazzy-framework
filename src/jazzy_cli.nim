## Jazzy CLI - Project scaffolding tool
## Usage: jazzy new <project_name>

import std/[os, strutils, strformat]
import jazzy/cli/templates

const VERSION = "0.1.0"

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
  echo "    jazzy --version             Show version"
  echo "    jazzy --help                Show this help"
  echo ""

proc createFile(path, content: string) =
  let dir = parentDir(path)
  if dir.len > 0:
    createDir(dir)
  writeFile(path, content)
  echo fmt"    ✓ {path}"

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

  # Core files
  createFile(name / fmt"{name}.nimble", nimbleTemplate(name))
  createFile(name / "config.nims", configNimsTemplate())
  createFile(name / ".gitignore", gitignoreTemplate())

  # Source files
  createFile(name / "src" / "app.nim", appTemplate(name))
  createFile(name / "src" / "router.nim", routerTemplate())
  createFile(name / "src" / "controllers" / "home_controller.nim",
      homeControllerTemplate())

  # Placeholder directories
  createFile(name / "src" / "services" / ".gitkeep", "")
  createFile(name / "src" / "models" / ".gitkeep", "")

  # Tests
  createFile(name / "tests" / "config.nims", testConfigTemplate())

  echo ""
  echo "  ✅ Project created successfully!"
  echo ""
  echo "  Next steps:"
  echo fmt"    cd {name}"
  echo "    nimble install --depsOnly"
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
  of "--version", "-v":
    echo fmt"Jazzy v{VERSION}"
  of "--help", "-h":
    showHelp()
  else:
    echo fmt"  Unknown command: {args[0]}"
    echo ""
    showHelp()
    quit(1)
