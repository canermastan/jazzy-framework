# Jazzy Framework: AI Agent & Developer Guide

Jazzy is a high-performance, developer-friendly web framework for Nim, inspired by Laravel's DX. It is built on top of **Mummy** (multi-threaded HTTP server) and uses **Async** by default.

## 🚀 Core Philosophy
- **Context-First**: Every request handler receives a `Context` object (`ctx`) containing request, response, auth, and cache.
- **Thread-Safety**: All internal components (DB, Cache) use `Lock` or WAL mode to ensure safety in Mummy's multithreaded environment.
- **Automatic DX**: Framework automatically loads `.env` on `Jazzy.serve()` and provides a Dev UI in development mode.

---

## 🛠 Project Structure
- `src/`: Framework core logic.
- `docs/`: Comprehensive documentation.
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

- **Input**: `ctx.input("name")` (Checks query params then JSON body).
- **Params**: `ctx.param("id")` (URL parameters).
- **Validation**: `let data = ctx.validate(%*{"email": "required|email"})` (Throws 422 on failure).
- **Response**: `ctx.json(node)`, `ctx.text(str)`, `ctx.html(html)`, `ctx.status(404)`.
- **Auth**: `ctx.login(userNode)`, `ctx.logout()`, `ctx.check()` (bool), `ctx.user()` (Option).
- **IP**: `ctx.ip()` (Respects `TRUST_PROXY`).

---

## 🗄 Database (Query Builder & Schema)
Jazzy uses SQLite with thread-safe WAL mode.

### Query Builder (`DB`)
```nim
# Fetching
let user = DB.table("users").where("email", "test@test.com").first()
let posts = DB.table("posts").where("active", 1).limit(10).get()

# Mutations
let newId = DB.table("users").insert(%*{"title": "New Post"})
DB.table("users").where("id", 1).update(%*{"completed": true})
DB.table("users").where("deleted", 1).delete()
```

### Schema Builder
Fluent API for migrations (usually in `schema.nim`):
```nim
createTable("users")
  .increments("id")
  .string("email", nullable = false)
  .string("password")
  .boolean("is_admin", default = false)
  .execute()
```

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
- **Log Level**: Set `LOG_LEVEL` in `.env` (DEBUG, INFO, WARN, ERROR, NONE).
- **Request ID**: Every request has a UUID in `ctx.requestId` and `X-Request-Id` header.
- **Dev UI**: Available at `/dev-ui` in development mode.

---

## 🧪 Testing
Run all tests: `nimble test`.
Individual: `nim c -r --path:src tests/test_router.nim`.
