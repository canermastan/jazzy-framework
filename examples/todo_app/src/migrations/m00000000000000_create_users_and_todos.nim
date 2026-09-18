import jazzy

migration "00000000000000_create_users_and_todos":
  up:
    await createTable("users")
      .increments("id")
      .string("username")
      .string("password")
      .unique("username")
      .timestamps()
      .execute()

    await createTable("todos")
      .increments("id")
      .string("title")
      .boolean("completed", default = false)
      .timestamps()
      .execute()
  down:
    await dropTable("todos")
    await dropTable("users")
