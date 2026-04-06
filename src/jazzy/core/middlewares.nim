import std/[asyncdispatch, httpcore, strutils, json, times, math]
import ../http/[types, context, router]
import ../core/[config, cache]

proc rateLimit*(maxRequests: int = 60, windowSeconds: int = 60): Middleware =
  ## IP-based rate limiting middleware.
  ## Default is 60 requests per 60 seconds (1 minute).
  
  let handler: MiddlewareProc = proc(ctx: Context, next: HandlerProc) {.async, gcsafe.} =
    let ip = ctx.ip()
    
    # Generate a fixed-window key based on time
    # This automatically resets every window period
    let now = epochTime()
    let windowId = floor(now / windowSeconds.float).int
    let cacheKey = "ratelimit:" & ip & ":" & $windowId
    
    # Increment and check limit
    # We use cache.increment for thread-safety (race conditions)
    let current = ctx.cache.increment(cacheKey, ttl = windowSeconds)
    
    # Standard Rate-Limit Headers
    let resetAt = (windowId + 1) * windowSeconds
    ctx.header("X-RateLimit-Limit", $maxRequests)
    ctx.header("X-RateLimit-Remaining", $(max(0, maxRequests - current)))
    ctx.header("X-RateLimit-Reset", $resetAt)
    
    if current > maxRequests:
      let retryAfter = resetAt - now.int
      ctx.header("Retry-After", $retryAfter)
      ctx.status(429).json( %* {
        "error": "Too Many Requests",
        "retry_after": retryAfter,
        "reset_at": resetAt
      })
      return
    
    await next(ctx)
  
  return Middleware(name: "RateLimit(" & $maxRequests & "/" & $windowSeconds & "s)", handler: handler)

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
