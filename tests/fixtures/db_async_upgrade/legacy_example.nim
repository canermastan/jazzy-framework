proc list(ctx: Context) {.async.} =
  let users = DB.table("users").get()
  ctx.json(users)

proc legacyReport(): JsonNode =
  DB.table("reports").count()
