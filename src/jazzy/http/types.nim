import std/[httpcore, tables, asyncdispatch, json, options]
import ../core/cache

type
  AuthManager* = ref object
    user*: Option[JsonNode]
    isLoggedIn*: bool
    token*: string

  JazzyRequest* = ref object
    body*: string
    headers*: HttpHeaders
    httpMethod*: HttpMethod
    url*: string
    path*: string
    ip*: string
    queryParams*: Table[string, string]
    params*: Table[string, string]
    files*: Table[string, UploadedFile]

  UploadedFile* = object
    filename*: string
    contentType*: string
    content*: string

  ValidationError* = ref object of CatchableError
    errors*: JsonNode

  JazzyResponse* = ref object
    code*: int
    body*: string
    headers*: HttpHeaders

  WsEvent* = enum
    OpenEvent, MessageEvent, ErrorEvent, CloseEvent

  WsMessageKind* = enum
    TextMessage, BinaryMessage, Ping, Pong

  WsMessage* = object
    kind*: WsMessageKind
    data*: string

  JazzyWebSocket* = ref object
    sendProc*: proc(data: string) {.gcsafe.}
    closeProc*: proc() {.gcsafe.}

  WsHandlerProc* = proc(ws: JazzyWebSocket, event: WsEvent, msg: WsMessage) {.gcsafe.}

  Context* = ref object
    request*: JazzyRequest
    response*: JazzyResponse
    auth*: AuthManager
    authSecret*: string
    cache*: JazzyCache
    requestId*: string
    csrfTokenValue*: string
    wsHandler*: WsHandlerProc

  HandlerProc* = proc(ctx: Context): Future[void] {.gcsafe, closure.}

  MiddlewareProc* = proc(ctx: Context, next: HandlerProc): Future[void] {.gcsafe, closure.}

  Middleware* = object
    name*: string
    handler*: MiddlewareProc

proc newJazzyResponse*(): JazzyResponse =
  new(result)
  result.code = 200
  result.headers = newHttpHeaders()

proc send*(ws: JazzyWebSocket, data: string) =
  if ws.sendProc != nil: ws.sendProc(data)

proc close*(ws: JazzyWebSocket) =
  if ws.closeProc != nil: ws.closeProc()
