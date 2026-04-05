import unittest, json, times, os
import jazzy/http/types
import jazzy/core/cache

suite "Cache System Tests":

  setup:
    let testCache = newJazzyCache()

  test "Basic Put and Get (String)":
    testCache.put("test_key", "test_value", 10)
    check testCache.get("test_key") == "test_value"

  test "Get non-existent key returns default":
    check testCache.get("missing_key") == ""
    check testCache.get("missing_key", "fallback") == "fallback"

  test "Put and Get (Int)":
    testCache.put("age", 25, 10)
    check testCache.get("age") == "25"

  test "Put and Get JsonNode":
    let jData = %*{"name": "Caner", "role": "admin"}
    testCache.put("user_data", jData, 10)
    
    let retrieved = testCache.getJson("user_data")
    check retrieved.kind == JObject
    check retrieved["name"].getStr() == "Caner"

  test "GetJson on non-existent or invalid key":
    let missing = testCache.getJson("missing_json")
    check missing.kind == JNull
    
    let defJson = %*{"default": true}
    let missingDef = testCache.getJson("missing_json", defJson)
    check missingDef == defJson

    # Invalid JSON string
    testCache.put("bad_json", "not a json string", 10)
    check testCache.getJson("bad_json").kind == JNull

  test "Cache expiration":
    testCache.put("temp_key", "temp_value", 1) # 1 second TTL
    check testCache.get("temp_key") == "temp_value"
    
    sleep(1100) # Wait for exactly 1.1 seconds
    
    check testCache.get("temp_key") == "" # Should be expired and deleted
    check testCache.has("temp_key") == false

  test "Has method":
    testCache.put("exist_key", "value", 10)
    check testCache.has("exist_key") == true
    check testCache.has("non_exist_key") == false

  test "Delete method":
    testCache.put("to_delete", "value", 10)
    check testCache.has("to_delete") == true
    testCache.delete("to_delete")
    check testCache.has("to_delete") == false

  test "Prune method":
    testCache.put("keep_key", "value", 10)
    testCache.put("expire_key1", "value", -1) # Already expired
    testCache.put("expire_key2", "value", 0) # Expires immediately

    # Before prune
    check testCache.get("keep_key") == "value"
    
    testCache.prune()
    
    # After prune, expired keys should be removed. We check `has` which won't trigger `del` if it's already gone.
    # Actually, prune removes them directly. Let's just check they aren't there.
    check testCache.has("expire_key1") == false
    check testCache.has("expire_key2") == false
