import std/[json, httpcore, tables, strutils, options]
import types
import ../utils/json_helpers
import validation
import ../auth/jwt_manager

import config

# const AuthSecret = "CHANGE_ME_IN_PROD_SECRET_KEY"

export types

proc newContext*(req: JazzyRequest): Context =
  new(result)
  result.request = req
  result.response = newJazzyResponse()
  # Default headers
  result.response.headers["Content-Type"] = "text/html"

  result.auth = new(AuthManager)
  result.auth.isLoggedIn = false

  let authSecret = getConfig("JWT_SECRET", "CHANGE_ME_IN_PROD_SECRET_KEY")

  # Check for Bearer token
  if not req.headers.isNil and req.headers.hasKey("Authorization"):
    let authHeader = req.headers["Authorization"]
    if authHeader.startsWith("Bearer "):
      let token = authHeader[7..^1]
      let jwtParams = newJwtManager(authSecret)
      let payload = jwtParams.verify(token)
      if payload.isSome:
        result.auth.isLoggedIn = true
        result.auth.user = payload
        result.auth.token = token

  let ctx = result

  # Setup Login Proc
  result.auth.loginProc = proc(user: JsonNode): string =
    let col = newJwtManager(authSecret)
    let token = col.sign(user)
    ctx.auth.isLoggedIn = true
    ctx.auth.user = some(user)
    ctx.auth.token = token
    return token

  # Setup Logout Proc
  result.auth.logoutProc = proc() =
    ctx.auth.isLoggedIn = false
    ctx.auth.user = none(JsonNode)
    ctx.auth.token = ""

proc status*(ctx: Context, code: int): Context {.discardable.} =
  ctx.response.code = code
  return ctx

proc header*(ctx: Context, key, value: string): Context {.discardable.} =
  ctx.response.headers[key] = value
  return ctx

proc json*(ctx: Context, node: JsonNode) =
  ctx.header("Content-Type", "application/json")
  ctx.response.body = $node

proc text*(ctx: Context, content: string) =
  ctx.header("Content-Type", "text/plain")
  ctx.response.body = content

proc html*(ctx: Context, content: string) =
  ctx.header("Content-Type", "text/html")
  ctx.response.body = content

proc input*(ctx: Context, key: string, default = ""): string =
  # Priority:
  # 1. Query Parameters
  # 2. JSON Body (if application/json)

  # 1. Check Query Params
  if ctx.request.queryParams.hasKey(key):
    return ctx.request.queryParams[key]

  # 2. Check JSON Body
  try:
    if ctx.request.headers.hasKey("Content-Type") and
       ctx.request.headers["Content-Type"].contains("application/json"):
      if ctx.request.body.len > 0:
        let jsonBody = parseJson(ctx.request.body)
        if jsonBody.kind == JObject and jsonBody.hasKey(key):
          return jsonBody[key].getStr()
  except Exception:
    # JSON parse error, ignore
    discard

  return default

proc bodyAs*[T](ctx: Context, target: typedesc[T]): T =
  if ctx.request.body.len == 0:
    return

  let jsonNode = parseJson(ctx.request.body)
  return jsonNode.toLenient(T)

# Auth Helpers
proc login*(ctx: Context, user: JsonNode): string =
  ctx.auth.loginProc(user)

proc logout*(ctx: Context) =
  ctx.auth.logoutProc()

proc user*(ctx: Context): Option[JsonNode] =
  ctx.auth.user

proc check*(ctx: Context): bool =
  ctx.auth.isLoggedIn

proc id*(ctx: Context): int =
  if ctx.auth.isLoggedIn and ctx.auth.user.isSome:
    let u = ctx.auth.user.get
    if u.hasKey("id"): return u["id"].getInt
  return 0

proc validate*(ctx: Context, rules: JsonNode): JsonNode =
  if ctx.request.body.len == 0:
    return validation.validate(newJObject(), rules)

  let input = try:
    parseJson(ctx.request.body)
  except:
    newJObject()

  return validation.validate(input, rules)

proc file*(ctx: Context, key: string): UploadedFile =
  if ctx.request.files.hasKey(key):
    return ctx.request.files[key]
  return UploadedFile(filename: "", content: "")
