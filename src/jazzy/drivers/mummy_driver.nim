import std/[asyncdispatch, strutils, httpcore, tables, uri]
import mummy
import ../http/[types, context]
import ../core/[server, logger]
import ../utils/multipart

type
  MummyDriver* = ref object of ServerDriver
    server: Server

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

      var headers: seq[(string, string)]
      for key, val in ctx.response.headers:
        headers.add((key, val))

      req.respond(ctx.response.code, headers, ctx.response.body)

    except Exception as e:
      let reqId = if ctx.requestId.len >= 8: ctx.requestId[0..7] else: "unknown"
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

  driver.server = newServer(mummyHandler)
  driver.server.serve(Port(port), address)
