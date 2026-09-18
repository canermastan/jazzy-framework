## Versioned, transactional database migrations for Jazzy.
##
## Migration code is compiled with the application, which keeps Nim's normal
## static dependency model intact. The CLI assembles a disposable runner under
## `.jazzy/` and hands its discovered migrations to this runner.

import std/[algorithm, asyncdispatch, json, macros, strutils]
import database, builder, postgres

type
  MigrationProc* = proc(): Future[void]
  SeederProc* = proc(): Future[void]

  Migration* = object
    ## A stable, sortable name such as `20260917143000_create_users`.
    name*: string
    up*: MigrationProc
    down*: MigrationProc

  MigrationStatus* = object
    name*: string
    batch*: int
    appliedAt*: string

  Seeder* = object
    ## A named, explicitly-invoked data seeder.
    name*: string
    run*: SeederProc

proc initMigration*(name: string, up, down: MigrationProc): Migration =
  if name.len == 0:
    raise newException(ValueError, "Migration name cannot be empty")
  if up.isNil or down.isNil:
    raise newException(ValueError, "Every migration needs both up and down blocks")
  Migration(name: name, up: up, down: down)

proc initSeeder*(name: string, run: SeederProc): Seeder =
  if name.len == 0:
    raise newException(ValueError, "Seeder name cannot be empty")
  if run.isNil:
    raise newException(ValueError, "Seeder needs a run block")
  Seeder(name: name, run: run)

macro migration*(name: untyped, body: untyped): untyped =
  ## Declare one migration in a source file.
  ##
  ## ```nim
  ## migration "20260917143000_create_users":
  ##   up:
  ##     await createTable("users").increments("id").execute()
  ##   down:
  ##     discard await DB.rawExec("DROP TABLE users")
  ## ```
  if name.kind notin {nnkStrLit, nnkTripleStrLit}:
    error("migration name must be a string literal", name)

  var upBody, downBody: NimNode
  for statement in body:
    if statement.kind notin {nnkCall, nnkCommand} or statement.len != 2:
      error("a migration block may only contain up: and down: sections", statement)
    let section = statement[0]
    if section.kind notin {nnkIdent, nnkSym}:
      error("expected up: or down: in migration", section)
    if section.eqIdent("up"):
      if not upBody.isNil:
        error("migration contains more than one up: section", statement)
      upBody = statement[1]
    elif section.eqIdent("down"):
      if not downBody.isNil:
        error("migration contains more than one down: section", statement)
      downBody = statement[1]
    else:
      error("a migration block may only contain up: and down: sections", statement)

  if upBody.isNil or downBody.isNil:
    error("a migration needs both up: and down: sections", body)

  let generatedName = ident("jazzyMigration")
  result = quote do:
    let `generatedName`* = initMigration(`name`,
      proc(): Future[void] {.async.} =
        `upBody`,
      proc(): Future[void] {.async.} =
        `downBody`
    )

macro seed*(name: untyped, body: untyped): untyped =
  ## Declare one explicitly-run data seeder.
  ##
  ## ```nim
  ## seed "demo_users":
  ##   discard await User.factory(proc(): User = User(name: "Ada"))
  ## ```
  if name.kind notin {nnkStrLit, nnkTripleStrLit}:
    error("seed name must be a string literal", name)
  let generatedName = ident("jazzySeeder")
  result = quote do:
    let `generatedName`* = initSeeder(`name`,
      proc(): Future[void] {.async.} =
        `body`
    )

proc ensureMigrationTable*(): Future[void] {.async.} =
  ## Create Jazzy's migration history table if it does not exist yet.
  ensureDatabaseConfigured()
  let timestampType = if databaseDriver() == dbPostgres: "TIMESTAMP" else: "DATETIME"
  discard await DB.rawExec("CREATE TABLE IF NOT EXISTS \"jazzy_migrations\" (" &
    "\"name\" TEXT PRIMARY KEY NOT NULL, " &
    "\"batch\" INTEGER NOT NULL, " &
    "\"applied_at\" " & timestampType & " NOT NULL DEFAULT CURRENT_TIMESTAMP)")

proc parseBatch(node: JsonNode): int =
  case node.kind
  of JInt:
    node.getInt()
  of JString:
    try:
      parseInt(node.getStr())
    except ValueError:
      0
  else:
    0

proc migrationStatus*(): Future[seq[MigrationStatus]] {.async.} =
  await ensureMigrationTable()
  let rows = await DB.raw("SELECT \"name\", \"batch\", \"applied_at\" " &
    "FROM \"jazzy_migrations\" ORDER BY \"batch\" ASC, \"name\" ASC")
  for row in rows:
    result.add(MigrationStatus(
      name: row["name"].getStr(),
      batch: parseBatch(row["batch"]),
      appliedAt: if row["applied_at"].kind == JNull: "" else: row["applied_at"].getStr()
    ))

