import ../../src/jazzy
import router
import services/todo_service
import schema

proc main() =
  connectDB("todo.db")

  initSchema()
  registerRoutes()

  Jazzy.serve(8085)

when isMainModule:
  main()
