import unittest, asyncdispatch, json, times, httpcore
import jazzy/http/[types, context, router]
import jazzy/core/[middlewares, cache]

suite "Rate Limit Middleware Tests":

  setup:
    AppCache.clear()

  test "Allow requests under limit":
    let rl = rateLimit(maxRequests = 2, windowSeconds = 60)
    var callCount = 0
    let next: HandlerProc = proc(ctx: Context) {.async.} =
      callCount.inc()

    let req = JazzyRequest(httpMethod: HttpGet, path: "/", ip: "127.0.0.1")
    let ctx = newContext(req)

    # 1st request
    waitFor rl.handler(ctx, next)
    check callCount == 1
    check ctx.response.code == 200 # Default
    check ctx.response.headers["X-RateLimit-Limit"] == "2"
    check ctx.response.headers["X-RateLimit-Remaining"] == "1"

    # 2nd request
    waitFor rl.handler(ctx, next)
    check callCount == 2
    check ctx.response.code == 200
    check ctx.response.headers["X-RateLimit-Remaining"] == "0"

  test "Block requests over limit":
    let rl = rateLimit(maxRequests = 1, windowSeconds = 60)
    var callCount = 0
    let next: HandlerProc = proc(ctx: Context) {.async.} =
      callCount.inc()

    let req = JazzyRequest(httpMethod: HttpGet, path: "/", ip: "127.0.0.1")
    
    # 1st request - OK
    let ctx1 = newContext(req)
    waitFor rl.handler(ctx1, next)
    check callCount == 1
    check ctx1.response.code == 200

    # 2nd request - Blocked
    let ctx2 = newContext(req)
    waitFor rl.handler(ctx2, next)
    check callCount == 1 # Should not increment
    check ctx2.response.code == 429
    check ctx2.response.headers.hasKey("Retry-After")
    check ctx2.response.headers.hasKey("X-RateLimit-Reset")
    
    let body = parseJson(ctx2.response.body)
    check body["error"].getStr == "Too Many Requests"

  test "Different IPs have separate limits":
    let rl = rateLimit(maxRequests = 1, windowSeconds = 60)
    var callCount = 0
    let next: HandlerProc = proc(ctx: Context) {.async.} =
      callCount.inc()

    # IP 1
    let req1 = JazzyRequest(httpMethod: HttpGet, path: "/", ip: "1.1.1.1")
    let ctx1 = newContext(req1)
    waitFor rl.handler(ctx1, next)
    check callCount == 1

    # IP 2
    let req2 = JazzyRequest(httpMethod: HttpGet, path: "/", ip: "2.2.2.2")
    let ctx2 = newContext(req2)
    waitFor rl.handler(ctx2, next)
    check callCount == 2
    check ctx2.response.code == 200
