import std/[tables, times, locks, json, strutils]

type
  CacheItem = object
    value: string
    expiresAt: float

  JazzyCache* = ref object
    data: Table[string, CacheItem]
    lock: Lock

proc newJazzyCache*(): JazzyCache =
  result = JazzyCache(data: initTable[string, CacheItem]())
  initLock(result.lock)

var AppCache* = newJazzyCache()

proc put*(c: JazzyCache, key: string, value: string, ttl: int = 3600) =
  acquire(c.lock)
  try:
    let expiry = epochTime() + ttl.float
    c.data[key] = CacheItem(value: value, expiresAt: expiry)
  finally:
    release(c.lock)

proc put*(c: JazzyCache, key: string, value: JsonNode, ttl: int = 3600) =
  c.put(key, $value, ttl)

proc put*(c: JazzyCache, key: string, value: int, ttl: int = 3600) =
  c.put(key, $value, ttl)

proc get*(c: JazzyCache, key: string, default: string = ""): string =
  acquire(c.lock)
  defer: release(c.lock)

  if c.data.hasKey(key):
    let item = c.data[key]
    if epochTime() < item.expiresAt:
      return item.value
    else:
      # Expired, clean up
      c.data.del(key)
  return default

proc getJson*(c: JazzyCache, key: string): JsonNode =
  let raw = c.get(key)
  if raw.len > 0:
    try:
      return parseJson(raw)
    except JsonParsingError:
      return newJNull()
  return newJNull()

proc getJson*(c: JazzyCache, key: string, default: JsonNode): JsonNode =
  let res = c.getJson(key)
  if res.kind == JNull:
    return default
  return res

proc has*(c: JazzyCache, key: string): bool =
  acquire(c.lock)
  defer: release(c.lock)
  if c.data.hasKey(key):
    let item = c.data[key]
    if epochTime() < item.expiresAt:
      return true
    else:
      c.data.del(key)
  return false

proc delete*(c: JazzyCache, key: string) =
  acquire(c.lock)
  defer: release(c.lock)
  c.data.del(key)

proc clear*(c: JazzyCache) =
  acquire(c.lock)
  defer: release(c.lock)
  c.data.clear()

proc getAllKeys*(c: JazzyCache): seq[tuple[key: string, expiresAt: float]] =
  acquire(c.lock)
  defer: release(c.lock)
  result = @[]
  for k, v in c.data:
    result.add((k, v.expiresAt))

proc prune*(c: JazzyCache) =
  acquire(c.lock)
  defer: release(c.lock)
  var keysToRemove: seq[string] = @[]
  let now = epochTime()
  for k, v in c.data:
    if now >= v.expiresAt:
      keysToRemove.add(k)
  for k in keysToRemove:
    c.data.del(k)

proc increment*(c: JazzyCache, key: string, ttl: int = 60): int =
  ## Atomically increment a numeric value in cache.
  ## If key does not exist, it's initialized to 1 with the given TTL.
  acquire(c.lock)
  defer: release(c.lock)

  let now = epochTime()
  if c.data.hasKey(key):
    let item = c.data[key]
    if now < item.expiresAt:
      try:
        let val = parseInt(item.value) + 1
        c.data[key].value = $val
        return val
      except ValueError:
        # Not a number, reset to 1
        c.data[key] = CacheItem(value: "1", expiresAt: item.expiresAt)
        return 1
    else:
      # Expired, reset
      let expiry = now + ttl.float
      c.data[key] = CacheItem(value: "1", expiresAt: expiry)
      return 1
  else:
    # New key
    let expiry = now + ttl.float
    c.data[key] = CacheItem(value: "1", expiresAt: expiry)
    return 1

