import std/[asyncdispatch, json, os, unittest]
import jazzy/db/[database, builder, postgres, schema]

const postgresTestDsn = "JAZZY_POSTGRES_TEST_DSN"

when isMainModule:
  # Nim's unittest `skip()` only marks a test; it deliberately keeps running
  # the body. Avoid attempting a PostgreSQL connection on machines without the
  # opt-in integration-test DSN.
  if getEnv(postgresTestDsn).len == 0:
    echo "[SKIPPED] PostgreSQL builder integration tests: set " & postgresTestDsn
    quit(0)

suite "PostgreSQL await-first query builder":
  test "runs schema and CRUD against a real PostgreSQL server":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    putEnv("DB_CONNECTION", "postgres")
    putEnv("DATABASE_URL", dsn)
    putEnv("DB_POOL_MIN", "1")
    putEnv("DB_POOL_MAX", "2")
    configureDatabase()

    discard waitFor DB.rawExec("DROP TABLE IF EXISTS jazzy_builder_test")
    waitFor createTable("jazzy_builder_test")
      .increments("id")
      .string("name")
      .boolean("active", default = false)
      .timestamps()
      .softDeletes()
      .execute()

    let id = waitFor DB.table("jazzy_builder_test").insert(%*{
      "name": "Ada", "active": true
    })
    let user = waitFor DB.table("jazzy_builder_test").where("id", id).first()
    check user["name"].getStr() == "Ada"
    check user["active"].getBool()
    check user.hasKey("created_at")

    check (waitFor DB.table("jazzy_builder_test").where("active", true).update(%*{
      "name": "Ada Lovelace"
    })) == 1
    check (waitFor DB.table("jazzy_builder_test").where("active", true).count()) == 1

    check (waitFor DB.table("jazzy_builder_test").where("id", id).delete()) == 1
    check (waitFor DB.table("jazzy_builder_test").count()) == 0
    check (waitFor DB.table("jazzy_builder_test").withTrashed().count()) == 1
    discard waitFor DB.rawExec("DROP TABLE jazzy_builder_test")
    waitFor closePostgresForWorker()

  test "uses quoted identifiers, portable raw parameters and typed conditions":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    putEnv("DB_CONNECTION", "postgres")
    putEnv("DATABASE_URL", dsn)
    putEnv("DB_POOL_MIN", "1")
    putEnv("DB_POOL_MAX", "2")
    configureDatabase()

    discard waitFor DB.rawExec("DROP TABLE IF EXISTS \"order\"")
    waitFor createTable("order")
      .increments("id")
      .string("group", nullable = true)
      .string("state")
      .execute()

    let created = waitFor DB.table("order").returning("id", "state").insert(%*{
      "group": "primary", "state": "open"
    })
    let id = created["id"].getInt()
    discard waitFor DB.table("order").returning("id").insert(%*{
      "group": newJNull(), "state": "archived"
    })

    # Route parameters are strings. The PostgreSQL metadata-aware placeholder
    # makes the BIGSERIAL primary key comparison work without app-level casts.
    let found = waitFor DB.table("order").where("id", $id).first()
    check found["state"].getStr() == "open"
    check (waitFor DB.table("order").whereIn("id", [id]).whereNotNull("group").count()) == 1
    check (waitFor DB.table("order").where("id", id).orWhereNull("group").count()) == 2

    let raw = waitFor DB.raw("SELECT ?::integer AS answer", "42")
    check raw[0]["answer"].getInt() == 42
    let jsonOperator = waitFor DB.raw("SELECT ?::jsonb ?? 'name' AS has_name",
      "{\"name\": \"Ada\"}")
    check jsonOperator[0]["has_name"].getBool()

    let updated = waitFor DB.table("order").where("id", $id)
      .returning("id", "state").update(%*{"state": "done"})
    check updated["state"].getStr() == "done"
    check (waitFor DB.table("order").where("id", id).delete()) == 1

    discard waitFor DB.rawExec("DROP TABLE \"order\"")
    waitFor closePostgresForWorker()

  test "drops a column through the same alterTable API":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    putEnv("DB_CONNECTION", "postgres")
    putEnv("DATABASE_URL", dsn)
    putEnv("DB_POOL_MIN", "1")
    putEnv("DB_POOL_MAX", "1")
    configureDatabase()

    discard waitFor DB.rawExec("DROP TABLE IF EXISTS jazzy_drop_column_test")
    waitFor createTable("jazzy_drop_column_test")
      .increments("id")
      .string("name")
      .string("legacy_note", nullable = true)
      .execute()
    discard waitFor DB.table("jazzy_drop_column_test").insert(%*{
      "name": "Ada", "legacy_note": "remove me"
    })

    waitFor alterTable("jazzy_drop_column_test").dropColumn("legacy_note").execute()
    let row = waitFor DB.table("jazzy_drop_column_test").first()
    check row["name"].getStr() == "Ada"
    check not row.hasKey("legacy_note")

    discard waitFor DB.rawExec("DROP TABLE jazzy_drop_column_test")
    waitFor closePostgresForWorker()

  test "uses returning for UUID primary keys and JSONB values":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    putEnv("DB_CONNECTION", "postgres")
    putEnv("DATABASE_URL", dsn)
    putEnv("DB_POOL_MIN", "1")
    putEnv("DB_POOL_MAX", "2")
    configureDatabase()

    discard waitFor DB.rawExec("DROP TABLE IF EXISTS jazzy_uuid_test")
    discard waitFor DB.rawExec("""
      CREATE TABLE jazzy_uuid_test (
        token UUID PRIMARY KEY,
        payload JSONB NOT NULL,
        enabled BOOLEAN NOT NULL
      )
    """)
    let token = "ef8ed7cf-879d-4ee0-99f4-5c20e92324f4"
    let created = waitFor DB.table("jazzy_uuid_test")
      .returning("token", "payload").insert(%*{
        "token": token,
        "payload": {"role": "admin"},
        "enabled": true
      })
    check created["token"].getStr() == token
    check created["payload"]["role"].getStr() == "admin"

    let found = waitFor DB.table("jazzy_uuid_test").where("token", token)
      .where("enabled", "true").first()
    check found["payload"]["role"].getStr() == "admin"

    expect ValueError:
      discard waitFor DB.table("jazzy_uuid_test").insert(%*{
        "token": "c82fdbd2-3ca4-4657-bc21-21a03d5db2e5",
        "payload": {"role": "reader"},
        "enabled": false
      })
    discard waitFor DB.rawExec("DROP TABLE jazzy_uuid_test")
    waitFor closePostgresForWorker()
