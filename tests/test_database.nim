import std/[unittest, json, strutils, times, os]
import jazzy/db/[database, builder, schema]

suite "Database and Query Builder":
  setup:
    connectDB(":memory:")

    # Global tables for basic tests
    createTable("users")
      .increments("id")
      .string("name")
      .integer("age")
      .execute()

  teardown:
    closeDB()

  test "Basic: Insert and Get":
    let id = DB.table("users").insert(%*{"name": "Alice", "age": 25})
    check id == 1

    let user = DB.table("users").where("id", 1).first()
    check user["name"].getStr() == "Alice"
    check user["age"].getInt() == 25

  test "ORM: Select Specific Columns":
    discard DB.table("users").insert(%*{"name": "Alice", "age": 25})

    # Should only return 'name'
    let res = DB.table("users").select("name").first()
    check res.hasKey("name")
    check not res.hasKey("age")
    check res["name"].getStr() == "Alice"

  test "ORM: OrderBy ASC and DESC":
    discard DB.table("users").insert(%*{"name": "Alice", "age": 30})
    discard DB.table("users").insert(%*{"name": "Bob", "age": 20})

    let asc = DB.table("users").orderBy("age", "ASC").get()
    check asc[0]["name"].getStr() == "Bob"

    let desc = DB.table("users").orderBy("age", "DESC").get()
    check desc[0]["name"].getStr() == "Alice"

  test "ORM: Limit and Offset (Pagination)":
    for i in 1..5:
      discard DB.table("users").insert(%*{"name": "User " & $i, "age": i})

    # Skip first 2, take next 2 (User 3 and User 4)
    let res = DB.table("users").orderBy("id", "ASC").limit(2).offset(2).get()
    check res.len == 2
    check res[0]["name"].getStr() == "User 3"
    check res[1]["name"].getStr() == "User 4"

  test "ORM: Update and Delete":
    discard DB.table("users").insert(%*{"name": "Alice", "age": 25})

    DB.table("users").where("name", "Alice").update(%*{"age": 26})
    let user = DB.table("users").where("name", "Alice").first()
    check user["age"].getInt() == 26

    DB.table("users").where("name", "Alice").delete()
    check DB.table("users").count() == 0

  test "Timestamps: Automatic Creation":
    createTable("posts").increments("id").string("title").timestamps().execute()

    let id = DB.table("posts").insert(%*{"title": "New Post"})
    let post = DB.table("posts").where("id", id).first()

    check post.hasKey("created_at")
    check post.hasKey("updated_at")
    check post["created_at"].getStr() == post["updated_at"].getStr()

  test "Timestamps: Manual Override":
    createTable("logs").increments("id").string("msg").timestamps().execute()

    let pastDate = "2020-01-01 12:00:00"
    let id = DB.table("logs").insert(%*{
      "msg": "Old Log",
      "created_at": pastDate,
      "updated_at": pastDate
    })

    let log = DB.table("logs").where("id", id).first()
    check log["created_at"].getStr() == pastDate
    check log["updated_at"].getStr() == pastDate

  test "Timestamps: Automatic Update on Modification":
    createTable("products").increments("id").string("name").timestamps().execute()

    let pastDate = "2010-05-20 09:00:00"
    let id = DB.table("products").insert(%*{
      "name": "Old Product",
      "created_at": pastDate,
      "updated_at": pastDate
    })

    sleep(10)
    DB.table("products").where("id", id).update(%*{"name": "Updated Product"})

    let updated = DB.table("products").where("id", id).first()
    let nowStr = now().utc.format("yyyy-MM-dd")

    check updated["name"].getStr() == "Updated Product"
    check updated["created_at"].getStr() == pastDate
    check updated["updated_at"].getStr() != pastDate
    check updated["updated_at"].getStr().startsWith(nowStr)

  test "Raw: Query and Exec":
    discard DB.table("users").insert(%*{"name": "Alice", "age": 25})

    let res = DB.raw("SELECT name FROM users WHERE age = ?", 25)
    check res.len == 1
    check res[0]["name"].getStr() == "Alice"

    let affected = DB.rawExec("UPDATE users SET age = ? WHERE name = ?", 30, "Alice")
    check affected == 1

  test "ORM: Soft Deletes":
    createTable("tasks")
      .increments("id")
      .string("title")
      .softDeletes()
      .execute()

    # 1. Insert
    discard DB.table("tasks").insert(%*{"title": "Task 1"})
    discard DB.table("tasks").insert(%*{"title": "Task 2"})
    check DB.table("tasks").count() == 2

    # 2. Soft Delete Task 1
    DB.table("tasks").where("title", "Task 1").delete()

    # Task 1 should be hidden
    check DB.table("tasks").count() == 1
    let activeTasks = DB.table("tasks").get()
    check activeTasks[0]["title"].getStr() == "Task 2"

    # 3. With Trashed
    let allTasks = DB.table("tasks").withTrashed().get()
    check allTasks.len == 2

    # 4. Only Trashed
    let onlyTrashed = DB.table("tasks").onlyTrashed().get()
    check onlyTrashed.len == 1
    check onlyTrashed[0]["title"].getStr() == "Task 1"

    # 5. Restore
    DB.table("tasks").where("title", "Task 1").restore()
    check DB.table("tasks").count() == 2

    # 6. Force Delete
    DB.table("tasks").where("title", "Task 1").forceDelete()
    check DB.table("tasks").withTrashed().count() == 1

  test "Schema: String with Length":
    createTable("length_test")
      .string("short_str", length = 50)
      .string("long_str", length = 255)
      .string("default_str")
      .execute()

    let info = DB.raw("PRAGMA table_info(length_test)")
    
    var foundShort = false
    var foundLong = false
    var foundDefault = false
    
    for col in info:
      if col["name"].getStr() == "short_str":
        check col["type"].getStr() == "TEXT(50)"
        foundShort = true
      elif col["name"].getStr() == "long_str":
        check col["type"].getStr() == "TEXT(255)"
        foundLong = true
      elif col["name"].getStr() == "default_str":
        check col["type"].getStr() == "TEXT"
        foundDefault = true
        
    check foundShort
    check foundLong
    check foundDefault

