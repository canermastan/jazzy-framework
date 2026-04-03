import std/[base64, asyncdispatch]
import ../core/[context, types]
import config

proc basicAuthMiddleware*(): MiddlewareProc =
  let username = getConfig("BASIC_AUTH_USER", "")
  let password = getConfig("BASIC_AUTH_PASSWORD", "")

  if username.len == 0 or password.len == 0:
    return proc(ctx: Context, next: HandlerProc) {.async.} =
      await next(ctx)

  return proc(ctx: Context, next: HandlerProc) {.async.} =
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
