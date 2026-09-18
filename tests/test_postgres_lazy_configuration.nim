import std/[asyncdispatch, json, os, unittest]
import jazzy/db/[builder, postgres, schema]

const postgresTestDsn = "JAZZY_POSTGRES_TEST_DSN"

when isMainModule:
  # `unittest.skip()` still executes its body. This suite performs database I/O,
  # so it must exit before configuring PostgreSQL when the opt-in DSN is absent.
  if getEnv(postgresTestDsn).len == 0:
    echo "[SKIPPED] PostgreSQL lazy configuration test: set " & postgresTestDsn
    quit(0)

suite "lazy PostgreSQL environment configuration":
  test "loads .env settings before schema SQL is generated":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()

    putEnv("DB_CONNECTION", "postgres")
    putEnv("DATABASE_URL", dsn)
    putEnv("DB_POOL_MIN", "1")
    putEnv("DB_POOL_MAX", "1")

    # No configureDatabase call: execute() must load the environment before it
    # chooses PostgreSQL's BIGSERIAL syntax instead of SQLite AUTOINCREMENT.
    waitFor createTable("jazzy_lazy_config_test").increments("id").execute()
    let row = waitFor DB.raw("SELECT 1 AS database_ok")
    check row[0]["database_ok"].getInt() == 1
    discard waitFor DB.rawExec("DROP TABLE jazzy_lazy_config_test")
    waitFor closePostgresForWorker()
