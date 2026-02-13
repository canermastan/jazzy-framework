import unittest, json
import jazzy/core/[types, validation]

suite "Validation Tests":

  test "required rule - missing field":
    let input = %*{"name": "test"}
    let rules = %*{"email": "required"}
    expect(ValidationError):
      discard validate(input, rules)

  test "required rule - empty string":
    let input = %*{"email": ""}
    let rules = %*{"email": "required"}
    expect(ValidationError):
      discard validate(input, rules)

  test "required rule - valid field":
    let input = %*{"email": "test@test.com"}
    let rules = %*{"email": "required"}
    let result = validate(input, rules)
    check result["email"].getStr == "test@test.com"

  test "min rule - string too short":
    let input = %*{"password": "ab"}
    let rules = %*{"password": "min:3"}
    expect(ValidationError):
      discard validate(input, rules)

  test "min rule - string valid":
    let input = %*{"password": "abc"}
    let rules = %*{"password": "min:3"}
    let result = validate(input, rules)
    check result["password"].getStr == "abc"

  test "max rule - string too long":
    let input = %*{"name": "abcdef"}
    let rules = %*{"name": "max:5"}
    expect(ValidationError):
      discard validate(input, rules)

  test "max rule - string valid":
    let input = %*{"name": "abc"}
    let rules = %*{"name": "max:5"}
    let result = validate(input, rules)
    check result["name"].getStr == "abc"

  test "int rule - valid integer":
    let input = %*{"age": 25}
    let rules = %*{"age": "int"}
    let result = validate(input, rules)
    check result["age"].getInt == 25

  test "int rule - string is not int":
    let input = %*{"age": "not_a_number"}
    let rules = %*{"age": "int"}
    expect(ValidationError):
      discard validate(input, rules)

  test "bool rule - valid boolean":
    let input = %*{"active": true}
    let rules = %*{"active": "bool"}
    let result = validate(input, rules)
    check result["active"].getBool == true

  test "in rule - valid value":
    let input = %*{"role": "admin"}
    let rules = %*{"role": "in:admin,user,mod"}
    let result = validate(input, rules)
    check result["role"].getStr == "admin"

  test "in rule - invalid value":
    let input = %*{"role": "hacker"}
    let rules = %*{"role": "in:admin,user,mod"}
    expect(ValidationError):
      discard validate(input, rules)

  # Email validation tests
  test "email rule - valid email":
    let input = %*{"email": "user@example.com"}
    let rules = %*{"email": "required|email"}
    let result = validate(input, rules)
    check result["email"].getStr == "user@example.com"

  test "email rule - valid email with subdomain":
    let input = %*{"email": "user@mail.example.com"}
    let rules = %*{"email": "email"}
    let result = validate(input, rules)
    check result["email"].getStr == "user@mail.example.com"

  test "email rule - missing @":
    let input = %*{"email": "userexample.com"}
    let rules = %*{"email": "email"}
    expect(ValidationError):
      discard validate(input, rules)

  test "email rule - nothing before @":
    let input = %*{"email": "@example.com"}
    let rules = %*{"email": "email"}
    expect(ValidationError):
      discard validate(input, rules)

  test "email rule - nothing after @":
    let input = %*{"email": "user@"}
    let rules = %*{"email": "email"}
    expect(ValidationError):
      discard validate(input, rules)

  test "email rule - no dot in domain":
    let input = %*{"email": "user@localhost"}
    let rules = %*{"email": "email"}
    expect(ValidationError):
      discard validate(input, rules)

  test "email rule - domain ends with dot":
    let input = %*{"email": "user@example."}
    let rules = %*{"email": "email"}
    expect(ValidationError):
      discard validate(input, rules)

  test "email rule - not a string":
    let input = %*{"email": 12345}
    let rules = %*{"email": "email"}
    expect(ValidationError):
      discard validate(input, rules)

  test "multiple rules combined":
    let input = %*{
      "email": "admin@jazzy.dev",
      "password": "secret123"
    }
    let rules = %*{
      "email": "required|email",
      "password": "required|min:6"
    }
    let result = validate(input, rules)
    check result["email"].getStr == "admin@jazzy.dev"
    check result["password"].getStr == "secret123"

  test "multiple rules - email fails":
    let input = %*{
      "email": "not-an-email",
      "password": "secret123"
    }
    let rules = %*{
      "email": "required|email",
      "password": "required|min:6"
    }
    expect(ValidationError):
      discard validate(input, rules)
