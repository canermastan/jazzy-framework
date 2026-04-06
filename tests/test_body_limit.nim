import unittest, asyncdispatch, json, httpcore, strutils
import jazzy/http/[context, types]
import jazzy/core/middlewares

suite "Body Limit Middleware Tests":

  test "Should allow request under limit":
    let limitMw = bodyLimit(1) # 1MB Limit
    let req = JazzyRequest(
      httpMethod: HttpPost,
      body: "Small body",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)

    var nextCalled = false
    let next: HandlerProc = proc(c: Context): Future[void] {.async, gcsafe.} =
      nextCalled = true

    waitFor limitMw.handler(ctx, next)
    check nextCalled == true
    check ctx.response.code == 200

  test "Should reject request over limit":
    let limitMw = bodyLimit(1) # 1MB Limit

    # Create a body slightly over 1MB
    var largeBody = repeat('a', 1024 * 1024 + 100)

    let req = JazzyRequest(
      httpMethod: HttpPost,
      body: largeBody,
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)

    var nextCalled = false
    let next: HandlerProc = proc(c: Context): Future[void] {.async, gcsafe.} =
      nextCalled = true

    waitFor limitMw.handler(ctx, next)

    check nextCalled == false
    check ctx.response.code == 413
    let resJson = parseJson(ctx.response.body)
    check resJson["error"].getStr() == "Payload Too Large"
    check resJson["limit_mb"].getInt() == 1

  test "Should respect .env config when -1 is passed":
    let limitMw = bodyLimit(-1)
    let req = JazzyRequest(
      httpMethod: HttpPost,
      body: "Small body",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)

    var nextCalled = false
    let next: HandlerProc = proc(c: Context): Future[void] {.async, gcsafe.} =
      nextCalled = true

    waitFor limitMw.handler(ctx, next)
    check nextCalled == true

