import std/[asyncdispatch, httpcore, strutils, sysrand, cookies, json]
import ../http/[context, types]
import ../core/config
import security

const CsrfCookieName* = "csrf_token"
const CsrfHeaderName* = "X-CSRF-Token"

proc csrfEnabled*(): bool =
  ## CSRF is opt-in for existing projects; `jazzy new` enables it explicitly.
  configEnabled("CSRF_ENABLED")

proc csrfConfigurationWarnings*(): seq[string] =
  ## Returns a migration warning when production CSRF configuration is absent.
  if isProduction() and getConfig("CSRF_ENABLED").len == 0:
    result.add("[Jazzy Deprecation] CSRF protection is disabled for backwards " &
      "compatibility. Set CSRF_ENABLED=true for browser applications using " &
      "auth cookies.")

proc generateCsrfToken(): string =
  var bytes: array[32, byte]
  discard urandom(bytes)
  for b in bytes:
    result.add(toHex(int(b), 2))
  result = result.toLowerAscii()

proc csrfToken*(ctx: Context): string =
  ## Gets the request token or issues a readable double-submit cookie.
  if ctx.csrfTokenValue.len > 0:
    return ctx.csrfTokenValue

  result = ctx.getCookie(CsrfCookieName)
  if result.len == 0:
    result = generateCsrfToken()
    ctx.setCookie(CsrfCookieName, result, path = "/", secure = isProduction(),
        sameSite = SameSite.Strict)
  ctx.csrfTokenValue = result

proc isSafeMethod(httpMethod: HttpMethod): bool =
  httpMethod == HttpGet or httpMethod == HttpHead or httpMethod == HttpOptions or
      httpMethod == HttpTrace

proc csrf*(headerName: string = CsrfHeaderName,
           cookieName: string = CsrfCookieName): Middleware =
  ## Protects cookie-authenticated unsafe requests with double-submit CSRF.
  ## Stateless Bearer-token API requests without browser cookies are unaffected.
  let handler: MiddlewareProc = proc(ctx: Context, next: HandlerProc): Future[
      void] {.async, gcsafe.} =
    let token = ctx.getCookie(cookieName)
    let usesCookieAuth = ctx.getCookie("auth_token").len > 0

    if isSafeMethod(ctx.request.httpMethod):
      if token.len == 0:
        discard ctx.csrfToken()
      await next(ctx)
      return

    if usesCookieAuth or token.len > 0:
      var supplied = if ctx.request.headers.isNil: "" else:
          ctx.request.headers.getOrDefault(headerName)
      if supplied.len == 0:
        supplied = ctx.input("_csrf")
      if token.len == 0 or supplied.len == 0 or
          not constantTimeCompare(token, supplied):
        ctx.status(403).json(%*{"error": "CSRF token mismatch"})
        return

    await next(ctx)

  Middleware(name: "CSRF", handler: handler)
