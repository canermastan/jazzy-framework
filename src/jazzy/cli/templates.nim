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

proc agentsTemplate*(): string =
  ## Project-level instructions for coding agents. Keep this application-focused
  ## rather than copying Jazzy's framework-maintainer instructions into every
  ## generated project.
  result = """# Jazzy Application Guide

This is a **Jazzy** application: a batteries-included, async web framework for
Nim, inspired by Laravel's developer experience and built on Mummy.

Read this file before changing application code. Full framework documentation:
https://canermastan.github.io/jazzyframework/en/

## Agent Workflow

Before changing code, inspect the relevant parts of the application:

1. `.env` (and `.env.example`, if present) for the selected database and
   runtime settings. Never expose secrets from either file.
2. `src/app.nim` for startup and global configuration.
3. `src/router.nim` for route ownership, route groups, and middleware.
4. Related files in `src/controllers/`, `src/models/`, `src/services/`,
   `src/migrations/`, `src/seeders/`, and `views/`.
5. Existing tests and conventions before inventing a new project structure.

Keep changes focused. Prefer Jazzy's built-in APIs over a new package or
abstraction. Do not add another HTTP framework, database layer, ORM, template
engine, or dependency unless the project explicitly requests it.

## Typical Project Layout

- `src/app.nim`: application entry point; registers routes then starts Jazzy.
- `src/router.nim`: all route registration and route-level middleware.
- `src/controllers/`: HTTP handlers. Keep them focused on request/response
  work, validation, and calling application services.
- `src/models/`: optional typed ORM models.
- `src/services/`: reusable business logic that has outgrown a controller.
- `src/migrations/`: versioned, forward-and-rollback schema changes.
- `src/seeders/`: explicit demo/development seed data.
- `views/`: Melody HTML templates.
- `tests/`: application behavior tests.

## Routing and Async Handlers

Every handler receives `ctx: Context` and is asynchronous:

```nim
import jazzy

proc showUser(ctx: Context) {.async.} =
  let id = ctx.param("id")
  ctx.json(%*{"id": id})

Route.get("/users/:id", showUser)
Route.post("/users", proc(ctx: Context) {.async.} =
  ctx.status(201).json(%*{"created": true})
)
```

Register routes in `src/router.nim`. Use `Route.group(...)` for middleware
groups and `Route.groupPath("/admin", @[middleware])` for a path prefix plus
middleware. Use `Jazzy.serveStatic(...)` for global static assets and
`Route.staticRoute(...)` for protected static files.

## Context: Input, Validation, and Responses

- `ctx.input("name")` looks through query parameters, JSON, and URL-encoded
  form data.
- `ctx.param("id")` reads a path parameter.
- `ctx.validate(%*{"email": "required|email"})` returns validated data or
  sends a 422 response.
- Respond with `ctx.json(node)`, `ctx.text(value)`, `ctx.html(value)`, or
  `ctx.status(404).json(...)`.

```nim
proc store(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "email": "required|email",
    "name": "required|min:2"
  })
  ctx.status(201).json(%*{"email": data["email"].getStr})
```

## Environment and Runtime Configuration

Jazzy loads `.env` automatically. Keep configuration in `.env`, not hard-coded
application code. Important values include:

```dotenv
APP_ENV=development
LOG_LEVEL=debug
DEV_UI_ENABLED=true
TRUST_PROXY=false
BODY_LIMIT_MB=10

# SQLite (default)
DB_CONNECTION=sqlite
DB_DATABASE=database.sqlite

# PostgreSQL alternative
# DB_CONNECTION=postgres
# DATABASE_URL=postgresql://user:password@127.0.0.1:5432/app
# DB_POOL_MIN=1
# DB_POOL_MAX=1

CSRF_ENABLED=false
JWT_SECRET=set-a-long-random-secret
```

New code must not call legacy `connectDB()`. SQLite and PostgreSQL are
configured from `.env`; MySQL/MariaDB is not supported by Jazzy yet.

The Dev UI is development-only. Its database explorer currently understands
SQLite metadata, so do not rely on it as a PostgreSQL administration tool.

## Await-First Database Queries

Every database query returns a `Future`: use `await` in a handler or `waitFor`
during startup. Do not invent `getAsync` or `findAsync` names.

```nim
let user = await DB.table("users").where("email", "ada@example.com").first()
let posts = await DB.table("posts")
  .whereIn("id", [1, 2, 3])
  .whereNotNull("published_at")
  .orderBy("id", "DESC")
  .limit(10)
  .get()

let insertedId = await DB.table("posts").insert(%*{"title": "Hello"})
let changed = await DB.table("posts").where("id", insertedId)
  .update(%*{"published": true})
let deleted = await DB.table("posts").where("id", insertedId).delete()
```

Use builder conditions such as `where`, `orWhere`, `whereNull`,
`whereNotNull`, `whereIn`, `whereNotIn`, `orWhereIn`, and `orWhereNotIn`.
Use `returning("id", "email")` when a mutation must return its row, especially
for UUID or custom primary keys.

Builder identifiers are validated and quoted. PostgreSQL parameters are
type-aware for normal builder queries, so a string route parameter works for a
`BIGINT`, UUID, boolean, JSONB, or timestamp column without manual casting.

## Transactions

Use `DB.transaction:` when related database writes must either all succeed or
all be rolled back. The block awaits the transaction internally; each query in
the block still uses `await`.

```nim
proc placeOrder(ctx: Context) {.async.} =
  var orderId: int64

  DB.transaction:
    orderId = await DB.table("orders").insert(%*{"status": "pending"})
    discard await DB.table("payments").insert(%*{"order_id": orderId})

  ctx.status(201).json(%*{"id": orderId})
```

SQLite pins its shared locked connection; PostgreSQL pins one pooled connection
for the entire block. Keep a transaction short and database-only: do not await
HTTP calls, file I/O, queues, or other slow work inside it. Nested transactions
are intentionally rejected until savepoint support exists.

## Raw SQL

Use `DB.table()` first. Use raw SQL only for a trusted, static query shape that
the builder does not express well, such as a specialized report or join:

```nim
let rows = await DB.raw("SELECT name FROM users WHERE id = ?", 7)
let changed = await DB.rawExec(
  "UPDATE users SET active = ? WHERE id = ?", true, 7)
```

Raw values use portable `?` placeholders; Jazzy turns them into PostgreSQL
`$1`, `$2`, and so on. Never interpolate request input into SQL structure. Raw
queries cannot infer PostgreSQL column types; use an explicit cast such as
`?::uuid` when required. Write `??` for a literal PostgreSQL `?` operator.

## Migrations and Schema

Every schema change needs a new migration. Create and apply it with:

```bash
jazzy make:migration add_status_to_orders
jazzy migrate
```

Never edit a migration that might already have run in another environment,
staging, or production. Add a new migration with a correct `down:` block.

```nim
migration "20260919120000_create_orders":
  up:
    await createTable("orders")
      .increments("id")
      .string("status")
      .foreignId("user_id").constrained("users")
      .timestamps()
      .execute()
  down:
    await dropTable("orders")
```

`createTable()` is strict by default: an existing table is an error. Use
`.ifNotExists()` only for intentionally idempotent setup. Use `alterTable()`
and a new migration for added, changed, renamed, or dropped columns. Migrations
are transactional on SQLite and PostgreSQL.

Useful commands:

```bash
jazzy migrate
jazzy migrate:status
jazzy migrate:rollback
jazzy migrate --step
jazzy migrate --pretend
jazzy migrate:fresh     # destructive
jazzy migrate:reset     # destructive
```

Database-changing migration commands require `--force` when `APP_ENV` is
`production`. Do not use `migrate:fresh` or `migrate:reset` against real data.

## Seeders

Seeders are explicit and never run during a normal migration:

```bash
jazzy make:seeder demo_users
jazzy db:seed
jazzy migrate:fresh --seed
```

Use deterministic, safe demo/development data. Do not put production secrets
or irreversible external side effects in a seeder.

## Optional Typed ORM

Jazzy's ORM is a typed layer over the same database connection and query
builder; it is optional. Use it for ordinary domain records, and keep using
`DB.table()` or `DB.raw()` for joins, reports, and precise partial updates.

```nim
model User:
  table "users"
  id int64
  displayName string, column = "display_name"
  bio Option[string]
  timestamps()

let user = await User.find(ctx.param("id"))
let activeUsers = await User.where("active", true).orderBy("id", "DESC").get()
```

Use `jazzy make:model User` to create a conventional skeleton. Models support
`Option[T]`, custom columns, custom primary keys, `find`, `first`, `all`,
`create`, `update`, `patch`, `delete`, `save`, pagination, scopes, factories,
dirty tracking, and lifecycle hooks.

Declare `hasOne`, `hasMany`, `belongsTo`, and `belongsToMany` inside a model
when the relationship is part of the domain. Use `with("posts.comments")` for
batched eager loading and avoid per-row relation queries.

## Views and Cache

Melody templates live in `views/`. Render with:

```nim
ctx.render("home", %*{"title": "Hello"})
ctx.renderCached("landing", %*{"title": "Hello"}, ttl = 3600)
```

Melody escapes `{{ $value }}` and renders raw HTML only through
`{!! $value !!}`. Prefer escaped output for untrusted content. Layouts use
`@extends`, `@yield`, and `@section`; partials use `@include`.

Use `ctx.cache` or `AppCache` for explicit application caching. Do not assume
the ORM automatically caches query results.

## Authentication, Middleware, and Security

- `guard` is the JWT authentication middleware. `basicAuthGuard` protects a
  route with HTTP Basic authentication.
- Use `ctx.login(...)`, `ctx.logout()`, `ctx.check()`, and `ctx.user()` for
  Jazzy auth flows already adopted by this project.
- Use `cors()`, `rateLimit(...)`, and `bodyLimit(...)` where appropriate.
- Keep `JWT_SECRET`, database credentials, tokens, and passwords out of source
  control and logs. Never copy `.env` values into a response or test output.
- Respect existing `TRUST_PROXY`, CSRF, validation, and authorization choices.
- Never interpolate untrusted input into raw SQL, file paths, shell commands,
  redirects, or raw HTML.

## Verification

Run the smallest relevant check first, then broader checks when practical:

```bash
nimble test
jazzy migrate:status
nimble c -r src/app.nim
```

For PostgreSQL work, test with a real `DATABASE_URL`. Explain any test that
could not run and why. Preserve existing user changes: do not use destructive
Git commands or overwrite unrelated files.
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
