import std/[os, strutils]

const nimblePath = currentSourcePath().parentDir() / ".." / ".." / ".." / "jazzy.nimble"

proc getVersion(): string =
  let content = staticRead(nimblePath)
  for line in content.splitLines():
    if line.startsWith("version"):
      let parts = line.split("=")
      if parts.len > 1:
        return parts[1].strip().strip(chars = {'"'})
  return "0.0.0"

const JAZZY_VERSION* = getVersion()
