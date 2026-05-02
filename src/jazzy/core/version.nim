import std/[os, strutils]

const nimblePath = static:
  var path = ""
  let baseDir = currentSourcePath().parentDir()
  let attempts = [
    baseDir / ".." / ".." / "jazzy.nimble",
    baseDir / ".." / ".." / ".." / "jazzy.nimble"
  ]
  for a in attempts:
    if fileExists(a):
      path = a
      break
  path

proc getVersion(): string =
  when nimblePath == "":
    return "0.0.0"
  else:
    let content = staticRead(nimblePath)
    for line in content.splitLines():
      if line.startsWith("version"):
        let parts = line.split("=")
        if parts.len > 1:
          return parts[1].strip().strip(chars = {'"'})
    return "0.0.0"

const JAZZY_VERSION* = getVersion()
