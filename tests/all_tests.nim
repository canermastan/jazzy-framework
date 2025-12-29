import osproc, strformat

# Simple runner to execute all tests
# We compile and run each test file individually to ensure isolation

const tests = [
  "tests/test_multipart.nim",
  "tests/test_context.nim",
  "tests/test_router.nim",
  "tests/test_auth.nim"
]

var failed = false

echo "======================================================="
echo "Running Jazzy Test Suite"
echo "======================================================="

for test in tests:
  echo fmt"Testing {test}..."
  let cmd = fmt"nim c -r --path:src --hints:off --verbosity:0 {test}"
  let res = execCmd(cmd)
  if res != 0:
    echo fmt"FAILED: {test}"
    failed = true
  else:
    echo fmt"PASSED: {test}"
  echo "-------------------------------------------------------"

if failed:
  echo "Some tests failed!"
  quit(1)
else:
  echo "All tests passed!"
