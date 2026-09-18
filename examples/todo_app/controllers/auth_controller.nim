import jazzy
import ../services/auth_service

proc login*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "username": "required|min:3",
    "password": "required|min:4"
  })

  let user = await auth_service.login(data["username"].getStr, data[
      "password"].getStr)
  if user.isSome:
    let token = ctx.login(authClaims(user.get))
    ctx.json(%*{"token": token})
  else:
    ctx.status(401).json(%*{"error": "Invalid credentials"})

proc register*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "username": "required|min:3",
    "password": "required|min:6"
  })

  let id = await auth_service.register(data["username"].getStr, data[
      "password"].getStr)
  ctx.status(201).json(%*{"id": id, "message": "User registered successfully"})

proc me*(ctx: Context) {.async.} =
  let u = ctx.user
  if u.isSome:
    ctx.json(u.get)
  else:
    ctx.status(401).json(%*{"error": "Unauthenticated"})
