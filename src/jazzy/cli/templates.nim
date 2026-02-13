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

proc authControllerTemplate*(): string =
  result = """import jazzy
import ../services/auth_service

proc login*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "email": "required|email",
    "password": "required|min:4"
  })

  let user = auth_service.login(data["email"].getStr, data["password"].getStr)
  if user.isSome:
    let token = ctx.login(user.get)
    ctx.json(%*{"token": token})
  else:
    ctx.status(401).json(%*{"error": "Invalid credentials"})

proc register*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "email": "required|email",
    "password": "required|min:6"
  })

  discard auth_service.register(data["email"].getStr, data["password"].getStr)
  ctx.json(%*{"message": "User registered successfully"})

proc me*(ctx: Context) {.async.} =
  let u = ctx.user
  if u.isSome:
    ctx.json(u.get)
  else:
    ctx.status(401).json(%*{"error": "Unauthenticated"})

proc logout*(ctx: Context) {.async.} =
  ctx.logout()
  ctx.json(%*{"message": "Logged out successfully"})
"""

proc authServiceTemplate*(): string =
  result = """import jazzy
import std/[json, options]

proc login*(email, password: string): Option[JsonNode] =
  let user = DB.table("users").where("email", email).first()
  if user.kind != JNull and verifyPassword(password, user["password"].getStr):
    return some(user)
  else:
    return none(JsonNode)

proc register*(email, password: string): int =
  let hashedPassword = hashPassword(password)
  return DB.table("users").insert(%*{
    "email": email,
    "password": hashedPassword
  })
"""

proc schemaTemplate*(withAuth: bool): string =
  if withAuth:
    result = """import jazzy

proc initSchema*() =
  createTable("users")
    .increments("id")
    .string("email")
    .string("password")
    .execute()
"""
  else:
    result = ""

proc routerWithAuthTemplate*(): string =
  result = """import jazzy
import controllers/home_controller
import controllers/auth_controller

proc registerRoutes*() =
  # Public routes
  Route.get("/", home_controller.index)

  # Auth routes
  Route.post("/auth/login", auth_controller.login)
  Route.post("/auth/register", auth_controller.register)

  # Protected routes (requires JWT token)
  Route.groupPath("/auth", guard):
    Route.get("/me", auth_controller.me)
    Route.post("/logout", auth_controller.logout)
"""

proc appWithSchemaTemplate*(projectName: string): string =
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
