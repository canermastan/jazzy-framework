import std/[asyncdispatch, os, unittest]
import jazzy/db/[database, schema]

suite "database environment configuration":
  test "initializes SQLite lazily from environment without connectDB":
    putEnv("DB_CONNECTION", "sqlite")
    putEnv("DB_DATABASE", ":memory:")
    waitFor createTable("lazy_config_test").increments("id").execute()
    check isDatabaseConfigured()
    check databaseDriver() == dbSqlite
    check isDbConnected()
    closeDB()
