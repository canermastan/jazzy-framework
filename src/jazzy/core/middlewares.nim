import std/[asyncdispatch, httpcore, strutils, json]
import ../http/[types, context, router]
import config

proc bodyLimit*(maxSizeMb: int = -1): Middleware =
  let limitMb = if maxSizeMb == -1:
                  getConfig("BODY_LIMIT_MB", "10").parseInt()
                else:
                  maxSizeMb

  let limitBytes = limitMb * 1024 * 1024

  let handler: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async, gcsafe.} =
    if ctx.request.body.len > limitBytes:
      ctx.status(413).json( %* {
        "error": "Payload Too Large",
        "limit_mb": limitMb
      })
      return
    await next(ctx)
  
  return Middleware(name: "BodyLimit(" & $limitMb & "MB)", handler: handler)

proc cors*(allowedOrigin: string = "*",
          allowedMethods: string = "GET, POST, PUT, DELETE, OPTIONS, PATCH",
          allowedHeaders: string = "Content-Type, Authorization, X-Requested-With"): Middleware =
  let handler: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async, gcsafe.} =
    ctx.header("Access-Control-Allow-Origin", allowedOrigin)
    ctx.header("Access-Control-Allow-Methods", allowedMethods)
    ctx.header("Access-Control-Allow-Headers", allowedHeaders)

    if ctx.request.httpMethod == HttpOptions:
      ctx.status(204).text("")
      return

    await next(ctx)
  
  return Middleware(name: "CORS", handler: handler)
