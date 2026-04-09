## Scaffold templates for `jazzy new <project_name>`

import std/strformat
import ../core/version

proc nimbleTemplate*(projectName: string): string =
  result = fmt"""# Package

version       = "0.1.0"
author        = "Jazzy-CLI"
description   = "A new Jazzy web application"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"
requires "jazzy >= {JAZZY_VERSION}"
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
import schema

proc main() =
  connectDB("{projectName}.db")

  initSchema()
  registerRoutes()

  echo "🎷 Jazzy is dancing on http://localhost:8080"
  Jazzy.serve(8080)

when isMainModule:
  main()
"""

proc routerTemplate*(): string =
  result = """import jazzy
import controllers/todo_controller

proc registerRoutes*() =
  Route.get("/", proc(ctx: Context) {.async.} =
    ctx.json(%*{"message": "Welcome to Jazzy! 🎷", "api": "/todos"})
  )

  Route.groupPath("/todos"):
    Route.get("/", todo_controller.list)
    Route.post("/", todo_controller.create)
    Route.patch("/:id", todo_controller.update)
    Route.delete("/:id", todo_controller.delete)
"""

proc todoControllerTemplate*(): string =
  result = """import jazzy

# GET /todos
proc list*(ctx: Context) {.async.} =
  let todos = DB.table("todos").get()
  ctx.json(todos)

# POST /todos
proc create*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "title": "required|min:3"
  })

  let id = DB.table("todos").insert(%*{
    "title": data["title"].getStr,
    "completed": false
  })

  ctx.status(201).json(%*{"id": id, "status": "created"})

# PATCH /todos/:id
proc update*(ctx: Context) {.async.} =
  let id = ctx.param("id")
  let data = ctx.validate(%*{
    "completed": "required|bool"
  })

  DB.table("todos").where("id", id).update(%*{
    "completed": data["completed"].getBool
  })

  ctx.json(%*{"status": "updated"})

# DELETE /todos/:id
proc delete*(ctx: Context) {.async.} =
  let id = ctx.param("id")
  DB.table("todos").where("id", id).delete()
  ctx.status(204).json(%*{"status": "deleted"})
"""

proc schemaTemplate*(): string =
  result = """import jazzy

proc initSchema*() =
  createTable("todos")
    .increments("id")
    .string("title")
    .boolean("completed", default = false)
    .execute()
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

proc envTemplate*(): string =
  result = """# Application Environment (development | production)
APP_ENV=development
LOG_LEVEL=debug
"""

proc testConfigTemplate*(): string =
  result = """switch("path", "$projectDir/../src")
"""
