import std/[asyncdispatch, strutils, httpcore, tables, uri, strtabs]
import mummy
import ../core/[types, server, context]
import ../utils/multipart

type
  MummyDriver* = ref object of ServerDriver
    server: Server

method serve*(driver: MummyDriver, port: int, handler: HandlerProc) {.async.} =

  proc mummyHandler(req: Request) =
    let jReq = new(JazzyRequest)
    jReq.body = req.body
    jReq.url = req.uri

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
      echo "Error handling request: ", e.msg
      req.respond(500, @[], "Internal Server Error: " & e.msg)

  driver.server = newServer(mummyHandler)
  echo "🎷 Jazzy is dancing on http://localhost:" & $port
  driver.server.serve(Port(port))
