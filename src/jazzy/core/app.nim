import std/asyncdispatch
import types, context, server, router, static_files
import jazzy/drivers/mummy_driver

type
  JazzyStatic* = object
    driver: ServerDriver
    middlewares: seq[MiddlewareProc]


var Jazzy* = JazzyStatic(
  driver: new(MummyDriver),
  middlewares: @[]
)

proc use*(app: var JazzyStatic, mw: MiddlewareProc) =
  app.middlewares.add(mw)



proc static*(app: var JazzyStatic, path: string,
    urlPrefix: string = "/public") =
  app.use(serveStatic(path, urlPrefix))

proc serve*(app: JazzyStatic, port: int) =
  var mainHandler: HandlerProc = proc(ctx: Context): Future[void] {.async, gcsafe.} =
    await router.dispatch(ctx)

  for i in countdown(app.middlewares.len - 1, 0):
    let mw = app.middlewares[i]
    let next = mainHandler
    mainHandler = proc(ctx: Context): Future[void] {.async, gcsafe.} =
      await mw(ctx, next)

  waitFor app.driver.serve(port, mainHandler)
