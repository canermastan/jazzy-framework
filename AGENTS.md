# Jazzy Framework: AI Agent & Developer Guide

Jazzy is a high-performance, developer-friendly web framework for Nim, inspired by Laravel's DX. It is built on top of **Mummy** (multi-threaded HTTP server) and uses **Async** by default.

## 🚀 Core Philosophy
- **Context-First**: Every request handler receives a `Context` object (`ctx`) containing request, response, auth, and cache.
- **Thread-Safety**: All internal components (DB, Cache) use `Lock` or WAL mode to ensure safety in Mummy's multithreaded environment.
- **Automatic DX**: Framework loads `.env` automatically before serving and lazily for database/schema work that runs before `Jazzy.serve()`. The Dev UI is explicit opt-in in development mode.

---

## 🛠 Project Structure
- `src/`: Framework core logic.
- `jazzyframework/`: Starlight documentation website and its own nested Git repository.
- `examples/`: Reference implementations (e.g., `todo_app`).
- `tests/`: Comprehensive test suites.

---

## 🛣 Routing & Middleware
Routes are registered globally via the `Route` object.

```nim
import jazzy

proc handleUser(ctx: Context) {.async.} =
  let id = ctx.param("id")
  ctx.json(%*{"id": id})

# Basic Routes
Route.get("/", proc(ctx: Context) {.async.} = ctx.text("Welcome"))
Route.get("/users/:id", handleUser)

# Middleware Groups
Route.group(guard): # Auth guard (Middleware object)
  Route.post("/api/settings", handleSettings)

# Path Prefix + Middleware
Route.groupPath("/admin", @[adminGuard, cors()]):
  Route.get("/dashboard", handleDashboard)
```

### Static Files
- **Global**: `Jazzy.serveStatic("public", "/assets")` (Mounted as global middleware).
- **Protected**: `Route.staticRoute("docs", "/admin/docs", @[authGuard])` (Supports wildcards and middleware).

---

## 🛡 Middleware
Middlewares in Jazzy are **objects** containing a `name` and a `handler`.

### Built-in Middlewares
- `rateLimit(max, window)`: IP-based rate limiting with headers.
- `bodyLimit(mb)`: Restricts payload size (413 Payload Too Large).
- `cors()`: Handles Preflight and CORS headers.
- `guard`: JWT-based authentication check.
- `basicAuthGuard`: HTTP Basic Auth check.

---

## ⚡ The Context Object (`ctx`)
The `ctx` object is the primary interface for handlers:

- **Input**: `ctx.input("name")` (Checks query params, JSON body, then Form x-www-form-urlencoded).
- **Params**: `ctx.param("id")` (URL parameters).
- **Validation**: `let data = ctx.validate(%*{"email": "required|email"})` (Throws 422 on failure).
- **Response**: `ctx.json(node)`, `ctx.text(str)`, `ctx.html(html)`, `ctx.status(404)`.
- **Auth**: `ctx.login(userNode)`, `ctx.loginWithRefresh(user, refreshToken)`, `ctx.getRefreshToken()`, `ctx.logout()`, `ctx.check()` (bool), `ctx.user()` (Option).
- **IP**: `ctx.ip()` (Respects `TRUST_PROXY`).

---

## 🎨 Melody Template Engine
Jazzy includes a blazing-fast, zero-allocation template engine named **Melody** (inspired by Blade).

### Rendering Views
Views are placed in the `views/` directory.
```nim
# Normal render
ctx.render("home", %*{"title": "Hello", "success": true})

# Cached render (Tier-2 Cache)
ctx.renderCached("landing", %*{"data": "static"}, ttl=3600)
```

### Syntax & Features
- **Variables**: `{{ $var }}` (Escaped) / `{!! $var !!}` (Raw/Unescaped).
- **CSRF Token**: `{{ $csrf_token }}` (Automatically injected to view globals if CSRF is enabled). Example: `<input type="hidden" name="_csrf" value="{{ $csrf_token }}">`
- **Control Flow**: `@if(cond) ... @else ... @endif`
- **Loops**: `@foreach(items as item) ... @endforeach`
- **Layouts**: 
  - Parent (`views/layouts/app.html`): Uses `@yield("content")`
  - Child (`views/home.html`): Uses `@extends("layouts/app")` and `@section("content") ... @endsection`
  - Partials: `@include("partials/navbar")`

### Caching
- **Dev Mode**: Reads from disk on every request (Hot Reload, no restart required).
- **Prod Mode**: Tier-1 (File mtime-invalidated memory cache) + Tier-2 (Hash-based HTML cache via `renderCached`).

---

## 🗄 Database (Query Builder, Migrations & ORM)
Jazzy has an await-first query builder for **SQLite** and **PostgreSQL**.
Every database query returns a `Future` and must use `await` inside an async
handler, or `waitFor` during startup. `DB.transaction:` is the one block-form
exception: it awaits its transaction internally, while the queries in the
block still use `await`. Do not introduce `getAsync`-style method names:
`await DB.table(...).get()` is the public DX.

