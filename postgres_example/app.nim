import jazzy
import schema

proc registerRoutes() =
  Route.get("/", proc(ctx: Context) {.async.} =
    ctx.json(%*{
      "message": "Jazzy + PostgreSQL is running",
      "endpoints": ["GET /todos", "POST /todos", "PATCH /todos/:id", "DELETE /todos/:id"]
    })
  )

  Route.get("/health", proc(ctx: Context) {.async.} =
    let result = await DB.raw("SELECT 1 AS database_ok")
    ctx.json(%*{"status": "ok", "database": result[0]["database_ok"]})
  )

  Route.get("/todos", proc(ctx: Context) {.async.} =
    let todos = await DB.table("todos").orderBy("id", "DESC").get()
    ctx.json(todos)
  )

  Route.post("/todos", proc(ctx: Context) {.async.} =
    let data = ctx.validate(%*{"title": "required|min:3"})
    let id = await DB.table("todos").insert(%*{
      "title": data["title"].getStr,
      "completed": false
    })
    let todo = await DB.table("todos").where("id", id).first()
    ctx.status(201).json(todo)
  )

  Route.patch("/todos/:id", proc(ctx: Context) {.async.} =
    let data = ctx.validate(%*{"completed": "required|bool"})
    let id = ctx.param("id").parseInt
    discard await DB.table("todos").where("id", id).update(%*{
      "completed": data["completed"].getBool
    })
    let todo = await DB.table("todos").where("id", id).first()
    ctx.json(todo)
  )

  Route.delete("/todos/:id", proc(ctx: Context) {.async.} =
    let id = ctx.param("id").parseInt
    discard await DB.table("todos").where("id", id).delete()
    discard ctx.status(204)
  )

proc main() =
  # The first DB operation loads .env and connects automatically.
  waitFor initSchema()
  registerRoutes()
  Jazzy.serve(8080)

when isMainModule:
  main()
