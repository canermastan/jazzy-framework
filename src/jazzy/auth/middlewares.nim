import ../core/[context, types]
import std/[asyncdispatch, json]
import ../auth/basic_auth

let guard*: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async.} =
  ## Middleware that ensures the user is authenticated.
  ## Returns 401 Unauthorized if not logged in.
  if not ctx.check():
    ctx.status(401).json(%*{"error": "Unauthorized"})
  else:
    await next(ctx)

let basicAuthGuard*: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async.} =
  ## Middleware that enforces Basic Auth authentication.
  ## Requires BASIC_AUTH_USER and BASIC_AUTH_PASSWORD in .env file.
  ## Returns 401 Unauthorized if credentials are missing or invalid.
  let username = getConfig("BASIC_AUTH_USER", "")
  let password = getConfig("BASIC_AUTH_PASSWORD", "")

  if username.len == 0 or password.len == 0:
    ctx.status(401).json(%*{"error": "Basic Auth not configured"})
    return

  if not ctx.validateBasicAuth(username, password):
    ctx.status(401).json(%*{"error": "Unauthorized"})
    return

  let authHeader = ctx.request.headers["Authorization"]
  let decoded = decode(authHeader[6..^1])
  let parts = decoded.split(":")
  ctx.auth.isLoggedIn = true
  ctx.auth.user = some(%*{"username": parts[0]})
  await next(ctx)
