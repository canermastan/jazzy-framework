import ../../src/jazzy

proc initSchema*() =
  createTable("todos")
    .increments("id")
    .string("title")
    .boolean("completed", default = false)
    .execute()

  createTable("users")
    .increments("id")
    .string("username")
    .string("password")
    .execute()
