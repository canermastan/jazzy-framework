import std/[asyncdispatch, os, strformat]
import jazzy
import migrations/registry

proc printStatus() {.async.} =
  let applied = await migrationStatus()
  for item in applied:
    echo fmt"[{item.batch}] {item.name}"

proc main() =
  let action = if paramCount() == 0: "up" else: paramStr(1)
  case action
  of "up":
    echo fmt"Applied {waitFor migrate(allMigrations())} migration(s)."
  of "status":
    waitFor printStatus()
  of "rollback":
    echo fmt"Rolled back {waitFor rollback(allMigrations())} migration(s)."
  else:
    quit(1)

when isMainModule:
  main()
