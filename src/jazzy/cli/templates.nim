## Scaffold templates for `jazzy new <project_name>`

import std/[strformat, strutils]
import ../core/version

proc nimbleTemplate*(projectName: string): string =
  result = fmt"""# Package

version       = "0.1.0"
author        = "Jazzy-CLI"
description   = "A new Jazzy web application"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.2.4"
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

proc main() =
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
  let todos = await DB.table("todos").get()
  ctx.json(todos)

# POST /todos
proc create*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "title": "required|min:3"
  })

  let id = await DB.table("todos").insert(%*{
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

  discard await DB.table("todos").where("id", id).update(%*{
    "completed": data["completed"].getBool
  })

  ctx.json(%*{"status": "updated"})

# DELETE /todos/:id
proc delete*(ctx: Context) {.async.} =
  let id = ctx.param("id")
  discard await DB.table("todos").where("id", id).delete()
  ctx.status(204).json(%*{"status": "deleted"})
"""

proc todoMigrationTemplate*(): string =
  result = """import jazzy

migration "00000000000000_create_todos":
  up:
    await createTable("todos")
      .increments("id")
      .string("title")
      .boolean("completed", default = false)
      .timestamps()
      .execute()
  down:
    await dropTable("todos")
"""

proc createdTableName(name: string): string =
  ## `make:migration create_users` reaches this helper as a timestamped name.
  ## Only infer a table where the conventional name is unambiguous; an
  ## `add_*`, `rename_*`, or `create_users_and_roles` migration needs a
  ## purpose-written rollback instead of a potentially destructive guess.
  const marker = "_create_"
  let start = name.find(marker)
  if start < 0 or start + marker.len >= name.len:
    return
  result = name[start + marker.len .. ^1]
  if result.contains("_and_") or result.contains("_with_"):
    result.setLen(0)
    return
  if result.endsWith("_table"):
    result.setLen(result.len - "_table".len)

proc migrationTemplate*(name: string): string =
  let tableName = createdTableName(name)
  if tableName.len > 0:
    result = "import jazzy\n\nmigration \"" & name & "\":\n" &
      "  up:\n" &
      "    await createTable(\"" & tableName & "\")\n" &
      "      .increments(\"id\")\n" &
      "      .timestamps()\n" &
      "      .execute()\n" &
      "  down:\n" &
      "    await dropTable(\"" & tableName & "\")\n"
    return

  result = "import jazzy\n\nmigration \"" & name & "\":\n" & """
  up:
    # Add the forward schema change here.
    discard
  down:
    # Reverse the exact up: operation here.
    # For a created table: await dropTable("TABLE_NAME")
    discard
"""

proc seederTemplate*(name: string): string =
  result = "import jazzy\n\nseed \"" & name & "\":\n" & """
  # Insert deterministic development/demo data here. Example:
  # discard await DB.table("users").insert(%*{"name": "Ada"})
  discard
"""

proc modelTemplate*(typeName, tableName: string): string =
  ## The common model shape for a `create_<table>` migration. Developers add
  ## domain fields after creating the matching migration.
  result = "import jazzy\n\nmodel " & typeName & ":\n" &
    "  table \"" & tableName & "\"\n\n" &
    "  id int64\n" &
    "  timestamps()\n"

proc controllerTemplate*(controllerName: string): string =
  "import jazzy\n\n# " & controllerName & " CRUD actions.\n" & """
proc index*(ctx: Context) {.async.} =
  ctx.json(%*[])

proc show*(ctx: Context) {.async.} =
  ctx.status(501).json(%*{"error": "Not implemented"})

proc store*(ctx: Context) {.async.} =
  ctx.status(501).json(%*{"error": "Not implemented"})

proc update*(ctx: Context) {.async.} =
  ctx.status(501).json(%*{"error": "Not implemented"})

proc destroy*(ctx: Context) {.async.} =
  ctx.status(501).json(%*{"error": "Not implemented"})
"""