proc sortedMigrations(migrations: openArray[Migration]): seq[Migration] =
  result = @migrations
  result.sort(proc(a, b: Migration): int = cmp(a.name, b.name))
  for index in 0 ..< result.len:
    if result[index].name.len == 0:
      raise newException(ValueError, "Migration name cannot be empty")
    if result[index].up.isNil or result[index].down.isNil:
      raise newException(ValueError, "Migration '" & result[index].name & "' needs up and down blocks")
    if index > 0 and result[index - 1].name == result[index].name:
      raise newException(ValueError, "Duplicate migration name: " & result[index].name)

proc hasMigration(name: string): Future[bool] {.async.} =
  let row = await DB.raw("SELECT \"name\" FROM \"jazzy_migrations\" WHERE \"name\" = ?", name)
  row.len > 0

proc migrationHistoryExists(): Future[bool] {.async.} =
  ## Keep `migrate --pretend` read-only even before the first migration.
  ensureDatabaseConfigured()
  let rows = case databaseDriver()
    of dbSqlite:
      await DB.raw("SELECT name FROM sqlite_master WHERE type = 'table' " &
        "AND name = 'jazzy_migrations'")
    of dbPostgres:
      await DB.raw("SELECT to_regclass('jazzy_migrations') AS name")
    of dbMySql:
      raise newException(ValueError, "MySQL/MariaDB support is not available yet")
  rows.len > 0 and rows[0].hasKey("name") and rows[0]["name"].kind != JNull

proc highestBatch(): Future[int] {.async.} =
  let rows = await DB.raw("SELECT MAX(\"batch\") AS \"jazzy_batch\" FROM \"jazzy_migrations\"")
  if rows.len == 0 or rows[0]["jazzy_batch"].kind == JNull:
    return 0
  parseBatch(rows[0]["jazzy_batch"])

proc inTransaction(body: MigrationProc): Future[void] {.async.} =
  case databaseDriver()
  of dbSqlite:
    await withSqliteTransaction(body)
  of dbPostgres:
    let db = await postgresForCurrentWorker()
    await db.withPostgresTransaction(body)
  of dbMySql:
    raise newException(ValueError, "MySQL/MariaDB support is not available yet")

proc acquireMigrationLock(): Future[void] {.async.} =
  ## SQLite's BEGIN IMMEDIATE already serializes writers. PostgreSQL uses a
  ## transaction-scoped advisory lock so two deploy processes cannot race from
  ## the second history check through the schema change.
  if databaseDriver() == dbPostgres:
    discard await DB.raw("SELECT pg_advisory_xact_lock(hashtext('jazzy_migrations'))")

proc applyMigration(item: Migration, batch: int): Future[bool] {.async.} =
  ## `item` is a copied object here rather than an openArray element. Nim's
  ## async state machine can therefore safely retain it for the transactional
  ## callback below.
  var applied = false
  proc applyOne(): Future[void] {.async.} =
    ## Check a second time after the transaction lock is held. This protects
    ## ordinary concurrent CLI invocations without relying on a process-local
    ## lock.
    await acquireMigrationLock()
    if await hasMigration(item.name):
      return
    await item.up()
    discard await DB.rawExec(
      "INSERT INTO \"jazzy_migrations\" (\"name\", \"batch\") VALUES (?, ?)",
      item.name, batch)
    applied = true

  await inTransaction(applyOne)
  applied

proc rollbackMigration(item: Migration): Future[bool] {.async.} =
  var reverted = false
  proc rollbackOne(): Future[void] {.async.} =
    await acquireMigrationLock()
    await item.down()
    discard await DB.rawExec("DELETE FROM \"jazzy_migrations\" WHERE \"name\" = ?", item.name)
    reverted = true

  await inTransaction(rollbackOne)
  reverted

proc migrateImpl(migrations: seq[Migration]): Future[int] {.async.} =
  ## Apply every not-yet-recorded migration in name order.
  ##
  ## Each migration and its history row share a transaction. On SQLite this
  ## uses `BEGIN IMMEDIATE`; on PostgreSQL one pooled connection is pinned for
  ## the whole migration transaction.
  let ordered = sortedMigrations(migrations)
  await ensureMigrationTable()
  let nextBatch = (await highestBatch()) + 1

  for item in ordered:
    if await hasMigration(item.name):
      continue
    if await applyMigration(item, nextBatch):
      inc result

proc migrate*(migrations: openArray[Migration]): Future[int] =
  ## Copy the caller's array before entering the async state machine. Nim does
  ## not permit an async proc to retain an `openArray` across awaits.
  migrateImpl(@migrations)

