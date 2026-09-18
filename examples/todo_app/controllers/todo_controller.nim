import jazzy
import ../services/todo_service
import ../models/todo

proc todoJson(todo: Todo): JsonNode =
  modelData(todo)

proc todosJson(todos: openArray[Todo]): JsonNode =
  result = newJArray()
  for todo in todos:
    result.add(todoJson(todo))

# GET /todos
proc list*(ctx: Context) {.async.} =
  let todos = await todo_service.getAllTodos()
  ctx.json(todosJson(todos))

# GET /todos/:id
proc show*(ctx: Context) {.async.} =
  let id = ctx.param("id").parseBiggestInt.int64
  let todo = await todo_service.getTodo(id)
  if todo.isSome:
    ctx.json(todoJson(todo.get))
  else:
    ctx.status(404).json(%*{"error": "Todo not found"})

# POST /todos
proc create*(ctx: Context) {.async.} =
  let data = ctx.validate(%*{
    "title": "required|min:3"
  })

  let newTodo = await todo_service.createTodo(data["title"].getStr)
  ctx.status(201).json(%*{"status": "created", "data": todoJson(newTodo)})

# PATCH /todos/:id
proc update*(ctx: Context) {.async.} =
  let id = ctx.param("id").parseBiggestInt.int64
  let jsonBody = ctx.validate(%*{
    "completed": "required|bool"
  })

  let data = await todo_service.updateTodo(id, jsonBody["completed"].getBool)
  if data.isSome:
    ctx.status(200).json(%*{"status": "updated", "data": todoJson(data.get)})
  else:
    ctx.status(404).json(%*{"error": "Todo not found"})

# DELETE /todos/:id
proc delete*(ctx: Context) {.async.} =
  let id = ctx.param("id").parseBiggestInt.int64
  let deleted = await todo_service.deleteTodo(id)
  if deleted == 0:
    ctx.status(404).json(%*{"error": "Todo not found"})
  else:
    ctx.status(204).text("")
