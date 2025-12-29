import unittest, asyncdispatch, tables, httpcore
import jazzy/core/[types, context, router]

suite "Router Logic Tests":

  setup:
    # Reset routes if possible or just use unique paths
    # Since Route is global, we have to be careful.
    # We will rely on unique paths for tests.
    discard

  test "Static Route Match":
    proc handleStatic(ctx: Context) = ctx.text("Static")
    Route.get("/test/static", handleStatic)

    let req = JazzyRequest(httpMethod: HttpGet, path: "/test/static")
    let ctx = newContext(req)

    waitFor dispatch(ctx)
    check ctx.response.body == "Static"

  test "Dynamic Route Match":
    proc handleDynamic(ctx: Context) =
      ctx.text("ID: " & ctx.request.params["id"])
    Route.get("/test/user/:id", handleDynamic)

    let req = JazzyRequest(httpMethod: HttpGet, path: "/test/user/99")
    let ctx = newContext(req)

    waitFor dispatch(ctx)
    check ctx.response.body == "ID: 99"

  test "404 Not Found":
    let req = JazzyRequest(httpMethod: HttpGet, path: "/not/found")
    let ctx = newContext(req)

    waitFor dispatch(ctx)
    check ctx.response.code == 404
