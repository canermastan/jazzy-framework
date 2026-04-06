import std/[unittest, json]
import jazzy/db/[database, builder, schema]

suite "Database and Query Builder":
  setup:
    connectDB(":memory:")
    
    # Create a test table
    createTable("users")
      .increments("id")
      .string("name")
      .integer("age")
      .execute()

  teardown:
    closeDB()

  test "Basic Insert and Get":
    let id = DB.table("users").insert(%*{"name": "Alice", "age": 25})
    check id == 1
    
    let user = DB.table("users").where("id", 1).first()
    check user["name"].getStr() == "Alice"
    check user["age"].getInt() == 25

  test "Query Builder Where":
    discard DB.table("users").insert(%*{"name": "Alice", "age": 25})
    discard DB.table("users").insert(%*{"name": "Bob", "age": 30})
    
    let users = DB.table("users").where("age", ">", "26").get()
    check users.len == 1
    check users[0]["name"].getStr() == "Bob"

  test "Raw Query":
    discard DB.table("users").insert(%*{"name": "Alice", "age": 25})
    
    # Simple raw select with multiple params (variadic)
    let res = DB.raw("SELECT name, age FROM users WHERE name = ? AND age = ?", "Alice", 25)
    check res.len == 1
    check res[0]["name"].getStr() == "Alice"
    check res[0]["age"].getInt() == 25
    
    # Raw with expressions
    let countRes = DB.raw("SELECT COUNT(*) as total FROM users")
    check countRes[0]["total"].getInt() == 1

  test "Raw Exec":
    # Direct params without @[dbValue(...)]
    DB.rawExec("INSERT INTO users (name, age) VALUES (?, ?)", "Charlie", 35)
    
    let charlie = DB.table("users").where("name", "Charlie").first()
    check charlie["age"].getInt() == 35

  test "Update and Delete":
    discard DB.table("users").insert(%*{"name": "Alice", "age": 25})
    
    DB.table("users").where("name", "Alice").update(%*{"age": 26})
    let user = DB.table("users").where("name", "Alice").first()
    check user["age"].getInt() == 26
    
    DB.table("users").where("name", "Alice").delete()
    check DB.table("users").count() == 0
