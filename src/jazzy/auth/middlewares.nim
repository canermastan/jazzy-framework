import ../core/[context, types]
import std/[asyncdispatch, json, base64]
import ../core/config

let guard*: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async.} =
  ## Middleware that ensures the user is authenticated.
  ## Returns 401 Unauthorized if not logged in.
  if not ctx.check():
    ctx.status(401).json(%*{"error": "Unauthorized"})
  else:
    await next(ctx)

let basicAuthGuard*: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async.} =
  let username = getConfig("BASIC_AUTH_USER", "")
  let password = getConfig("BASIC_AUTH_PASSWORD", "")

  if username.len == 0 or password.len == 0:
    ctx.status(401).json(%*{"error": "Basic Auth not configured"})
    return

  let authHeader = ctx.request.headers.getOrDefault("Authorization")
  if not authHeader.startsWith("Basic "):
    ctx.status(401).json(%*{"error": "Unauthorized"})
    return

  let encoded = authHeader[6..^1]
  let decoded = decode(encoded)
  let parts = decoded.split(":")
  if parts.len < 2:
    ctx.status(401).json(%*{"error": "Unauthorized"})
    return

  let reqUser = parts[0]
  let reqPass = decoded.substr(reqUser.len + 1)

  if reqUser == username and reqPass == password:
    ctx.auth.isLoggedIn = true
    ctx.auth.user = some(%*{"username": reqUser})
    await next(ctx)
  else:
    ctx.status(401).json(%*{"error": "Unauthorized"})
