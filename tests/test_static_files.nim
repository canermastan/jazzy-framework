import unittest, asyncdispatch, os, httpcore, tables
import jazzy/http/[context, types, static_files]

suite "Static Files Serving Tests":

  setup:
    let testDir = "tests/static_test_data"
    createDir(testDir)
    writeFile(testDir / "hello.txt", "Hello Static!")
    writeFile(testDir / "index.html", "<html></html>")

    createDir(testDir / "subdir")
    writeFile(testDir / "subdir" / "secret.txt", "secret")

  teardown:
    removeDir("tests/static_test_data")

  test "Should serve existing file":
    let middleware = serveStatic("tests/static_test_data", "/public")
    let req = JazzyRequest(
      httpMethod: HttpGet,
      path: "/public/hello.txt",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)

    # Mock next proc
    let next: HandlerProc = proc(c: Context) {.async.} = discard

    waitFor middleware(ctx, next)

    check ctx.response.code == 200
    check ctx.response.body == "Hello Static!"
    check ctx.response.headers["Content-Type"] == "text/plain"
    check ctx.response.headers.hasKey("Cache-Control")

  test "Should serve file with correct mime type":
    let middleware = serveStatic("tests/static_test_data", "/public")
    let req = JazzyRequest(
      httpMethod: HttpGet,
      path: "/public/index.html",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)
    let next: HandlerProc = proc(c: Context) {.async.} = discard

    waitFor middleware(ctx, next)
    check ctx.response.headers["Content-Type"] == "text/html"

  test "Should call next() if path does not match prefix":
    let middleware = serveStatic("tests/static_test_data", "/public")
    let req = JazzyRequest(
      httpMethod: HttpGet,
      path: "/api/user",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)

    var nextCalled = false
    let next: HandlerProc = proc(c: Context) {.async.} =
      nextCalled = true

    waitFor middleware(ctx, next)
    check nextCalled == true

  test "Should call next() if file does not exist":
    let middleware = serveStatic("tests/static_test_data", "/public")
    let req = JazzyRequest(
      httpMethod: HttpGet,
      path: "/public/missing.txt",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)

    var nextCalled = false
    let next: HandlerProc = proc(c: Context) {.async.} =
      nextCalled = true

    waitFor middleware(ctx, next)
    check nextCalled == true

  test "Should prevent directory traversal":
    let middleware = serveStatic("tests/static_test_data", "/public")
    let req = JazzyRequest(
      httpMethod: HttpGet,
      path: "/public/../../jazzy.nimble",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)
    let next: HandlerProc = proc(c: Context) {.async.} = discard

    waitFor middleware(ctx, next)
    check ctx.response.code == 403

  test "Should serve index.html when requesting directory":
    let middleware = serveStatic("tests/static_test_data", "/public")
    let req = JazzyRequest(
      httpMethod: HttpGet,
      path: "/public/",
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)
    let next: HandlerProc = proc(c: Context) {.async.} = discard

    waitFor middleware(ctx, next)
    check ctx.response.code == 200
    check ctx.response.headers["Content-Type"] == "text/html"
