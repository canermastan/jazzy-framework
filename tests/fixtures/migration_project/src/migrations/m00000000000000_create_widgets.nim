import jazzy

migration "00000000000000_create_widgets":
  up:
    await createTable("widgets")
      .increments("id")
      .string("name")
      .execute()
  down:
    discard await DB.rawExec("DROP TABLE \"widgets\"")
