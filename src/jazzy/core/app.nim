import std/[asyncdispatch, strutils]
import ../http/[types, context, router, static_files]
import server, config
import ../drivers/mummy_driver
import ../devui/devui

type
  JazzyStatic* = object
    driver: ServerDriver
    middlewares: seq[Middleware]


var Jazzy* = JazzyStatic(
  driver: new(MummyDriver),
  middlewares: @[]
)

proc use*(app: var JazzyStatic, mw: Middleware) =
  app.middlewares.add(mw)

proc static*(app: var JazzyStatic, path: string,
    urlPrefix: string = "/public") =
  app.use(serveStatic(path, urlPrefix))

proc serve*(app: JazzyStatic, port: int, address: string = "0.0.0.0") =
  let env = getAppEnv()

  # Auto-register Dev UI in development mode
  if isDevelopment():
    registerDevUi()

  var mainHandler: HandlerProc = proc(ctx: Context): Future[void] {.async, gcsafe.} =
    await router.dispatch(ctx)

  for i in countdown(app.middlewares.len - 1, 0):
    let mw = app.middlewares[i]
    let next = mainHandler
    mainHandler = proc(ctx: Context): Future[void] {.async, gcsafe.} =
      await mw.handler(ctx, next)

  # Startup log
  let baseUrl = "http://" & address & ":" & $port
  echo "🎷 Jazzy running in " & env & " mode on " & baseUrl
  if isDevelopment():
    echo "🔧 Dev UI available at " & baseUrl & "/dev-ui"

  waitFor app.driver.serve(port, address, mainHandler)
