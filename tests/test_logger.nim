import unittest, os
import jazzy/core/logger

suite "Logger Tests":

  test "Default log level should be Info or Debug":
    let level = getMinLevel()
    check level in {Debug, Info}

  test "Setting log level at runtime":
    setLogLevel(Warn)
    check getMinLevel() == Warn
    setLogLevel(Error)
    check getMinLevel() == Error

  test "Log level logic":
    # This just ensures no crashes and code coverage for level logic
    setLogLevel(None)
    Log.info("This should not be logged")

    setLogLevel(Fatal)
    Log.fatal("Testing fatal log (should show)")
    Log.debug("Testing debug log (should NOT show)")

  test "LogLevel enum ordering":
    check ord(Debug) < ord(Info)
    check ord(Info) < ord(Warn)
    check ord(Warn) < ord(Error)
    check ord(Error) < ord(Fatal)
    check ord(Fatal) < ord(None)
