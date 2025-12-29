import jazzy/core/[context, types]
import std/[asyncdispatch, json, httpcore]

let guard*: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async.} =
  ## Middleware that ensures the user is authenticated.
  ## Returns 401 Unauthorized if not logged in.
  if not ctx.check():
    ctx.status(401).json(%*{"error": "Unauthorized"})
  else:
    await next(ctx)
