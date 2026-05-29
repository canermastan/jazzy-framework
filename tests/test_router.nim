import unittest, asyncdispatch, tables, httpcore
import jazzy/http/[types, context, router]

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

  # Helper mock middlewares for groups
  let mockMw1 = Middleware(
    name: "MockMw1",
    handler: proc(ctx: Context, next: HandlerProc) {.async.} =
      ctx.response.headers.add("X-Mw1", "true")
      await next(ctx)
  )

  let mockMw2 = Middleware(
    name: "MockMw2",
    handler: proc(ctx: Context, next: HandlerProc) {.async.} =
      ctx.response.headers.add("X-Mw2", "true")
      await next(ctx)
  )

  test "Group with single middleware":
    Route.group(mockMw1):
      Route.get("/grp/single", proc(ctx: Context) = ctx.text("GrpSingle"))

    let req = JazzyRequest(httpMethod: HttpGet, path: "/grp/single")
    let ctx = newContext(req)
    waitFor dispatch(ctx)
    check ctx.response.body == "GrpSingle"
    check ctx.response.headers["X-Mw1"] == "true"

  test "Group with multiple middlewares":
    Route.group(@[mockMw1, mockMw2]):
      Route.get("/grp/multi", proc(ctx: Context) = ctx.text("GrpMulti"))

    let req = JazzyRequest(httpMethod: HttpGet, path: "/grp/multi")
    let ctx = newContext(req)
    waitFor dispatch(ctx)
    check ctx.response.body == "GrpMulti"
    check ctx.response.headers["X-Mw1"] == "true"
    check ctx.response.headers["X-Mw2"] == "true"

  test "GroupPath with single middleware":
    Route.groupPath("/gp1", mockMw1):
      Route.get("/hello", proc(ctx: Context) = ctx.text("GP1"))

    let req = JazzyRequest(httpMethod: HttpGet, path: "/gp1/hello")
    let ctx = newContext(req)
    waitFor dispatch(ctx)
    check ctx.response.body == "GP1"
    check ctx.response.headers["X-Mw1"] == "true"

  test "GroupPath with multiple middlewares":
    Route.groupPath("/gp2", @[mockMw1, mockMw2]):
      Route.get("/hello", proc(ctx: Context) = ctx.text("GP2"))

    let req = JazzyRequest(httpMethod: HttpGet, path: "/gp2/hello")
    let ctx = newContext(req)
    waitFor dispatch(ctx)
    check ctx.response.body == "GP2"
    check ctx.response.headers["X-Mw1"] == "true"
    check ctx.response.headers["X-Mw2"] == "true"

  test "GroupPath with zero middleware (new template)":
    Route.groupPath("/gp3"):
      Route.get("/hello", proc(ctx: Context) = ctx.text("GP3"))

    let req = JazzyRequest(httpMethod: HttpGet, path: "/gp3/hello")
    let ctx = newContext(req)
    waitFor dispatch(ctx)
    check ctx.response.body == "GP3"
    check not ctx.response.headers.hasKey("X-Mw1")
    check not ctx.response.headers.hasKey("X-Mw2")