### Configuration

New applications configure the driver in `.env`; do not call `connectDB()` in
new code. `connectDB(path)` remains a legacy SQLite compatibility API.

```env
# SQLite (default)
DB_CONNECTION=sqlite
DB_DATABASE=database.sqlite

# PostgreSQL
# DB_CONNECTION=postgres
# DATABASE_URL=postgresql://user:password@127.0.0.1:5432/app
# DB_POOL_MIN=1
# DB_POOL_MAX=1
```

SQLite uses a shared, locked WAL connection. PostgreSQL owns one async pool per
Mummy OS worker; `DB_POOL_MIN` and `DB_POOL_MAX` therefore apply **per worker**.
Start with `1`/`1`. MySQL/MariaDB is not supported yet.

### Query Builder (`DB`)

```nim
# Fetching
let user = await DB.table("users").where("email", "test@test.com").first()
let posts = await DB.table("posts")
  .whereIn("id", [1, 2, 3])
  .whereNotNull("published_at")
  .orderBy("id", "DESC")
  .limit(10)
  .get()

# Mutations return the numeric id or affected-row count.
let newId = await DB.table("users").insert(%*{"title": "New Post"})
let updated = await DB.table("users").where("id", 1)
  .update(%*{"completed": true})
let deleted = await DB.table("users").where("id", 1).delete()

# Use returning for one expected changed record or a custom/UUID primary key.
let createdUser = await DB.table("users").returning("id", "email")
  .insert(%*{"email": "test@test.com"})
```

Available condition helpers include `where`, `orWhere`, `whereNull`,
`whereNotNull`, `whereIn`, `whereNotIn`, `orWhereIn`, and `orWhereNotIn`.
`withTrashed`, `onlyTrashed`, `restore`, and `forceDelete` support soft-delete
tables. `update`, `delete`, `restore`, and `forceDelete` return affected rows.

Builder identifiers are validated and SQL-quoted, so reserved names such as
`order` work. PostgreSQL builder parameters are type-aware from table metadata:
string route parameters work for `BIGINT`, UUID, boolean, JSONB, and timestamp
columns without app-level casts.

### Transactions

Use `DB.transaction:` when multiple writes must either all succeed or all be
rolled back. The transaction block awaits its driver work internally, while
each query in the block remains explicitly awaited:

```nim
DB.transaction:
  let orderId = await DB.table("orders").insert(%*{"status": "pending"})
  discard await DB.table("payments").insert(%*{"order_id": orderId})
```

SQLite pins its locked shared connection; PostgreSQL pins one pooled connection
for the whole block. A `CatchableError` rolls back and is re-raised. Keep the
block database-only and short: do not await HTTP, file, or other long-running
work inside it. Nested transactions are intentionally rejected for now rather
than silently creating unexpected transaction boundaries.

### Raw SQL

```nim
let rows = await DB.raw("SELECT name FROM users WHERE id = ?", 7)
let changed = await DB.rawExec("UPDATE users SET active = ? WHERE id = ?", false, 7)
```

Raw SQL uses portable `?` placeholders. Jazzy converts them to PostgreSQL
`$1`, `$2`, ... automatically. Write `??` for a literal PostgreSQL question
mark operator (for example JSONB `?`). Raw queries cannot infer a column type;
use explicit PostgreSQL casts such as `?::uuid` when needed.

### Migrations

New projects already include versioned migration infrastructure rather than
running schema setup at every server boot: after `jazzy new`, configure `.env`
and run `jazzy migrate`. `jazzy migrations:init` exists only to add the same
visible `src/migrations/` folder to a project created before migrations were
available. The CLI discovers those files and compiles a self-regenerating,
ignored `.jazzy/migration_runner.nim`; never add a `migrate.nim` or registry to
an application:

```bash
jazzy make:migration create_users
jazzy migrate
jazzy migrate:status # applied batches plus pending files
jazzy migrate:rollback
jazzy migrate --step
jazzy migrate --pretend
jazzy migrate:fresh
```

A migration uses one declaration with both forward and rollback logic:

```nim
migration "20260917143000_create_users":
  up:
    await createTable("users")
      .increments("id")
      .string("email")
      .unique("email")
      .timestamps()
      .execute()
  down:
    await dropTable("users")
```

Migrations and their history rows are transactional on SQLite and PostgreSQL.
`--pretend` lists pending names without executing arbitrary Nim migration
bodies or creating history state. `migrate:fresh` and `migrate:reset` are
destructive. All database-changing migration commands require `--force` with
`APP_ENV=production`. Never alter a migration that has already been
deployed—create a new migration instead.

Seeders are explicit and live in `src/seeders/`: use `jazzy make:seeder name`,
`jazzy db:seed`, or `jazzy migrate:fresh --seed`. They never run as part of a
normal migration.

### Schema Builder

