import jazzy
import std/[json, options]

proc authClaims*(user: JsonNode): JsonNode =
  ## Returns the only user fields that may be stored in an authentication token.
  result = %*{
    "id": user["id"],
    "username": user["username"]
  }

proc login*(username, password: string): Option[JsonNode] =
  let user = DB.table("users").where("username", username).first()
  if user.kind != JNull and verifyPassword(password, user["password"].getStr):
    return some(user)
  else:
    return none(JsonNode)

proc register*(username, password: string): int =
  let hashedPassword = hashPassword(password)
  return DB.table("users").insert(%*{
    "username": username,
    "password": hashedPassword
  })
