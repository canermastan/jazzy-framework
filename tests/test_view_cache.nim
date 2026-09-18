import std/[unittest, os]
import jazzy/views/cache

# We force-set the env variable so tests can toggle dev/prod mode.
proc setEnv(val: string) =
  putEnv("APP_ENV", val)

suite "JazzyViews File Cache (Tier-1)":

  setup:
    # Each test gets a fresh store and a real temp file
    let store = newViewCacheStore()
    let tmpPath = getTempDir() / "jazzy_test_view.html"
    writeFile(tmpPath, "<p>Hello</p>")

  teardown:
    try: removeFile(tmpPath) except CatchableError: discard

  test "Development mode: always reads from disk (no caching)":
    setEnv("development")
    let (c1, ok1) = store.loadTemplate(tmpPath)
    check ok1
    check c1 == "<p>Hello</p>"
    check store.hits == 0 # no cache hit in dev mode

    # Modify file — should be reflected immediately
    writeFile(tmpPath, "<p>Updated</p>")
    let (c2, ok2) = store.loadTemplate(tmpPath)
    check ok2
    check c2 == "<p>Updated</p>"

  test "Production mode: first call is a miss, second is a hit":
    setEnv("production")
    let (c1, ok1) = store.loadTemplate(tmpPath)
    check ok1
    check c1 == "<p>Hello</p>"
    check store.misses == 1
    check store.hits == 0

    let (c2, ok2) = store.loadTemplate(tmpPath)
    check ok2
    check c2 == "<p>Hello</p>"
    check store.hits == 1

  test "Production mode: stale cache is invalidated on mtime change":
    setEnv("production")
    discard store.loadTemplate(tmpPath) # populate cache

    # Simulate file change: write new content and touch mtime
    # Sleep 10ms to ensure OS mtime resolution flips
    os.sleep(20)
    writeFile(tmpPath, "<p>Fresh</p>")

    let (c, ok) = store.loadTemplate(tmpPath)
    check ok
    check c == "<p>Fresh</p>"

  test "Missing file returns (empty, false)":
    setEnv("production")
    let (c, ok) = store.loadTemplate("/does/not/exist.html")
    check not ok
    check c == ""

  test "evictTemplate removes entry from cache":
    setEnv("production")
    discard store.loadTemplate(tmpPath)
    check store.stats().templateEntries == 1

    store.evictTemplate(tmpPath)
    check store.stats().templateEntries == 0
    check store.evictions == 1

  test "clearTemplateCache wipes all entries":
    setEnv("production")
    discard store.loadTemplate(tmpPath)
    store.clearTemplateCache()
    check store.stats().templateEntries == 0

suite "JazzyViews Render Cache (Tier-2)":

  setup:
    let store = newViewCacheStore()

  test "Development mode: getCachedRender always returns miss":
    setEnv("development")
    store.putCachedRender("/p/v.html", "{}", "<h1>Hi</h1>", ttl = 0.0)
    let (html, hit) = store.getCachedRender("/p/v.html", "{}")
    check not hit
    check html == ""

  test "Production mode: put then get returns hit":
    setEnv("production")
    store.putCachedRender("/p/v.html", "{}", "<h1>Hi</h1>", ttl = 0.0)
    let (html, hit) = store.getCachedRender("/p/v.html", "{}")
    check hit
    check html == "<h1>Hi</h1>"

  test "Different data keys produce different entries":
    setEnv("production")
    store.putCachedRender("/p/v.html", """{"user":"Ali"}""", "<b>Ali</b>", ttl = 0.0)
    store.putCachedRender("/p/v.html", """{"user":"Ayse"}""", "<b>Ayse</b>", ttl = 0.0)

    let (h1, ok1) = store.getCachedRender("/p/v.html", """{"user":"Ali"}""")
    let (h2, ok2) = store.getCachedRender("/p/v.html", """{"user":"Ayse"}""")
    check ok1 and h1 == "<b>Ali</b>"
    check ok2 and h2 == "<b>Ayse</b>"

  test "TTL expiry evicts entry":
    setEnv("production")
    # Put with 1-second TTL
    store.putCachedRender("/p/v.html", "{}", "<h1>Exp</h1>", ttl = 1.0)
    let (_, hit1) = store.getCachedRender("/p/v.html", "{}")
    check hit1

    # Wait for expiry
    os.sleep(1100)
    let (_, hit2) = store.getCachedRender("/p/v.html", "{}")
    check not hit2
    check store.evictions == 1

  test "evictCachedRender removes single entry":
    setEnv("production")
    store.putCachedRender("/p/v.html", "{}", "<h1>X</h1>", ttl = 0.0)
    store.evictCachedRender("/p/v.html", "{}")
    let (_, hit) = store.getCachedRender("/p/v.html", "{}")
    check not hit

  test "clearAll wipes both tiers":
    setEnv("production")
    let tmpPath = getTempDir() / "jazzy_clear_test.html"
    writeFile(tmpPath, "x")
    discard store.loadTemplate(tmpPath)
    store.putCachedRender(tmpPath, "{}", "y", ttl = 0.0)

    store.clearAll()
    let s = store.stats()
    check s.templateEntries == 0
    check s.renderEntries == 0
    try: removeFile(tmpPath) except CatchableError: discard

suite "JazzyViews Cache Stats":

  test "stats returns correct counts":
    setEnv("production")
    let store = newViewCacheStore()
    let tmpPath = getTempDir() / "jazzy_stats_test.html"
    writeFile(tmpPath, "hello")

    discard store.loadTemplate(tmpPath) # miss
    discard store.loadTemplate(tmpPath) # hit
    store.putCachedRender(tmpPath, "{}", "y", ttl = 0.0)

    let s = store.stats()
    check s.templateEntries == 1
    check s.renderEntries == 1
    check s.hits == 1
    check s.misses == 1
    check s.enabled == true
    try: removeFile(tmpPath) except CatchableError: discard
