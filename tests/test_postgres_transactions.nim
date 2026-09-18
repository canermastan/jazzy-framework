import std/[asyncdispatch, json, os, unittest]
import jazzy/db/[database, builder, postgres]

const postgresTestDsn = "JAZZY_POSTGRES_TEST_DSN"

proc exercisePostgresTransactions(): Future[int64] {.async.} =
  DB.transaction:
    discard await DB.table("jazzy_postgres_transaction_test").insert(%*{
      "name": "first"
    })
    discard await DB.table("jazzy_postgres_transaction_test").insert(%*{
      "name": "second"
    })

  try:
    DB.transaction:
      discard await DB.table("jazzy_postgres_transaction_test").insert(%*{
        "name": "must be rolled back"
      })
      raise newException(ValueError, "intentional transaction rollback")
    raise newException(AssertionDefect, "transaction should have failed")
  except ValueError:
    discard

  var createdId: int64
  DB.transaction:
    createdId = await DB.table("jazzy_postgres_transaction_test").insert(%*{
      "name": "returned from transaction"
    })
  return createdId

proc exerciseNestedPostgresTransaction(): Future[void] {.async.} =
  DB.transaction:
    DB.transaction:
      discard

when isMainModule:
  if getEnv(postgresTestDsn).len == 0:
    echo "[SKIPPED] PostgreSQL transaction integration tests: set " & postgresTestDsn
    quit(0)

suite "PostgreSQL public transactions":
  test "commits related queries and rolls back all queries after an error":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    else:
      putEnv("DB_CONNECTION", "postgres")
      putEnv("DATABASE_URL", dsn)
      putEnv("DB_POOL_MIN", "1")
      # Two connections ensure builder operations must use Jazzy's pinned
      # transaction connection rather than happen to reuse one pool entry.
      putEnv("DB_POOL_MAX", "2")
      configureDatabase()

      discard waitFor DB.rawExec("DROP TABLE IF EXISTS jazzy_postgres_transaction_test")
      discard waitFor DB.rawExec("""
        CREATE TABLE jazzy_postgres_transaction_test (
          id BIGSERIAL PRIMARY KEY,
          name TEXT NOT NULL
        )
      """)

      let createdId = waitFor exercisePostgresTransactions()
      # PostgreSQL sequences deliberately do not roll back, so a failed insert
      # can consume an ID. Verify the committed rows, not a numeric sequence.
      check createdId > 0
      check (waitFor DB.table("jazzy_postgres_transaction_test").count()) == 3
      check (waitFor DB.table("jazzy_postgres_transaction_test")
        .where("name", "must be rolled back").count()) == 0

      expect ValueError:
        waitFor exerciseNestedPostgresTransaction()

      discard waitFor DB.rawExec("DROP TABLE jazzy_postgres_transaction_test")
      waitFor closePostgresForWorker()
