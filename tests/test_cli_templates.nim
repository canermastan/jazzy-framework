import std/[unittest, strutils]
import jazzy/cli/templates

suite "CLI Security Scaffold":

  test "environment template includes the generated JWT secret and API-safe CSRF default":
    let secret = repeat("a", 64)
    let env = envTemplate(secret)
    check env.contains("JWT_SECRET=" & secret)
    check env.contains("CSRF_ENABLED=false")
    check env.contains("APP_ENV=development")
    check env.contains("DEV_UI_ENABLED=true")
