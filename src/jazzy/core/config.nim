import std/[os, strutils]

proc loadEnv*(path: string = "") =
  var targetPath = path

  if targetPath.len == 0:
    if fileExists(".env"):
      targetPath = ".env"
    elif fileExists(getAppDir() / ".env"):
      targetPath = getAppDir() / ".env"
    else:
      return

  if fileExists(targetPath):
    for line in lines(targetPath):
      if line.strip().len == 0 or line.startsWith("#"): continue
      let parts = line.split('=', 1)
      if parts.len == 2:
        putEnv(parts[0].strip(), parts[1].strip())

proc getConfig*(key: string, default: string = ""): string =
  getEnv(key, default)

loadEnv()
