import std/unittest
import jazzy/core/version

suite "Jazzy Version":
  test "version is correctly loaded":
    check JAZZY_VERSION != "0.0.0"
    check JAZZY_VERSION.len > 0
    echo "Current Jazzy Version: ", JAZZY_VERSION