proc migrationRunnerTemplate*(modules, seederModules: openArray[string]): string =
  ## Generated inside `.jazzy/` immediately before a CLI migration command.
  ## It is deliberately not part of the application's source tree.
  result = """import std/[asyncdispatch, os, strformat]
import jazzy

"""
  for moduleName in modules:
    result.add("import migrations/" & moduleName & " as " & moduleName & "\n")
  for moduleName in seederModules:
    result.add("import seeders/" & moduleName & " as " & moduleName & "\n")
  result.add("\nproc allMigrations(): seq[Migration] =\n")
  if modules.len == 0:
    result.add("  @[]\n")
  else:
    result.add("  @[")
    for index, moduleName in modules:
      if index > 0:
        result.add(", ")
      result.add(moduleName & ".jazzyMigration")
    result.add("]\n")
  result.add("\nproc allSeeders(): seq[Seeder] =\n")
  if seederModules.len == 0:
    result.add("  @[]\n")
  else:
    result.add("  @[")
    for index, moduleName in seederModules:
      if index > 0:
        result.add(", ")
      result.add(moduleName & ".jazzySeeder")
    result.add("]\n")
  result.add("""

proc printStatus() {.async.} =
  let applied = await migrationStatus()
  let pending = await pendingMigrations(allMigrations())
  if applied.len == 0 and pending.len == 0:
    echo "No migrations found."
    return
  for item in applied:
    echo fmt"[{item.batch}] {item.name}  {item.appliedAt}"
  for item in pending:
    echo fmt"[pending] {item.name}"

proc printPending() {.async.} =
  let pending = await pendingMigrations(allMigrations())
  if pending.len == 0:
    echo "No pending migrations."
    return
  echo "Would apply:"
  for item in pending:
    echo "  " & item.name

proc requiresForce(action: string): bool =
  action notin ["status", "pretend"]

proc main() =
  let action = if paramCount() == 0: "up" else: paramStr(1)
  let force = paramCount() > 1 and paramStr(2) == "--force"
  if isProduction() and requiresForce(action) and not force:
    echo "Refusing to change a production database without --force."
    quit(1)
  case action
  of "up":
    echo fmt"Applied {waitFor migrate(allMigrations())} migration(s)."
  of "step":
    echo fmt"Applied {waitFor migrateStep(allMigrations())} migration(s), one batch each."
  of "pretend":
    # Nim migration bodies are arbitrary compiled code, so Jazzy cannot
    # truthfully render SQL without executing them. This read-only preview
    # lists exactly which migrations would run instead.
    waitFor printPending()
  of "status":
    waitFor printStatus()
  of "rollback":
    echo fmt"Rolled back {waitFor rollback(allMigrations())} migration(s)."
  of "reset":
    echo fmt"Reset {waitFor reset(allMigrations())} migration(s)."
  of "fresh":
    echo fmt"Fresh-migrated {waitFor fresh(allMigrations())} migration(s)."
  of "seed":
    echo fmt"Ran {waitFor seedAll(allSeeders())} seeder(s)."
  of "fresh-seed":
    let migrated = waitFor fresh(allMigrations())
    let seeded = waitFor seedAll(allSeeders())
    echo fmt"Fresh-migrated {migrated} migration(s) and ran {seeded} seeder(s)."
  else:
    echo "Usage: jazzy migrate [--step|--pretend|--force]"
    echo "       jazzy migrate:status|migrate:rollback|migrate:reset|migrate:fresh [--force]"
    echo "       jazzy db:seed [--force]"
    quit(1)

when isMainModule:
  main()
"""
  )

proc gitignoreTemplate*(): string =
  result = """# Nim build artifacts
*.exe
*.dll
*.so
*.dylib
nimcache/
nimblecache/
.jazzy/

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

proc envTemplate*(jwtSecret: string): string =
  ## The CLI supplies a fresh random signing secret.
  result = """# Application Environment (development | production)
APP_ENV=development
LOG_LEVEL=debug
# Dev UI can execute SQL and is available only in development.
DEV_UI_ENABLED=true
# Trust X-Forwarded-* headers only behind a reverse proxy you control.
TRUST_PROXY=false
# Default limit when bodyLimit() is used without an explicit value.
BODY_LIMIT_MB=10
# Database (SQLite is the default; use postgres and DATABASE_URL in production.)
DB_CONNECTION=sqlite
DB_DATABASE=database.sqlite
# PostgreSQL pool settings apply per Mummy worker.
# DB_POOL_MIN=1
# DB_POOL_MAX=1
# For PostgreSQL, replace the SQLite settings with:
# DB_CONNECTION=postgres
# DATABASE_URL=postgresql://user:password@localhost:5432/app
# Enable only for browser forms that use the auth_token cookie.
CSRF_ENABLED=false
JWT_SECRET=""" & jwtSecret & "\n"

proc testConfigTemplate*(): string =
  result = """switch("path", "$projectDir/../src")
"""
