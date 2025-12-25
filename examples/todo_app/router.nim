import ../../src/jazzy
import controllers/todo_controller
import controllers/auth_controller

proc registerRoutes*() =
  # Auth Routes
  Route.post("/auth/login", auth_controller.login)
  Route.post("/auth/register", auth_controller.register)
  Route.get("/auth/me", auth_controller.me)

  Route.groupPath("/todos", guard):
    Route.get("/", todo_controller.list)
    Route.get("/:id", todo_controller.show)
    Route.post("/", todo_controller.create)
    Route.patch("/:id", todo_controller.update)
    Route.delete("/:id", todo_controller.delete)
