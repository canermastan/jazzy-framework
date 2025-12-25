# 🎷 Jazzy Framework

**Write Less Code, Build More Features.**

**The Productive Framework.** Developer-friendly, lightning fast, and designed for rapid development.

---

## THE POWER SNIPPET

See how easy it is to validate input, save to the database, and return a response.

```nim
proc createTodo*(ctx: Context) {.async.} =
  # 1. VALIDATE (Automatic 422 on failure)
  let data = ctx.validate(%*{
    "title": "required|min:3",
    "priority": "int|between:1,5"
  })

  # 2. DATABASE (Fluent API)
  let id = DB.table("todos").insert(%*{
    "title": data["title"].getStr,
    "priority": data["priority"].getInt,
    "completed": 0
  })

  # 3. RESPONSE
  ctx.status(201).json(%*{"id": id, "status": "created"})
```

---

## EVERYTHING YOU NEED TO SHIP IT

Jazzy comes batteries-included so you can focus on your product, not the plumbing.

*   **⚡ Lightning Fast**: Powered by `Mummy`, keeping your app blazing fast.
*   **🛡️ Built-in Auth**: JWT Authentication and Middleware ready to go.
*   **💾 Fluent ORM**: A lightweight, expressive query builder.
*   **✅ Validation**: Declarative validation rules (Laravel style).
*   **⚙️ Zero Config**: Auto-loads `.env` and just works.

---

## QUICK START

```bash
nimble install jazzy
```

### `app.nim`

```nim
import jazzy

proc home(ctx: Context) =
  ctx.text("Hello Jazzy!")

Route.get("/", home)
Jazzy.serve(8080)
```

Run it:
```bash
nim c -r app.nim
```

---

## FEATURES IN DEPTH

### 1. DATABASE
Jazzy makes database interactions trivial.

```nim
connectDB("app.db")

# Fetch
let users = DB.table("users").where("active", 1).get()

# First
let user = DB.table("users").where("id", 5).first()

# Insert
DB.table("logs").insert(%*{"level": "info", "msg": "Login"})
```

### 2. ROUTING & GROUPS
Organize your routes cleanly. Secure them with middleware easily.

```nim
Route.groupPath("/api/v1", guard):
  Route.get("/todos", listTodos) # required bearer token
  Route.post("/todos", createTodo) # required bearer token
  Route.delete("/todos/:id", deleteTodo) # required bearer token
```

### 3. AUTHENTICATION
Secure your app in minutes.

```nim
# Login
let token = ctx.login(%*{"id": 1, "role": "admin"})

# Protect
if ctx.check():
  echo "User is logged in!"
```

### 4. CONFIGURATION
Jazzy automatically reads your `.env` file.

```env
JWT_SECRET=my-secret-key
```

```nim
let secret = getConfig("JWT_SECRET")
```

---

**Jazzy pays the boilerplate tax so you don't have to.**

Made with ❤️ by the Jazzy Team.
