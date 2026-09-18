import jazzy
import ../models/todo

proc getAllTodos*(): Future[seq[Todo]] {.async.} =
  await Todo.query().orderBy("id", "DESC").get()

proc getTodo*(id: int64): Future[Option[Todo]] {.async.} =
  await Todo.find(id)

proc createTodo*(title: string): Future[Todo] {.async.} =
  await Todo.create(Todo(title: title, completed: false))

proc updateTodo*(id: int64, completed: bool): Future[Option[Todo]] {.async.} =
  await Todo.patch(id, %*{"completed": completed})

proc deleteTodo*(id: int64): Future[int] {.async.} =
  await Todo.delete(id)
