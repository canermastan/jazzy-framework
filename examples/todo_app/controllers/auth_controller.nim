import jazzy
import ../services/todo_service
import ../services/auth_service

proc login*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "username": "required|min:3",
    "password": "required|min:4"
  })

  let user = auth_service.login(data["username"].getStr, data[
      "password"].getStr)
  if user.isSome:
    let token = ctx.login(user.get)
    ctx.json(%*{"token": token})
  else:
    ctx.status(401).json(%*{"error": "Invalid credentials"})

proc register*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "username": "required|min:3",
    "password": "required|min:6"
  })

  let id = auth_service.register(data["username"].getStr, data[
      "password"].getStr)
  ctx.json(%*{"message": "User registered successfully"})

proc me*(ctx: Context) {.async.} =
  let u = ctx.user
  if u.isSome:
    ctx.json(u.get)
  else:
    ctx.status(401).json(%*{"error": "Unauthenticated"})
