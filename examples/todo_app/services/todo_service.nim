import ../../../src/jazzy
import ../models/todo

proc getAllTodos*(): JsonNode =
  return DB.table("todos").get()

proc getTodo*(id: int): Option[Todo] =
  let res = DB.table("todos").where("id", id).first()
  if res.kind == JNull:
    return none(Todo)
  else:
    return some(res.toLenient(Todo))

proc createTodo*(title: string): Todo =
  let id = DB.table("todos").insert(%*{
    "title": title,
    "completed": 0
  })
  return getTodo(id.int).get

proc updateTodo*(id: int, completed: bool): Todo =
  DB.table("todos").where("id", id).update(%*{
    "completed": if completed: 1 else: 0
  })
  return getTodo(id).get

proc deleteTodo*(id: int) =
  DB.table("todos").where("id", id).delete()
