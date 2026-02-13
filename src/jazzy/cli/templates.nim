## Scaffold templates for `jazzy new <project_name>`

import std/strformat

proc nimbleTemplate*(projectName: string): string =
  result = fmt"""# Package

version       = "0.1.0"
author        = ""
description   = "A new Jazzy web application"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"
requires "jazzy >= 0.1.0"
"""

proc configNimsTemplate*(): string =
  result = """# This file fixes IDE support for Nimble packages
import std/os

let nimbleDir = getHomeDir() / ".nimble"
let pkgs2Dir = nimbleDir / "pkgs2"

if dirExists(pkgs2Dir):
  for kind, path in walkDir(pkgs2Dir):
    if kind == pcDir:
      switch("path", path)
"""

proc appTemplate*(projectName: string): string =
  result = fmt"""import jazzy
import router

proc main() =
  connectDB("{projectName}.db")

  registerRoutes()

  echo "🎷 Jazzy is dancing on http://localhost:8080"
  Jazzy.serve(8080)

when isMainModule:
  main()
"""

proc routerTemplate*(): string =
  result = """import jazzy
import controllers/home_controller

proc registerRoutes*() =
  Route.get("/", home_controller.index)
"""

proc homeControllerTemplate*(): string =
  result = """import jazzy

proc index*(ctx: Context) {.async.} =
  ctx.json(%*{
    "message": "Welcome to Jazzy! 🎷",
    "status": "running"
  })
"""

proc gitignoreTemplate*(): string =
  result = """# Nim build artifacts
*.exe
*.dll
*.so
*.dylib
nimcache/
nimblecache/

# Database
*.db
*.db-shm
*.db-wal

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
"""

proc testConfigTemplate*(): string =
  result = """switch("path", "$projectDir/../src")
"""
