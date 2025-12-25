import unittest, json, tables, options, httpcore
import ../../src/jazzy/core/[types, context]

suite "Context Logic Tests":

  test "input() should prefer Query Params over Body":
    let req = JazzyRequest(
      queryParams: {"name": "QueryName"}.toTable,
      headers: newHttpHeaders(),
      body: """{"name": "BodyName"}"""
    )
    req.headers["Content-Type"] = "application/json"
    let ctx = newContext(req)

    check ctx.input("name") == "QueryName"

  test "input() should fallback to JSON Body":
    let req = JazzyRequest(
      queryParams: initTable[string, string](),
      headers: newHttpHeaders(),
      body: """{"name": "BodyName"}"""
    )
    req.headers["Content-Type"] = "application/json"
    let ctx = newContext(req)

    check ctx.input("name") == "BodyName"

  test "bodyAs[T] should deserialize JSON":
    type TestDto = ref object
      id: int
      name: string

    let req = JazzyRequest(
      body: """{"id": 123, "name": "Test"}"""
    )
    let ctx = newContext(req)
    let dto = ctx.bodyAs(TestDto)

    check dto.id == 123
    check dto.name == "Test"

  test "Responses should set body and headers":
    let req = JazzyRequest()
    let ctx = newContext(req)

    # Text
    ctx.text("Hello")
    check ctx.response.body == "Hello"
    check ctx.response.headers["Content-Type"] == "text/plain"

    # JSON
    ctx.json(%*{"a": 1})
    check ctx.response.body == """{"a":1}"""
    check ctx.response.headers["Content-Type"] == "application/json"
