import jazzy
import std/[json, options]

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
