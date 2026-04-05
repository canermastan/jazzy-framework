import std/[asyncdispatch, httpcore]
import ../http/[types, context]

proc cors*(allowedOrigin: string = "*",
          allowedMethods: string = "GET, POST, PUT, DELETE, OPTIONS, PATCH",
          allowedHeaders: string = "Content-Type, Authorization, X-Requested-With"): MiddlewareProc =
  return proc(ctx: Context, next: HandlerProc) {.async.} =
    ctx.header("Access-Control-Allow-Origin", allowedOrigin)
    ctx.header("Access-Control-Allow-Methods", allowedMethods)
    ctx.header("Access-Control-Allow-Headers", allowedHeaders)

    if ctx.request.httpMethod == HttpOptions:
      ctx.status(204).text("")
      return

    await next(ctx)
