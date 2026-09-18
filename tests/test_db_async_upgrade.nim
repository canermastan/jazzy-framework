import std/[strutils, unittest]
import jazzy/cli/db_async_upgrade

suite "DB async upgrade analyzer":
  test "adds await to direct calls in async procs":
    let source = """proc list(ctx: Context) {.async.} =
  let users = DB.table("users").where("active", true).get()
  ctx.json(DB.table("users").count())
"""
    let analysis = analyzeDbAsyncSource(source, "controllers/users.nim")
    check analysis.findings.len == 2
    for finding in analysis.findings:
      check finding.safe
    let upgraded = applyDbAsyncUpgrade(source, analysis)
    check "let users = await DB.table(\"users\").where(\"active\", true).get()" in upgraded
    check "ctx.json(await DB.table(\"users\").count())" in upgraded

  test "recognizes multiline schema builders":
    let source = """proc initSchema() {.async.} =
  createTable("users")
    .increments("id")
    .execute()
"""
    let analysis = analyzeDbAsyncSource(source)
    check analysis.findings.len == 1
    check analysis.findings[0].safe
    check "await createTable" in applyDbAsyncUpgrade(source, analysis)

  test "reports synchronous procs without touching them":
    let source = """proc loadUsers(): JsonNode =
  return DB.table("users").get()
"""
    let analysis = analyzeDbAsyncSource(source, "services/users.nim")
    check analysis.findings.len == 1
    check not analysis.findings[0].safe
    check "synchronous proc" in analysis.findings[0].reason
    check applyDbAsyncUpgrade(source, analysis) == source

  test "ignores comments, strings, and existing async boundaries":
    let source = """proc list(ctx: Context) {.async.} =
  # DB.table("users").get()
  let example = "DB.table(\\\"users\\\").get()"
  let users = await DB.table("users").get()
  let count = waitFor DB.table("users").count()
"""
    check analyzeDbAsyncSource(source).findings.len == 0

  test "uses the innermost proc scope":
    let source = """proc outer() {.async.} =
  proc helper(): JsonNode =
    DB.table("users").first()
"""
    let analysis = analyzeDbAsyncSource(source)
    check analysis.findings.len == 1
    check not analysis.findings[0].safe
