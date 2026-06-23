import std/[json, httpcore, tables, strutils, options, net, sysrand, os, uri,
    cookies, strtabs]
import types, validation
import ../core/[cache, config]
import ../utils/[json_helpers, ip]
import ../auth/jwt_manager
import ../views/engine
import ../views/cache as viewcache

# const AuthSecret = "CHANGE_ME_IN_PROD_SECRET_KEY"

export types

proc generateRequestId(): string =
  ## Generates a UUID-like request identifier using cryptographic randomness
  var bytes: array[16, byte]
  discard urandom(bytes)
  for b in bytes:
    result.add(toHex(int(b), 2))
  result = result.toLowerAscii()
  result = result[0..7] & "-" & result[8..11] & "-" &
           result[12..15] & "-" & result[16..19] & "-" & result[20..31]

proc setCookie*(ctx: Context, name, value: string, maxAge: Option[int] = none(int),
                domain = "", path = "", secure = false, httpOnly = false,
                sameSite = SameSite.Default) =
  var cookieStr = cookies.setCookie(name, value, domain, path, "", false,
      secure, httpOnly, maxAge, sameSite)
  if cookieStr.startsWith("Set-Cookie: "):
    cookieStr = cookieStr[12..^1]
  ctx.response.headers.add("Set-Cookie", cookieStr)

proc getCookie*(ctx: Context, name: string): string =
  if ctx.request.headers.isNil:
    return ""
  let cookieHeader = ctx.request.headers.getOrDefault("Cookie")
  if cookieHeader.len > 0:
    let parsedCookies = parseCookies(cookieHeader)
    if parsedCookies.hasKey(name):
      return parsedCookies[name]
  return ""

proc newContext*(req: JazzyRequest): Context {.gcsafe.} =
  new(result)
  result.request = req
  result.response = newJazzyResponse()
  result.requestId = generateRequestId()
  # Default headers
  result.response.headers["Content-Type"] = "text/html"
  result.response.headers["X-Request-Id"] = result.requestId

  {.cast(gcsafe).}:
    result.cache = AppCache

  result.auth = new(AuthManager)
  result.auth.isLoggedIn = false

  let authSecret = getConfig("JWT_SECRET", "CHANGE_ME_IN_PROD_SECRET_KEY")

  # Check for Bearer token (JWT)
  var authToken = ""
  if not req.headers.isNil and req.headers.hasKey("Authorization"):
    let authHeader = req.headers["Authorization"]
    if authHeader.startsWith("Bearer "):
      authToken = authHeader[7..^1]
  elif not req.headers.isNil and req.headers.hasKey("Cookie"):
    let cookieHeader = req.headers["Cookie"]
    if cookieHeader.len > 0:
      let parsedCookies = parseCookies(cookieHeader)
      if parsedCookies.hasKey("auth_token"):
        authToken = parsedCookies["auth_token"]

  if authToken.len > 0:
    let jwtParams = newJwtManager(authSecret)
    let payload = jwtParams.verify(authToken)
    if payload.isSome:
      result.auth.isLoggedIn = true
      result.auth.user = payload
      result.auth.token = authToken

  let ctx = result

  # Setup Login Proc
  result.auth.loginProc = proc(user: JsonNode): string =
    let col = newJwtManager(authSecret)
    let token = col.sign(user)
    ctx.auth.isLoggedIn = true
    ctx.auth.user = some(user)
    ctx.auth.token = token
    ctx.setCookie("auth_token", token, path = "/", httpOnly = true,
        secure = isProduction(), sameSite = SameSite.Lax)
    return token

  # Setup Logout Proc
  result.auth.logoutProc = proc() =
    ctx.auth.isLoggedIn = false
    ctx.auth.user = none(JsonNode)
    ctx.auth.token = ""
    ctx.setCookie("auth_token", "", path = "/", httpOnly = true,
        secure = isProduction(), sameSite = SameSite.Lax, maxAge = some(0))

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

