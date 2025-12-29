import jazzy
import ../services/todo_service
import ../models/todo

# GET /todos
proc list*(ctx: Context) {.async.} =
  let todos = todo_service.getAllTodos()
  ctx.json(todos)

# GET /todos/:id
proc show*(ctx: Context) {.async.} =
  let id = ctx.request.params["id"].parseInt
  let todo = todo_service.getTodo(id)
  if todo.isSome:
    ctx.json(%*(todo.get))
  else:
    ctx.status(404).json(%*{"error": "Todo not found"})

# POST /todos
proc create*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "title": "required|min:3"
  })

  let newTodo = todo_service.createTodo(data["title"].getStr)
  ctx.status(201).json(%*{"status": "created", "data": newTodo})

# PATCH /todos/:id
proc update*(ctx: Context) {.async.} =
  let id = ctx.request.params["id"].parseInt
  let jsonBody = ctx.validate(%*{
    "completed": "required|bool"
  })

  let data = todo_service.updateTodo(id, jsonBody["completed"].getBool)
  ctx.status(200).json(%*{"status": "updated", "data": data})

# DELETE /todos/:id
proc delete*(ctx: Context) {.async.} =
  let id = ctx.request.params["id"].parseInt
  todo_service.deleteTodo(id)
  ctx.status(204).json(%*{"status": "deleted"})
