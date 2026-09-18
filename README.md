<div align="center">
  <h1>🎷 Jazzy Framework</h1>
  <p><strong>Write Less Code, Build More Features.</strong></p>
  <p><em>The high-performance, batteries-included web framework for Nim.</em></p>

  <p>
    <a href="https://nim-lang.org/"><img src="https://img.shields.io/badge/Nim-2.2.4%2B-FFE953?style=flat-square&logo=nim&logoColor=000" alt="Nim 2.2.4+"></a>
    <a href="https://github.com/canermastan/jazzy-framework/releases"><img src="https://img.shields.io/github/v/tag/canermastan/jazzy-framework?style=flat-square&color=blueviolet&label=version" alt="Version"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License"></a>
  </p>

  <p>
    <a href="#why-jazzy">Why Jazzy?</a> •
    <a href="#the-power-snippet">Power Snippet</a> •
    <a href="#quick-start">Quick Start</a> •
    <a href="#features-in-depth">Features in Depth</a> •
    <a href="#documentation">Documentation</a>
  </p>
</div>

---

## Why Jazzy?

When building a web application, piecing together third-party libraries, wiring up middleware, and hand-crafting database or auth infrastructure is a massive time sink.

**Jazzy Framework** is a batteries-included web framework designed for maximum developer productivity. From authentication and declarative validation to a fluent database query builder and the Melody template engine, everything you need to ship production web apps comes built right in. Powered by the multi-threaded **Mummy** HTTP server under the hood, Jazzy delivers blazing-fast performance without sacrificing developer experience.

