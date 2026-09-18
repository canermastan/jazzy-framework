import std/[asyncdispatch, json, unittest]
import jazzy/db/[database, builder, schema]

suite "await-first SQLite query builder":
  setup:
    connectDB(":memory:")
    waitFor createTable("users")
      .increments("id")
      .string("name")
      .integer("age")
      .boolean("active", default = true)
      .timestamps()
      .execute()

  teardown:
    closeDB()

  test "uses the same awaited CRUD API as PostgreSQL":
    let id = waitFor DB.table("users").insert(%*{
      "name": "Alice", "age": 25, "active": true
    })
    check id == 1

    let user = waitFor DB.table("users").where("id", id).first()
    check user["name"].getStr() == "Alice"
    check user["age"].getInt() == 25
    check user["active"].getInt() == 1
    check user.hasKey("created_at")

    check (waitFor DB.table("users").where("id", id).update(%*{"age": 26})) == 1
    check (waitFor DB.table("users").where("id", id).count()) == 1
    check (waitFor DB.table("users").where("id", id).first())["age"].getInt() == 26

    check (waitFor DB.table("users").where("id", id).delete()) == 1
    check (waitFor DB.table("users").count()) == 0

  test "supports raw queries and soft deletes":
    waitFor createTable("tasks").increments("id").string("title").softDeletes().execute()
    discard waitFor DB.table("tasks").insert(%*{"title": "First"})
    discard waitFor DB.table("tasks").insert(%*{"title": "Second"})

    let rows = waitFor DB.raw("SELECT title FROM tasks WHERE title = ?", "First")
    check rows.len == 1
    check rows[0]["title"].getStr() == "First"
    let legacyParam = waitFor DB.raw("SELECT ? AS value", dbValue(7))
    check legacyParam[0]["value"].getInt() == 7

    check (waitFor DB.table("tasks").where("title", "First").delete()) == 1
    check (waitFor DB.table("tasks").count()) == 1
    check (waitFor DB.table("tasks").withTrashed().count()) == 2
    check (waitFor DB.table("tasks").onlyTrashed().get())[0]["title"].getStr() == "First"

    check (waitFor DB.table("tasks").where("title", "First").restore()) == 1
    let affected = waitFor DB.rawExec("UPDATE tasks SET title = ? WHERE title = ?", "Done", "First")
    check affected == 1

  test "quotes identifiers and supports condition helpers and returning":
    waitFor createTable("order")
      .increments("id")
      .string("group", nullable = true)
      .string("state")
      .execute()

    let first = waitFor DB.table("order").returning("id", "group").insert(%*{
      "group": "primary", "state": "open"
    })
    let firstId = first["id"].getInt()
    let second = waitFor DB.table("order").returning("id").insert(%*{
      "group": newJNull(), "state": "archived"
    })
    let secondId = second["id"].getInt()

    check (waitFor DB.table("order").whereIn("id", [firstId, secondId])
      .whereNotNull("group").count()) == 1
    check (waitFor DB.table("order").whereNotIn("id", [firstId]).count()) == 1
    check (waitFor DB.table("order").whereNull("group").count()) == 1
    check (waitFor DB.table("order").where("id", firstId)
      .orWhereNull("group").count()) == 2
    check (waitFor DB.table("order").where("id", firstId)
      .orWhereIn("id", [secondId]).count()) == 2

    let updated = waitFor DB.table("order").where("id", secondId)
      .returning("id", "state").update(%*{"state": "open"})
    check updated["id"].getInt() == secondId
    check updated["state"].getStr() == "open"

  test "rewrites only portable raw placeholders":
    check postgresPlaceholders("SELECT ? AS value, '??' AS literal, ?? AS question " &
      "/* ? */ -- ?\nFROM \"?\"") ==
      "SELECT $1 AS value, '??' AS literal, ? AS question /* ? */ -- ?\nFROM \"?\""
    check postgresPlaceholders("SELECT $$?$$, $func$?$func$, ?") ==
      "SELECT $$?$$, $func$?$func$, $1"

  test "creates portable indexes and foreign keys and alters tables":
    waitFor createTable("authors")
      .increments("id")
      .string("email")
      .string("tagline", default = "Ada's")
      .unique("email")
      .execute()
    waitFor createTable("articles")
      .increments("id")
      .foreignId("author_id")
      .constrained("authors")
      .onDelete("CASCADE")
      .string("title")
      .index("title")
      .execute()

    let authorId = waitFor DB.table("authors").insert(%*{"email": "ada@example.com"})
    discard waitFor DB.table("articles").insert(%*{
      "author_id": authorId, "title": "Notes"
    })
    check (waitFor DB.table("articles").count()) == 1
    check (waitFor DB.table("authors").where("id", authorId).forceDelete()) == 1
    check (waitFor DB.table("articles").count()) == 0

    waitFor alterTable("authors")
      .addString("display_name", nullable = true)
      .renameColumn("display_name", "name")
      .execute()
    discard waitFor DB.table("authors").insert(%*{
      "email": "grace@example.com", "name": "Grace"
    })
    check (waitFor DB.table("authors").where("name", "Grace").count()) == 1

    waitFor alterTable("authors").dropColumn("name").execute()
    let author = waitFor DB.table("authors").where("email", "grace@example.com").first()
    check not author.hasKey("name")
    check author["tagline"].getStr() == "Ada's"

    waitFor renameTable("authors", "writers")
    check (waitFor DB.table("writers").count()) == 1
    waitFor dropTable("writers")
