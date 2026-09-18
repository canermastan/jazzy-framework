import std/[os, strutils, times, unittest]
import jazzy/cli/[migrations, scaffolding, templates]

suite "CLI Security Scaffold":

  test "environment template includes the generated JWT secret and API-safe CSRF default":
    let secret = repeat("a", 64)
    let env = envTemplate(secret)
    check env.contains("JWT_SECRET=" & secret)
    check env.contains("CSRF_ENABLED=false")
    check env.contains("APP_ENV=development")
    check env.contains("DEV_UI_ENABLED=true")

  test "migration templates use a hidden generated runner and ORM-ready layout":
    let migration = migrationTemplate("20260917143000_create_users")
    check migration.contains("migration \"20260917143000_create_users\":")
    check migration.contains("  up:")
    check migration.contains("  down:")
    check migration.contains("await createTable(\"users\")")
    check migration.contains(".increments(\"id\")")
    check migration.contains("await dropTable(\"users\")")
    let alterMigration = migrationTemplate("20260917143001_add_timezone_to_users")
    check alterMigration.contains("# Reverse the exact up: operation here.")
    check alterMigration.contains("await dropTable(\"TABLE_NAME\")")
    check todoMigrationTemplate().contains("00000000000000_create_todos")
    check todoMigrationTemplate().contains("await dropTable(\"todos\")")
    let runner = migrationRunnerTemplate(@["m00000000000000_create_todos"],
      @["s20260917143000_demo_users"])
    check runner.contains("import migrations/m00000000000000_create_todos")
    check runner.contains("migrate(allMigrations())")
    check runner.contains("import seeders/s20260917143000_demo_users")
    check runner.contains("seedAll(allSeeders())")
    check seederTemplate("20260917143000_demo_users").contains("seed \"20260917143000_demo_users\"")
    let model = modelTemplate("ApiKey", "api_keys")
    check model.contains("model ApiKey:")
    check model.contains("table \"api_keys\"")
    check model.contains("id int64")
    check model.contains("timestamps()")
    let controller = controllerTemplate("TaskController")
    check controller.contains("proc index*")
    check controller.contains("proc destroy*")
    check gitignoreTemplate().contains(".jazzy/")

  test "make:model creates a conventional typed model skeleton":
    let root = getTempDir() / ("jazzy_model_" & $int(epochTime() * 1_000_000))
    createDir(root / "src")
    try:
      check makeModel("Task", root) == 0
      let task = readFile(root / "src" / "models" / "task.nim")
      check task.contains("model Task:")
      check task.contains("table \"tasks\"")
      check makeModel("APIKey", root) == 0
      let apiKey = readFile(root / "src" / "models" / "api_key.nim")
      check apiKey.contains("table \"api_keys\"")
      check makeController("TaskController", root = root) == 0
      let controller = readFile(root / "src" / "controllers" / "task_controller.nim")
      check controller.contains("proc store*")
      check controller.contains("proc destroy*")
    finally:
      if dirExists(root):
        removeDir(root)

  test "migration commands self-generate their hidden runner":
    let root = getTempDir() / ("jazzy_hidden_runner_" &
      $int(epochTime() * 1_000_000))
    let migrationDirectory = root / "src" / "migrations"
    createDir(migrationDirectory)
    writeFile(root / ".env", "DB_CONNECTION=sqlite\nDB_DATABASE=database.sqlite\n")
    writeFile(migrationDirectory / "m20260917143000_create_notes.nim", """import jazzy

migration "20260917143000_create_notes":
  up:
    await createTable("notes").increments("id").string("body").execute()
  down:
    discard await DB.rawExec("DROP TABLE \"notes\"")
""")
    let seederDirectory = root / "src" / "seeders"
    createDir(seederDirectory)
    writeFile(seederDirectory / "s20260917150000_demo_notes.nim", """import jazzy

seed "20260917150000_demo_notes":
  discard await DB.table("notes").insert(%*{"body": "seeded"})
""")
    try:
      check runMigrationCommand("pretend", root) == 0
      check runMigrationCommand("up", root) == 0
      check fileExists(root / ".jazzy" / "migration_runner.nim")
      check not fileExists(root / "src" / "migrate.nim")
      check not fileExists(root / "src" / "migrations" / "registry.nim")
      check runMigrationCommand("status", root) == 0
      check runMigrationCommand("fresh-seed", root) == 0
      writeFile(root / ".env", "APP_ENV=production\nDB_CONNECTION=sqlite\nDB_DATABASE=database.sqlite\n")
      check runMigrationCommand("reset", root) == 1
      check runMigrationCommand("reset", root, force = true) == 0
    finally:
      if dirExists(root):
        removeDir(root)
