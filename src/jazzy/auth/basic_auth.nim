import std/[base64, httpcore, strutils]
import ../core/types
import security

proc validateBasicAuth*(ctx: Context; username, password: string): bool =
  let reqHeaders = ctx.request.headers
  if reqHeaders.isNil or not reqHeaders.hasKey("Authorization"):
    return false

  let authHeader = reqHeaders["Authorization"]
  if not authHeader.startsWith("Basic "):
    return false

  try:
    let encoded = authHeader[6..^1]
    let decoded = decode(encoded)
    let parts = decoded.split(":", 1)
    if parts.len < 2:
      return false

    let reqUser = parts[0]
    let reqPass = parts[1]

    return constantTimeCompare(reqUser, username) and constantTimeCompare(
        reqPass, password)
  except:
    return false
