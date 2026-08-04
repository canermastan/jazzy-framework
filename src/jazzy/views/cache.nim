import std/[tables, times, locks, os, hashes]
import ../core/config

# Two-tier in-memory view cache for Melody.
#
# Tier 1 (file cache): stores raw template content keyed by absolute path.
#   Invalidated automatically when the file's mtime changes.
#   Eliminates per-request disk I/O in production.
#
# Tier 2 (output cache): stores the final rendered HTML keyed by hash(path + data).
#   Opt-in via ctx.renderCached. Use only for templates with rarely-changing data.
#   Supports TTL; ttl=0 means "never expire until server restart".
#
# Both tiers are disabled in development mode — template edits are visible immediately.

type
  TemplateEntry = object
    content: string
    mtime: Time ## mtime at load time; used for staleness check
    loadedAt: Time

  RenderedEntry = object
    html: string
    expiresAt: float ## epochTime() deadline; 0 = no expiry

  ViewCacheStore* = ref object
    templateLock: Lock
    templates: Table[string, TemplateEntry]

    renderLock: Lock
    rendered: Table[Hash, RenderedEntry]

    hits*: int ## Approximate counters (not lock-protected; for diagnostics only)
    misses*: int
    evictions*: int

proc newViewCacheStore*(): ViewCacheStore =
  result = ViewCacheStore(
    templates: initTable[string, TemplateEntry](),
    rendered: initTable[Hash, RenderedEntry]()
  )
  initLock(result.templateLock)
  initLock(result.renderLock)

var ViewCache* = newViewCacheStore()

proc fileModTime(path: string): Time =
  try: getLastModificationTime(path)
  except: Time()

proc makeRenderKey(viewPath, dataRepr: string): Hash =
  hash(viewPath) !& hash(dataRepr)

proc loadTemplate*(store: ViewCacheStore, path: string): (string, bool) =
  ## Loads template content from cache or disk.
  ## Dev mode: always reads from disk.
  ## Prod mode: returns cached content unless the file's mtime has changed.
  if isDevelopment():
    if not fileExists(path): return ("", false)
    try:
      {.cast(gcsafe).}: inc store.misses
      return (readFile(path), true)
    except IOError:
      return ("", false)

  let mtime = fileModTime(path)

  acquire(store.templateLock)
  let cached = store.templates.getOrDefault(path)
  release(store.templateLock)

  if cached.content.len > 0 and cached.mtime == mtime:
    {.cast(gcsafe).}: inc store.hits
    return (cached.content, true)

  if not fileExists(path): return ("", false)
  let content = try: readFile(path) except: return ("", false)

  acquire(store.templateLock)
  store.templates[path] = TemplateEntry(content: content, mtime: mtime,
      loadedAt: getTime())
  release(store.templateLock)

  {.cast(gcsafe).}: inc store.misses
  return (content, true)

proc evictTemplate*(store: ViewCacheStore, path: string) =
  ## Removes a single file entry. Useful after programmatic template writes.
  acquire(store.templateLock)
  store.templates.del(path)
  release(store.templateLock)
  {.cast(gcsafe).}: inc store.evictions

proc clearTemplateCache*(store: ViewCacheStore) =
  acquire(store.templateLock)
  store.templates.clear()
  release(store.templateLock)

proc getCachedRender*(store: ViewCacheStore,
                      viewPath, dataRepr: string): (string, bool) =
  ## Returns a previously rendered HTML string, or ("", false) on miss/expiry.
  ## Always returns miss in dev mode.
  if isDevelopment(): return ("", false)

  let key = makeRenderKey(viewPath, dataRepr)
  acquire(store.renderLock)
  let entry = store.rendered.getOrDefault(key)
  release(store.renderLock)

  if entry.html.len == 0:
    {.cast(gcsafe).}: inc store.misses
    return ("", false)

  if entry.expiresAt > 0 and epochTime() > entry.expiresAt:
    acquire(store.renderLock)
    store.rendered.del(key)
    release(store.renderLock)
    {.cast(gcsafe).}: inc store.evictions
    return ("", false)

  {.cast(gcsafe).}: inc store.hits
  return (entry.html, true)

proc putCachedRender*(store: ViewCacheStore,
                      viewPath, dataRepr, html: string,
                      ttl: float = 0.0) =
  ## Stores rendered HTML. ttl=0 means no expiry.
  ## No-op in dev mode.
  if isDevelopment(): return

  let key = makeRenderKey(viewPath, dataRepr)
  let expiresAt = if ttl > 0: epochTime() + ttl else: 0.0

  acquire(store.renderLock)
  store.rendered[key] = RenderedEntry(html: html, expiresAt: expiresAt)
  release(store.renderLock)

proc evictCachedRender*(store: ViewCacheStore, viewPath, dataRepr: string) =
  let key = makeRenderKey(viewPath, dataRepr)
  acquire(store.renderLock)
  store.rendered.del(key)
  release(store.renderLock)

proc clearRenderCache*(store: ViewCacheStore) =
  acquire(store.renderLock)
  store.rendered.clear()
  release(store.renderLock)

proc clearAll*(store: ViewCacheStore) =
  ## Clears both tiers. Equivalent of `php artisan view:clear`.
  store.clearTemplateCache()
  store.clearRenderCache()

type ViewCacheStats* = object
  templateEntries*: int
  renderEntries*: int
  hits*: int
  misses*: int
  evictions*: int
  enabled*: bool ## false in development mode

proc stats*(store: ViewCacheStore): ViewCacheStats =
  ## Thread-safe snapshot of cache diagnostics.
  acquire(store.templateLock)
  let tCount = store.templates.len
  release(store.templateLock)

  acquire(store.renderLock)
  let rCount = store.rendered.len
  release(store.renderLock)

  ViewCacheStats(
    templateEntries: tCount,
    renderEntries: rCount,
    hits: store.hits,
    misses: store.misses,
    evictions: store.evictions,
    enabled: not isDevelopment()
  )
