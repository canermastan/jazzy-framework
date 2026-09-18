import std/[asyncdispatch, json, os, unittest]
import jazzy/db/[database, builder, migrations, postgres, schema]

const postgresTestDsn = "JAZZY_POSTGRES_TEST_DSN"
const migrationName = "99999999999990_jazzy_postgres_migration_test"
const failingMigrationName = "99999999999991_jazzy_postgres_migration_rollback_test"

proc createMigrationTable(): Future[void] {.async.} =
  await createTable("jazzy_postgres_migration_test")
    .increments("id")
    .string("name")
    .execute()

proc dropMigrationTable(): Future[void] {.async.} =
  discard await DB.rawExec("DROP TABLE \"jazzy_postgres_migration_test\"")

proc failingUp(): Future[void] {.async.} =
  await createTable("jazzy_postgres_migration_rollback_test")
    .increments("id")
    .execute()
  raise newException(ValueError, "intentional migration rollback test")

proc failingDown(): Future[void] {.async.} =
  discard await DB.rawExec("DROP TABLE IF EXISTS \"jazzy_postgres_migration_rollback_test\"")

suite "PostgreSQL migrations":
  test "pins a connection so every migration is atomic":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    else:
      putEnv("DB_CONNECTION", "postgres")
      putEnv("DATABASE_URL", dsn)
      putEnv("DB_POOL_MIN", "1")
      # More than one connection proves a migration does not accidentally use a
      # different pool connection after BEGIN.
      putEnv("DB_POOL_MAX", "2")
      configureDatabase()

      discard waitFor DB.rawExec("DROP TABLE IF EXISTS \"jazzy_postgres_migration_test\"")
      discard waitFor DB.rawExec("DROP TABLE IF EXISTS \"jazzy_postgres_migration_rollback_test\"")
      waitFor ensureMigrationTable()
      discard waitFor DB.rawExec("DELETE FROM \"jazzy_migrations\" WHERE \"name\" IN (?, ?)",
        migrationName, failingMigrationName)

      let migration = initMigration(migrationName, createMigrationTable, dropMigrationTable)
      check (waitFor migrate(@[migration])) == 1
      check (waitFor DB.raw("SELECT \"name\" FROM \"jazzy_migrations\" WHERE \"name\" = ?",
        migrationName)).len == 1
      check (waitFor rollback(@[migration])) == 1

      let failing = initMigration(failingMigrationName, failingUp, failingDown)
      expect ValueError:
        discard waitFor migrate(@[failing])
      let tables = waitFor DB.raw(
        "SELECT to_regclass('public.jazzy_postgres_migration_rollback_test') AS \"table_name\"")
      check tables[0]["table_name"].kind == JNull
      check (waitFor DB.raw("SELECT \"name\" FROM \"jazzy_migrations\" WHERE \"name\" = ?",
        failingMigrationName)).len == 0

      waitFor closePostgresForWorker()
