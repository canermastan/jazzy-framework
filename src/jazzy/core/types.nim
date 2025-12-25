import std/[httpcore, tables, asyncdispatch, json, options]

type
  AuthManager* = ref object
    user*: Option[JsonNode]
    isLoggedIn*: bool
    token*: string
    loginProc*: proc(user: JsonNode): string {.gcsafe, closure.}
    logoutProc*: proc() {.gcsafe, closure.}

  JazzyRequest* = ref object
    body*: string
    headers*: HttpHeaders
    httpMethod*: HttpMethod
    url*: string
    path*: string
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

  Context* = ref object
    request*: JazzyRequest
    response*: JazzyResponse
    auth*: AuthManager

  HandlerProc* = proc(ctx: Context): Future[void] {.gcsafe, closure.}

  MiddlewareProc* = proc(ctx: Context, next: HandlerProc): Future[
      void] {.gcsafe, closure.}

proc newJazzyResponse*(): JazzyResponse =
  new(result)
  result.code = 200
  result.headers = newHttpHeaders()
