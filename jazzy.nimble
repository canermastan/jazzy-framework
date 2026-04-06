import std/[os, strutils]

# Package

version       = "0.3.0"
author        = "canermastan"
description   = "Productive, developer-friendly web framework for Nim. Write less code, build more features."
license       = "MIT"
srcDir        = "src"
namedBin      = {"jazzy_cli": "jazzy"}.toTable()
installExt    = @["nim"]

# Dependencies

requires "nim >= 2.0.0"
requires "mummy >= 0.4.0"
requires "jwt >= 0.1.0"
requires "nimcrypto >= 0.5.4"
requires "tiny_sqlite >= 0.2.0"

# Tasks

task test, "Run all tests":
  for file in listFiles("tests"):
    if file.startsWith("tests" / "test_") and file.endsWith(".nim"):
      exec "nim c -r --path:src --hints:off --verbosity:0 " & file