proc render*(ctx: Context, viewName: string, data: JsonNode = newJObject()) =
  ## Renders a view template using Tier-1 (file) cache.
  ## Supports @extends, @include, @yield, and @section via the views/ directory.
  ## - Development: always reads from disk, no caching.
  ## - Production:  reads from file cache; invalidates automatically on mtime change.
  let viewsDir = getCurrentDir() / "views"
  let viewPath = viewsDir / (viewName & ".html")

  # Inject global $user variable into the template context
  if ctx.auth.isLoggedIn and ctx.auth.user.isSome and not data.hasKey("user"):
    data["user"] = ctx.auth.user.get

  var content: string
  var ok: bool
  {.cast(gcsafe).}:
    (content, ok) = ViewCache.loadTemplate(viewPath)
  if not ok:
    ctx.status(500).text("View not found: " & viewPath)
    return

  try:
    let output = engine.renderString(content, data, viewsDir)
    ctx.html(output)
  except ViewError as e:
    ctx.status(500).text("View template error: " & e.msg)
  except Exception as e:
    ctx.status(500).text("View render error: " & e.msg)

proc renderCached*(ctx: Context, viewName: string,
                   data: JsonNode = newJObject(), ttl: int = 0) =
  ## Renders a view using BOTH Tier-1 (file) and Tier-2 (output) cache.
  ## Supports @extends, @include, @yield, and @section.
  ##
  ## Tier-2 key = hash(viewPath + $data). Use only for templates whose data
  ## rarely changes (landing pages, navigation, footers). Not for user-specific pages.
  ## ttl=0 caches indefinitely until server restart or an explicit clearAll() call.
  let viewsDir = getCurrentDir() / "views"
  let viewPath = viewsDir / (viewName & ".html")

  # Inject global $user variable into the template context
  if ctx.auth.isLoggedIn and ctx.auth.user.isSome and not data.hasKey("user"):
    data["user"] = ctx.auth.user.get

  let dataRepr = $data

  var cached: string
  var hit: bool
  {.cast(gcsafe).}:
    (cached, hit) = ViewCache.getCachedRender(viewPath, dataRepr)
  if hit:
    ctx.html(cached)
    return

  var content: string
  var ok: bool
  {.cast(gcsafe).}:
    (content, ok) = ViewCache.loadTemplate(viewPath)
  if not ok:
    ctx.status(500).text("View not found: " & viewPath)
    return

  try:
    let output = engine.renderString(content, data, viewsDir)
    {.cast(gcsafe).}:
      ViewCache.putCachedRender(viewPath, dataRepr, output, ttl)
    ctx.html(output)
  except ViewError as e:
    ctx.status(500).text("View template error: " & e.msg)
  except Exception as e:
    ctx.status(500).text("View render error: " & e.msg)

proc input*(ctx: Context, key: string, default = ""): string =
  # Priority:
  # 1. Query Parameters
  # 2. JSON Body (if application/json)
  # 3. Form Body (if application/x-www-form-urlencoded)

  # 1. Check Query Params
  if ctx.request.queryParams.hasKey(key):
    return ctx.request.queryParams[key]

  let ct = ctx.request.headers.getOrDefault("Content-Type")

  # 2. Check JSON Body
  if ct.contains("application/json"):
    try:
      if ctx.request.body.len > 0:
        let jsonBody = parseJson(ctx.request.body)
        if jsonBody.kind == JObject and jsonBody.hasKey(key):
          return jsonBody[key].getStr()
    except Exception:
      discard

  # 3. Check Form Body (URL Encoded)
  elif ct.contains("application/x-www-form-urlencoded"):
    if ctx.request.body.len > 0:
      for pair in ctx.request.body.split('&'):
        let kv = pair.split('=', 1)
        if kv.len == 2:
          let decodedKey = decodeUrl(kv[0])
          if decodedKey == key:
            # decodeUrl correctly decodes %20 to space, but often forms use '+' for space.
            return decodeUrl(kv[1].replace("+", " "))

  return default

proc param*(ctx: Context, key: string, default: string = ""): string =
  ## Access route parameters (e.g., /users/:id -> ctx.param("id"))
  if ctx.request.params.hasKey(key):
    return ctx.request.params[key]
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

proc ip*(ctx: Context): string =
  getClientIp(ctx.request.headers, ctx.request.ip)

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