The schema builder creates tables and is normally called inside a migration's
`up:` or `down:` block. `createTable()` is strict by default: an unexpected
existing table aborts the migration. Use `.ifNotExists()` only for intentional
idempotent setup. `execute()` is async:

```nim
migration "20260917143000_create_users":
  up:
    await createTable("users")
      .increments("id")
      .string("email", nullable = false)
      .string("password")
      .boolean("is_admin", default = false)
      .timestamps()
      .execute()
```

`increments` maps to SQLite `INTEGER PRIMARY KEY AUTOINCREMENT` and PostgreSQL
`BIGSERIAL PRIMARY KEY`; booleans and timestamps are mapped per driver.

Use `foreignId("user_id").constrained("users")` for a portable foreign key;
chain `onDelete("CASCADE")`/`onUpdate(...)` when needed. `index(...)` and
`unique(...)` create portable indexes. Existing tables can use
`alterTable("users").addString(...).renameColumn(...).dropColumn(...).execute()`, while
`renameColumn`, `renameTable`, and `dropTable` are standalone async helpers.

### Optional ORM

Jazzy's ORM is a typed convenience layer over the same public query builder;
it does not own another pool or driver. It is optional—`DB.table()` remains a
first-class API for joins, partial updates, and custom SQL.

```nim
model User:
  table "users"
  uuid string, column = "user_uuid", primaryKey = true
  displayName string, column = "display_name"
  bio Option[string]
  timestamps()

let user = await User.find(ctx.param("id"))
let changed = await User.patch(ctx.param("id"), %*{"displayName": "Ada"})
```

Models support nullable scalar `Option[T]` fields, `column = "..."` mapping,
and `primaryKey = true` on a custom key. `patch()` rejects custom keys and
managed timestamps, preventing accidental identity changes. `find()`/`first()`,
`update()`, and `patch(id, ...)` return `Option[T]`.
`modelData(value)` serializes one model, while `modelData(models)` serializes
the `seq[Model]` returned by `get()` directly for `ctx.json()`.

Relations are declared in the same block with explicit keys:

```nim
hasOne profile, Profile, foreignKey = "userId"
hasMany posts, Post, foreignKey = "userId"
belongsTo author, User, foreignKey = "authorId"
belongsToMany roles, Role,
  through = "role_user", foreignKey = "user_id", relatedKey = "role_id"

let users = await User.with("posts.comments", "roles").get()
let page = await User.where("active", true).paginate(page = 1, perPage = 20)
```

Relation target models must already be in scope. `with()` batches nested
relation paths, scopes are declared with `scope name:`, and `Page[T]` exposes
`data`, `total`, `perPage`, `currentPage`, and `lastPage`. `createRelated()`
creates declared has-one/has-many children; `attach`, `detach`, and `sync`
manage many-to-many pivots. Models also support native enum/`DateTime` casts,
`make`/`factory`, `dirty`/`isDirty`, `user = await user.save()`, and the typed
`beforeCreate`/`afterCreate`/`beforeUpdate`/`afterUpdate`/delete hooks.

---

## 💾 Memory Cache (Thread-Safe)
Shared across all threads, accessible via `ctx.cache` or global `AppCache`.

```nim
ctx.cache.put("key", "value", 3600)
let val = ctx.cache.get("key", "default")
let user = ctx.cache.getJson("user_json")
```

---

## 📝 Logging & Debugging
- **Log Level**: Set `LOG_LEVEL` in `.env` (`DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, or `NONE`).
- **Request ID**: Every request has a UUID in `ctx.requestId` and `X-Request-Id` header.
- **Dev UI**: Available only when `APP_ENV=development` and `DEV_UI_ENABLED=true`. Its table browser/schema viewer currently use SQLite metadata; PostgreSQL explorer support is pending.

---

## 🧪 Testing
Run all tests: `nimble test`.
Individual: `nim c -r --path:src tests/test_router.nim`.

Run the real PostgreSQL builder suite with a running server and
`JAZZY_POSTGRES_TEST_DSN` set, for example:

```powershell
$env:JAZZY_POSTGRES_TEST_DSN = "postgresql://jazzy:password@127.0.0.1:55432/app"
nim c -r --path:src tests/test_postgres_builder.nim
```

Run `tests/test_postgres_migrations.nim` with the same DSN to verify pinned
PostgreSQL migration transactions. `tests/test_orm_and_migrations.nim` covers
the SQLite migration runner, single-block ORM API, and public transaction
blocks. `tests/test_postgres_transactions.nim` verifies public transaction
commit/rollback behavior against a real PostgreSQL server.
`tests/test_postgres_orm.nim` verifies mapped/nullable models and eager
relations, has-one, nested loading, and pivot writes against a real PostgreSQL
server when `JAZZY_POSTGRES_TEST_DSN` is set.

Existing projects can preview/apply the await-first conversion with
`jazzy upgrade db-async`, `jazzy upgrade db-async --apply`, and
`jazzy upgrade db-async --check`.
