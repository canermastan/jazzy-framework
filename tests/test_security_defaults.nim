import std/[unittest, asyncdispatch, httpcore, json, strutils, os]
import jazzy/auth/[csrf, jwt_manager, security]
import jazzy/core/config
import jazzy/http/[context, types]

suite "Production Security Defaults":

  test "weak JWT configuration warns without using the legacy secret":
    putEnv("APP_ENV", "production")
    putEnv("JWT_SECRET", "")
    let missingSecretWarnings = jwtConfigurationWarnings()
    check missingSecretWarnings.len == 1
    check missingSecretWarnings[0].contains("Jazzy Deprecation")
    check missingSecretWarnings[0].contains("JWT_SECRET")

    putEnv("JWT_SECRET", DefaultJwtSecret)
    check jwtConfigurationWarnings().len == 1

    let context = newContext(JazzyRequest(headers: newHttpHeaders()))
    check context.authSecret != DefaultJwtSecret
    check context.authSecret.len >= 32

    let legacyToken = newJwtManager(DefaultJwtSecret).sign(%*{"id": 1})
    let legacyRequest = JazzyRequest(headers: newHttpHeaders())
    legacyRequest.headers["Authorization"] = "Bearer " & legacyToken
    check not newContext(legacyRequest).check()

    putEnv("JWT_SECRET", repeat("a", 32))
    check jwtConfigurationWarnings().len == 0

    putEnv("APP_ENV", "development")
    putEnv("JWT_SECRET", "")
    check jwtConfigurationWarnings().len == 1
    check newContext(JazzyRequest(headers: newHttpHeaders())).authSecret !=
        DefaultJwtSecret

  test "Dev UI requires an explicit development opt-in":
    putEnv("APP_ENV", "development")
    putEnv("DEV_UI_ENABLED", "")
    check not devUiEnabled()

    putEnv("DEV_UI_ENABLED", "true")
    check devUiEnabled()

    putEnv("APP_ENV", "production")
    check not devUiEnabled()

    putEnv("APP_ENV", "development")
    putEnv("DEV_UI_ENABLED", "")

  test "strict production validation remains available to applications":
    putEnv("APP_ENV", "production")
    putEnv("JWT_SECRET", "")
    expect JwtConfigurationError:
      requireSecureJwtSecret()

    putEnv("JWT_SECRET", DefaultJwtSecret)
    expect JwtConfigurationError:
      requireSecureJwtSecret()

    putEnv("JWT_SECRET", repeat("a", 32))
    requireSecureJwtSecret()

    putEnv("APP_ENV", "development")
    putEnv("JWT_SECRET", "")

  test "CSRF stays opt-in for existing projects":
    putEnv("APP_ENV", "production")
    putEnv("CSRF_ENABLED", "")
    check not csrfEnabled()
    check csrfConfigurationWarnings().len == 1

    putEnv("CSRF_ENABLED", "true")
    check csrfEnabled()
    check csrfConfigurationWarnings().len == 0

    putEnv("APP_ENV", "development")
    putEnv("CSRF_ENABLED", "")

  test "CSRF issues a strict cookie for safe browser requests":
    let mw = csrf()
    let ctx = newContext(JazzyRequest(httpMethod: HttpGet, headers: newHttpHeaders()))
    var nextCalled = false
    let next: HandlerProc = proc(c: Context): Future[void] {.async, gcsafe.} =
      nextCalled = true

    waitFor mw.handler(ctx, next)
    let cookie = $ctx.response.headers.getOrDefault("Set-Cookie")
    check nextCalled
    check cookie.contains("csrf_token=")
    check cookie.contains("SameSite=Strict")

  test "CSRF reuses its token within one request":
    let ctx = newContext(JazzyRequest(httpMethod: HttpGet, headers: newHttpHeaders()))
    let first = ctx.csrfToken()
    let second = ctx.csrfToken()
    check first == second

  test "CSRF rejects a cookie-authenticated unsafe request without a token":
    let mw = csrf()
    let req = JazzyRequest(httpMethod: HttpPost, headers: newHttpHeaders())
    req.headers["Cookie"] = "auth_token=token; csrf_token=known-token"
    let ctx = newContext(req)
    var nextCalled = false
    let next: HandlerProc = proc(c: Context): Future[void] {.async, gcsafe.} =
      nextCalled = true

    waitFor mw.handler(ctx, next)
    check not nextCalled
    check ctx.response.code == 403
    check ctx.response.body.contains("CSRF token mismatch")

  test "CSRF accepts matching header and leaves Bearer APIs alone":
    let mw = csrf()
    let protectedReq = JazzyRequest(httpMethod: HttpPatch, headers: newHttpHeaders())
    protectedReq.headers["Cookie"] = "auth_token=token; csrf_token=known-token"
    protectedReq.headers[CsrfHeaderName] = "known-token"
    let protectedCtx = newContext(protectedReq)
    var protectedNext = false
    let next: HandlerProc = proc(c: Context): Future[void] {.async, gcsafe.} =
      protectedNext = true
    waitFor mw.handler(protectedCtx, next)
    check protectedNext

    let bearerReq = JazzyRequest(httpMethod: HttpPost, headers: newHttpHeaders())
    bearerReq.headers["Authorization"] = "Bearer token"
    let bearerCtx = newContext(bearerReq)
    var bearerNext = false
    let bearerNextProc: HandlerProc = proc(c: Context): Future[void] {.async, gcsafe.} =
      bearerNext = true
    waitFor mw.handler(bearerCtx, bearerNextProc)
    check bearerNext