> 🖥️ **Building Desktop Apps?** Check out [Jazzy Desktop](https://github.com/canermastan/jazzy-desktop) — build cross-platform desktop applications powered by Jazzy Framework & React / Vue / Svelte under the hood!

---

## EVERYTHING YOU NEED TO SHIP IT

* **⚡ Lightning Fast Core:** Multi-threaded Mummy HTTP engine under the hood for maximum throughput.
* **🛡️ Built-in Auth & Security:** Out-of-the-box JWT Authentication, Basic Auth, Rate Limiting, and CORS protection.
* **💾 Database Toolkit:** Await-first SQLite and PostgreSQL query builder, transactional migrations, and an optional typed ORM.
* **✅ Declarative Validation:** Expressive validation rules that automatically return `422 Unprocessable Entity` on failure.
* **🎨 Melody Template Engine:** Nim-native HTML rendering engine with zero allocations, layout inheritance, and hot-reload.
* **⚙️ Zero Setup & Dev UI:** Automatic `.env` loading and a built-in `/dev-ui` dashboard for real-time monitoring during development.

> 💡 **Developer Mode UI:** When running in dev mode (`Jazzy.serve(8080)`), navigate to `http://localhost:8080/dev-ui` in your browser to inspect routes, request logs, and memory cache in real time.

---

## THE POWER SNIPPET

Validating input, persisting to the database, and returning a structured response — all in a single clean handler:

```nim
proc createTodo*(ctx: Context) {.async.} =
  # 1. VALIDATE (Automatic 422 JSON response on failure)
  let data = ctx.validate(%*{
    "title": "required|min:3",
    "priority": "int|between:1,5"
  })

  # 2. DATABASE (Fluent API)
  let id = await DB.table("todos").insert(%*{
    "title": data["title"].getStr,
    "priority": data["priority"].getInt,
    "completed": 0
  })

  # 3. RESPONSE
  ctx.status(201).json(%*{"id": id, "status": "created"})
```

---

## QUICK START

### 1. Install
```bash
nimble install jazzy
```

### 2. Create `app.nim`
```nim
import jazzy

Route.get("/", proc(ctx: Context) {.async.} =
  ctx.text("Hello Jazzy!")
)

Jazzy.serve(8080)
```

### 3. Run It
```bash
nim c -r app.nim
```

---

## FEATURES IN DEPTH

### 1. Context-First Architecture (`ctx`)
Every handler receives a thread-safe `Context` object managing the request and response lifecycle:
* **Input Gathering:** `ctx.input("key")` (Automatically searches query params, JSON body, and form payloads).
* **Auth & Sessions:** `ctx.login(userNode)`, `ctx.logout()`, `ctx.check()`.
* **Response Helpers:** `ctx.json(...)`, `ctx.text(...)`, `ctx.html(...)`, `ctx.render(...)`.

### 2. Melody Template Engine (Nim Syntax)
A zero-allocation, clean HTML rendering engine with native Nim syntax and layout inheritance:

```html
<!-- views/layouts/app.html (Parent Layout) -->
<!DOCTYPE html>
<html>
<body>
  @include "partials/navbar"
  <main>
    @yield "content"
  </main>
</body>
</html>
```

```html
<!-- views/home.html (Child View) -->
@extends "layouts/app"

@section "content"
  <h1>Welcome, {{ $user.name }}!</h1>

  @if user.isAdmin
    <p>Admin Dashboard</p>
  @else
    <p>User Dashboard</p>
  @endif

  <ul>
    @for item in todos
      <li>{{ $item.title }}</li>
    @endfor
  </ul>
@endsection
```

### 3. Database, Migrations & ORM
Await-first query builder. SQLite is the zero-config default; PostgreSQL uses a native async pool:
```nim
# Fetching Data
let users = await DB.table("users").where("active", true).get()

# Conditions and mutation results
let active = await DB.table("users")
  .whereIn("id", [1, 2, 3])
  .whereNotNull("email")
  .get()
let changed = await DB.table("users").where("id", 1).update(%*{"active": false})

# Return inserted/updated columns on either driver
let user = await DB.table("users").returning("id", "email").insert(%*{
  "email": "ada@example.com"
})

# Schema setup
await createTable("users")
  .increments("id")
  .string("email", nullable = false)
  .unique("email")
  .execute()
```

```env
# SQLite (default)
DB_CONNECTION=sqlite
DB_DATABASE=database.sqlite

# PostgreSQL
# DB_CONNECTION=postgres
# DATABASE_URL=postgresql://user:password@localhost:5432/app
```

Jazzy quotes builder identifiers, so table and column names such as `order` are safe. Raw SQL accepts portable `?` placeholders on both drivers; in PostgreSQL raw SQL, write `??` for a literal question mark (for example the JSON `?` operator).

Use versioned, transactional migrations for schema changes:

```bash
jazzy make:migration create_users
jazzy migrate
jazzy migrate:status
jazzy migrate:rollback
jazzy migrate --step
jazzy migrate --pretend
jazzy migrate:fresh
```

Migration files live only in `src/migrations/`. Jazzy self-generates its
compiled runner under ignored `.jazzy/`, so projects have no registry or
`migrate.nim` file to maintain. `migrate:fresh`, `migrate:reset`, and all
database-changing migration commands require `--force` when `APP_ENV=production`.

For explicit demo/reference data, use `jazzy make:seeder demo_users` and
`jazzy db:seed`; `jazzy migrate:fresh --seed` recreates a local database and
runs the seeders.

The optional ORM uses the same configured database and pool as `DB.table()`:

```nim
model User:
  table "users"
  id int64
  displayName string, column = "display_name"
  bio Option[string]
  timestamps()

let user = await User.patch(1, %*{"displayName": "Ada"})
let users = await User.whereNotNull("displayName").get()
```

Models also support `hasOne`, `hasMany`, `belongsTo`, `belongsToMany`, nested
batch loading (`User.with("posts.comments")`), pivot `attach`/`detach`/`sync`,
typed factories, enum/`DateTime` fields, dirty tracking, and lifecycle hooks.

Existing projects can preview the await-first upgrade before changing files:

```bash
jazzy upgrade db-async
jazzy upgrade db-async --apply
jazzy upgrade db-async --check
```

The upgrader changes direct calls inside `.async.` procedures and reports
ambiguous synchronous call sites with their file and line number.

### 4. Routing & Middleware Guards
```nim
Route.groupPath("/admin", @[authGuard, cors()]):
  Route.get("/dashboard", handleDashboard)
```

### 5. Memory Cache
Thread-safe in-memory cache shared across all Mummy worker threads:
```nim
ctx.cache.put("stats", data, ttl = 3600)
```

<br/>

<details>
<summary>🔍 <b>View More Code Examples (Controllers, Middleware, Redirects...)</b></summary>

<br/>

#### Controller / Handler Example (`isNull` Helper)
```nim
proc showProfile*(ctx: Context) {.async.} =
  let userId = ctx.param("id")
  let user = await DB.table("users").where("id", userId).first()
  
  # Using Jazzy's built-in isNull helper
  if user.isNull():
    ctx.status(404).json(%*{"error": "User not found"})
    return

  ctx.render("profile", %*{"user": user})
```

#### Custom Middleware
```nim
let customHeaderMiddleware* = Middleware(
  name: "CustomHeader",
  handler: proc(ctx: Context, next: HandlerProc) {.async.} =
    ctx.header("X-Framework", "Jazzy")

    # Crucial: Always call next(ctx) to continue the middleware chain
    await next(ctx)
)
```

#### Redirects & Custom Response Headers
```nim
proc handleOldUrl*(ctx: Context) =
  # 302 Redirect
  ctx.redirect("/new-url")

proc handleDownload*(ctx: Context) =
  # Custom response headers and raw payload
  ctx.header("Content-Type", "application/pdf")
  ctx.text("PDF Binary Content")
```

</details>

---

## DOCUMENTATION

📖 For full documentation, guides, and comprehensive API references:
👉 **[Jazzy Framework Documentation](https://canermastan.github.io/jazzyframework/)**

---

## ⭐️ Star History

<div align="center">
  <a href="https://www.star-history.com/?repos=canermastan%2Fjazzy-framework&type=date&legend=top-left">
   <picture>
     <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=canermastan/jazzy-framework&type=date&theme=dark&legend=top-left" />
     <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=canermastan/jazzy-framework&type=date&legend=top-left" />
     <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=canermastan/jazzy-framework&type=date&legend=top-left" />
   </picture>
  </a>
</div>

---

<div align="center">
  <sub>
    Built with ❤️ and <a href="https://nim-lang.org/">Nim</a> &nbsp;·&nbsp;
    <a href="LICENSE">MIT License</a>
  </sub>
</div>
