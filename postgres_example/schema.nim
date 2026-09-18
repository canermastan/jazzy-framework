import jazzy

proc initSchema*() {.async.} =
  await createTable("todos")
    .increments("id")
    .string("title", nullable = false)
    .boolean("completed", default = false)
    .timestamps()
    .softDeletes()
    .execute()
