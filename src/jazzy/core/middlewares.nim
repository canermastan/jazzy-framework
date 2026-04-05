import std/[asyncdispatch, httpcore, strutils, json]
import ../http/[types, context]
import config

proc bodyLimit*(maxSizeMb: int = -1): MiddlewareProc =
  let limitMb = if maxSizeMb == -1:
                  getConfig("BODY_LIMIT_MB", "10").parseInt()
                else:
                  maxSizeMb

  let limitBytes = limitMb * 1024 * 1024

  return proc(ctx: Context, next: HandlerProc) {.async, gcsafe.} =
    if ctx.request.body.len > limitBytes:
      ctx.status(413).json( %* {
        "error": "Payload Too Large",
        "limit_mb": limitMb
      })
      return
    await next(ctx)

proc cors*(allowedOrigin: string = "*",
          allowedMethods: string = "GET, POST, PUT, DELETE, OPTIONS, PATCH",
          allowedHeaders: string = "Content-Type, Authorization, X-Requested-With"): MiddlewareProc =
  return proc(ctx: Context, next: HandlerProc) {.async, gcsafe.} =
    ctx.header("Access-Control-Allow-Origin", allowedOrigin)
    ctx.header("Access-Control-Allow-Methods", allowedMethods)
    ctx.header("Access-Control-Allow-Headers", allowedHeaders)

    if ctx.request.httpMethod == HttpOptions:
      ctx.status(204).text("")
      return

    await next(ctx)
