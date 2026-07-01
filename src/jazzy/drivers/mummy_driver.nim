import std/[asyncdispatch, strutils, httpcore, tables, uri, locks]
import mummy
import ../http/[types, context]
import ../core/[server, logger, config]
import ../utils/multipart

type
  MummyDriver* = ref object of ServerDriver
    server: Server

var
  wsLock: Lock
  wsHandlers: Table[mummy.WebSocket, WsHandlerProc]

initLock(wsLock)

proc mummyWsHandler(ws: mummy.WebSocket, event: mummy.WebSocketEvent, message: mummy.Message) {.gcsafe.} =
  var handler: WsHandlerProc
  {.cast(gcsafe).}:
    wsLock.acquire()
    if wsHandlers.hasKey(ws):
      handler = wsHandlers[ws]
      if event == mummy.CloseEvent:
        wsHandlers.del(ws)
    wsLock.release()

  if handler != nil:
    let jEvent = case event:
      of mummy.OpenEvent: WsEvent.OpenEvent
      of mummy.MessageEvent: WsEvent.MessageEvent
      of mummy.ErrorEvent: WsEvent.ErrorEvent
      of mummy.CloseEvent: WsEvent.CloseEvent
      
    let jKind = case message.kind:
      of mummy.TextMessage: WsMessageKind.TextMessage
      of mummy.BinaryMessage: WsMessageKind.BinaryMessage
      of mummy.Ping: WsMessageKind.Ping
      of mummy.Pong: WsMessageKind.Pong
      
    let jMsg = WsMessage(kind: jKind, data: message.data)
    
    let jWs = new JazzyWebSocket
    
    let w = ws
    jWs.sendProc = proc(data: string) = w.send(data)
    jWs.closeProc = proc() =
      when compiles(w.close()): w.close()
      
    handler(jWs, jEvent, jMsg)


method serve*(driver: MummyDriver, port: int, address: string,
    handler: HandlerProc) {.async.} =

  proc mummyHandler(req: Request) {.gcsafe.} =
    let jReq = new(JazzyRequest)
    jReq.body = req.body
    jReq.url = req.uri
    jReq.ip = req.remoteAddress

    try:
      jReq.httpMethod = parseEnum[HttpMethod](req.httpMethod)
    except ValueError:
      jReq.httpMethod = HttpGet

    jReq.headers = newHttpHeaders()
    for header in req.headers:
      jReq.headers.add(header[0], header[1])

    # Parse Query Params
    let parsedUri = parseUri(req.uri)
    jReq.path = parsedUri.path

    # Only init and parse query if present
    if parsedUri.query.len > 0:
      jReq.queryParams = initTable[string, string]()
      for key, value in decodeQuery(parsedUri.query):
        jReq.queryParams[key] = value
    else:
      jReq.queryParams = initTable[string, string]()

    # Parse Files (Multipart)
    let cType = jReq.headers.getOrDefault("Content-Type")
    if cType.len > 0 and cType.startsWith("multipart/form-data"):
      jReq.files = parseMultipart(req.body, cType)
    else:
      jReq.files = initTable[string, UploadedFile]()

    var ctx = newContext(jReq)

    try:
      waitFor handler(ctx)

      if ctx.wsHandler != nil:
        let ws = req.upgradeToWebSocket()
        {.cast(gcsafe).}:
          wsLock.acquire()
          wsHandlers[ws] = ctx.wsHandler
          wsLock.release()
      else:
        var headers: seq[(string, string)]
        for key, val in ctx.response.headers:
          headers.add((key, val))

        req.respond(ctx.response.code, headers, ctx.response.body)

    except Exception as e:
      let reqId = if ctx.requestId.len >= 8: ctx.requestId[0..7] else: "unknown"
      try:
        when defined(release):
          discard e
          Log.error("Request failed [" & reqId & "]")
          req.respond(500, @[], "Internal Server Error")
        else:
          Log.error($e.name & ": " & e.msg & " [" & reqId & "]")
          let trace = e.getStackTrace()
          if trace.len > 0:
            for line in trace.strip().splitLines():
              Log.debug("    " & line.strip())
          req.respond(500, @[], "Internal Server Error: " & e.msg)
      except Exception as innerE:
        Log.debug("Could not send 500 response (client disconnected): " & innerE.msg)

  let maxUploadSizeStr = getConfig("MAX_UPLOAD_SIZE", "10")
  var maxBodyLen = 10 * 1024 * 1024 # default 10MB
  try:
    maxBodyLen = parseInt(maxUploadSizeStr) * 1024 * 1024
  except ValueError:
    Log.debug("Invalid MAX_UPLOAD_SIZE in .env, using 10MB default")

  driver.server = newServer(mummyHandler, websocketHandler = mummyWsHandler, maxBodyLen = maxBodyLen)
  driver.server.serve(Port(port), address)
