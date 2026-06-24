import unittest, json
import jazzy/utils/json_ext

suite "JSON Extensions Tests":

  setup:
    let data = %*{
      "name": "Caner",
      "age": 30,
      "age_str": "30",
      "price": 19.99,
      "price_int": 20,
      "price_str": "19.99",
      "is_admin": true,
      "is_admin_str": "true",
      "is_active_num": 1,
      "empty_field": newJNull(),
      "tags": ["nim", "web", "jazzy"],
      "address": {
        "city": "Istanbul"
      }
    }

  test "isNull behavior":
    check data.isNull("email") == true
    check data.isNull("empty_field") == true
    check data.isNull("name") == false
    
    let nullNode = newJNull()
    check nullNode.isNull() == true
    check data.isNull() == false

  test "has behavior":
    check data.has("name") == true
    check data.has("age") == true
    check data.has("email") == false
    check data.has("empty_field") == false

  test "getString behavior":
    check data.getString("name") == "Caner"
    check data.getString("age") == "30"
    check data.getString("price") == "19.99"
    check data.getString("is_admin") == "true"
    check data.getString("email", "default@example.com") == "default@example.com"
    check data.getString("empty_field", "fallback") == "fallback"

  test "getInt behavior":
    check data.getInt("age") == 30
    check data.getInt("age_str") == 30
    check data.getInt("price_int") == 20
    check data.getInt("price") == 20 # 19.99 to int is 20 (rounds to nearest)
    check data.getInt("is_admin") == 1 # true to 1
    check data.getInt("missing", 42) == 42
    check data.getInt("empty_field", 42) == 42

  test "getFloat behavior":
    check data.getFloat("price") == 19.99
    check data.getFloat("price_str") == 19.99
    check data.getFloat("price_int") == 20.0
    check data.getFloat("missing", 3.14) == 3.14

  test "getBool behavior":
    check data.getBool("is_admin") == true
    check data.getBool("is_admin_str") == true
    check data.getBool("is_active_num") == true
    check data.getBool("age") == true # 30 != 0
    check data.getBool("missing", false) == false
    
    let falsyData = %*{"f1": "false", "f2": "0", "f3": false, "f4": 0}
    check falsyData.getBool("f1", true) == false
    check falsyData.getBool("f2", true) == false
    check falsyData.getBool("f3", true) == false
    check falsyData.getBool("f4", true) == false

  test "getArray behavior":
    let tags = data.getArray("tags")
    check tags.kind == JArray
    check tags.len == 3
    
    let missingArray = data.getArray("missing")
    check missingArray.kind == JArray
    check missingArray.len == 0

  test "getObject behavior":
    let address = data.getObject("address")
    check address.kind == JObject
    check address.has("city") == true
    
    let missingObj = data.getObject("missing")
    check missingObj.kind == JObject
    check missingObj.len == 0
