import std/[asyncdispatch, strutils, times]
import ../http/[types, context, router, static_files]
import server, config, logger
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

  # Wrap with request logger (outermost — catches panics, measures total time)
  let appHandler = mainHandler
  mainHandler = proc(ctx: Context): Future[void] {.async, gcsafe.} =
    let start = epochTime()
    try:
      await appHandler(ctx)
    except Exception as e:
      if ctx.response.code < 500:
        ctx.status(500)
      {.cast(gcsafe).}:
        let reqId = ctx.requestId[0..7]
        Log.error("Unhandled " & $e.name & ": " & e.msg & " [" & reqId & "]")
        when not defined(release):
          let trace = e.getStackTrace()
          if trace.len > 0:
            for line in trace.strip().splitLines():
              Log.debug("    " & line.strip())

    # Log request — early-out if logging disabled
    {.cast(gcsafe).}:
      if getMinLevel() != LogLevel.None:
        let duration = (epochTime() - start) * 1000
        let code = ctx.response.code
        let level = if code >= 500: LogLevel.Error
                    elif code >= 400: LogLevel.Warn
                    else: LogLevel.Info
        let durationStr = formatFloat(duration, ffDecimal, 1) & "ms"
        Log.log(level, "← " & $ctx.request.httpMethod & " " &
                ctx.request.path & " " & $code & " " & durationStr &
                " [" & ctx.requestId[0..7] & "]")

  # Startup log
  let baseUrl = "http://" & address & ":" & $port
  Log.info("🎷 Jazzy running in " & env & " mode on " & baseUrl)
  if isDevelopment():
    Log.info("🔧 Dev UI available at " & baseUrl & "/dev-ui")

  waitFor app.driver.serve(port, address, mainHandler)
