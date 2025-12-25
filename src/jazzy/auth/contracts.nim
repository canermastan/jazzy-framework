import std/[json, options]

type
  AuthManager* = ref object
    user*: Option[JsonNode]
    isLoggedIn*: bool
    token*: string
    loginProc*: proc(user: JsonNode): string {.gcsafe, closure.}
    logoutProc*: proc() {.gcsafe, closure.}
