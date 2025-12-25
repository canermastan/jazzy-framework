import std/asyncdispatch
import types
import context

export types

type
  ServerDriver* = ref object of RootObj
    ## Abstract base class for Server Drivers.

method serve*(driver: ServerDriver, port: int, handler: HandlerProc) {.base, async.} =
  quit "Base ServerDriver.serve must be overridden!"