proc migrateStepImpl(migrations: seq[Migration]): Future[int] {.async.} =
  ## Apply pending migrations one at a time, giving each its own batch.
  let ordered = sortedMigrations(migrations)
  await ensureMigrationTable()
  var batch = await highestBatch()
  for item in ordered:
    if await hasMigration(item.name):
      continue
    inc batch
    if await applyMigration(item, batch):
      inc result

proc migrateStep*(migrations: openArray[Migration]): Future[int] =
  ## Equivalent to Laravel's `migrate --step`.
  migrateStepImpl(@migrations)

proc pendingMigrationsImpl(migrations: seq[Migration]): Future[seq[Migration]] {.async.} =
  ## Return pending names without calling migration bodies. This is the safe
  ## part of `--pretend` possible for arbitrary compiled Nim migrations.
  for item in sortedMigrations(migrations):
    if not await hasMigration(item.name):
      result.add(item)

proc pendingMigrationsReady(migrations: seq[Migration]): Future[seq[Migration]] {.async.} =
  if not await migrationHistoryExists():
    return sortedMigrations(migrations)
  return await pendingMigrationsImpl(migrations)

proc pendingMigrations*(migrations: openArray[Migration]): Future[seq[Migration]] =
  pendingMigrationsReady(@migrations)

proc rollbackImpl(migrations: seq[Migration]): Future[int] {.async.} =
  ## Roll back the most recently applied batch, in reverse migration order.
  let ordered = sortedMigrations(migrations)
  await ensureMigrationTable()
  let batch = await highestBatch()
  if batch == 0:
    return 0

  var names: seq[string]
  let rows = await DB.raw("SELECT \"name\" FROM \"jazzy_migrations\" " &
    "WHERE \"batch\" = ? ORDER BY \"name\" DESC", batch)
  for row in rows:
    names.add(row["name"].getStr())

  for name in names:
    var found = false
    var item: Migration
    for candidate in ordered:
      if candidate.name == name:
        found = true
        item = candidate
        break
    if not found:
      raise newException(ValueError,
        "Applied migration '" & name & "' is missing from the migration registry")

    if await rollbackMigration(item):
      inc result

proc rollback*(migrations: openArray[Migration]): Future[int] =
  rollbackImpl(@migrations)

proc resetImpl(migrations: seq[Migration]): Future[int] {.async.} =
  ## Roll back every applied batch, newest first.
  while true:
    let reverted = await rollbackImpl(migrations)
    if reverted == 0:
      break
    result += reverted

proc reset*(migrations: openArray[Migration]): Future[int] =
  ## Equivalent to Laravel's `migrate:reset`.
  resetImpl(@migrations)

proc applicationTables(): Future[seq[string]] {.async.} =
  ## Discover tables in Jazzy's default database namespace. Identifiers are
  ## fed back through quoteIdentifier before DDL is emitted.
  ensureDatabaseConfigured()
  let rows = case databaseDriver()
    of dbSqlite:
      await DB.raw("SELECT name FROM sqlite_master WHERE type = 'table' " &
        "AND name NOT LIKE 'sqlite_%'")
    of dbPostgres:
      await DB.raw("SELECT tablename AS name FROM pg_tables " &
        "WHERE schemaname = current_schema()")
    of dbMySql:
      raise newException(ValueError, "MySQL/MariaDB support is not available yet")
  for row in rows:
    if row.hasKey("name") and row["name"].kind != JNull:
      result.add(row["name"].getStr())

proc freshImpl(migrations: seq[Migration]): Future[int] {.async.} =
  ## Drop Jazzy's default-schema tables then run every migration again.
  ## This is intentionally destructive; CLI production protection lives in
  ## the generated runner so it also protects installed Jazzy binaries.
  for tableName in await applicationTables():
    let sql = "DROP TABLE " & builder.quoteIdentifier(tableName) &
      (if databaseDriver() == dbPostgres: " CASCADE" else: "")
    discard await DB.rawExec(sql)
  await migrateImpl(migrations)

proc fresh*(migrations: openArray[Migration]): Future[int] =
  ## Equivalent to Laravel's `migrate:fresh`.
  freshImpl(@migrations)

proc seedImpl(seeders: seq[Seeder]): Future[int] {.async.} =
  var ordered = seeders
  ordered.sort(proc(a, b: Seeder): int = cmp(a.name, b.name))
  for index, item in ordered:
    if item.name.len == 0 or item.run.isNil:
      raise newException(ValueError, "Every seeder needs a name and run block")
    if index > 0 and ordered[index - 1].name == item.name:
      raise newException(ValueError, "Duplicate seeder name: " & item.name)
    await item.run()
    inc result

proc seedAll*(seeders: openArray[Seeder]): Future[int] =
  ## Run seeders in deterministic name order. Seeders are always explicit;
  ## `jazzy migrate` never inserts development data by itself.
  seedImpl(@seeders)
