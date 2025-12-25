import unittest, json, options, httpcore, strutils, times
import ../../src/jazzy/core/[types, context]
import ../../src/jazzy/auth/[jwt_manager, security]

suite "Auth System Tests":

  setup:
    let req = JazzyRequest(
      headers: newHttpHeaders()
    )
    let ctx = newContext(req)

  test "Default context is not logged in":
    check ctx.check() == false
    check ctx.user.isNone()
    check ctx.id == 0

  test "login(user) should generate token and set session":
    let user = %*{"id": 1, "username": "testuser"}
    let token = ctx.login(user)

    check token.len > 0
    check ctx.check() == true
    check ctx.user.isSome()
    check ctx.user.get["username"].getStr == "testuser"
    check ctx.id == 1

  test "logout() should clear session":
    let user = %*{"id": 1}
    discard ctx.login(user)
    check ctx.check() == true

    ctx.logout()
    check ctx.check() == false
    check ctx.user.isNone()
    check ctx.id == 0

  test "Authorization header should authenticate user":
    let user = %*{"id": 99, "role": "admin"}
    let tempCtx = newContext(JazzyRequest(headers: newHttpHeaders()))
    let token = tempCtx.login(user)

    let req2 = JazzyRequest(headers: newHttpHeaders())
    req2.headers["Authorization"] = "Bearer " & token
    let ctx2 = newContext(req2)

    check ctx2.check() == true
    check ctx2.user.isSome()
    check ctx2.id == 99

  test "Invalid token should not authenticate":
    let req2 = JazzyRequest(headers: newHttpHeaders())
    req2.headers["Authorization"] = "Bearer invalid.token.value"
    let ctx2 = newContext(req2)

    check ctx2.check() == false
    check ctx2.user.isNone()

  test "Expired token should not authenticate":
    let manager = newJwtManager("CHANGE_ME_IN_PROD_SECRET_KEY")
    let user = %*{"id": 1}
    let token = manager.sign(user, -3600) # Expired 1 hour ago

    let req2 = JazzyRequest(headers: newHttpHeaders())
    req2.headers["Authorization"] = "Bearer " & token
    let ctx2 = newContext(req2)

    check ctx2.check() == false

  test "Password hashing should generate unique salts":
    let password = "samePassword"
    let hash1 = hashPassword(password)
    let hash2 = hashPassword(password)

    check hash1 != hash2
    check verifyPassword(password, hash1)
    check verifyPassword(password, hash2)

  test "Verify wrong password fails":
    let hash = hashPassword("secret")
    check verifyPassword("wrong", hash) == false

  test "Verify tampered hash fails":
    let password = "secret"
    var hash = hashPassword(password)
    hash = hash.replace(hash[^5..^1], "ABCDE")
    check verifyPassword(password, hash) == false

    let hash2 = hashPassword(password)
    let parts = hash2.split('$')
    let tampered = "ABC" & parts[0][3..^1] & "$" & parts[1]
    check verifyPassword(password, tampered) == false

  test "JWT Roundtrip with complex types":
    let manager = newJwtManager("s3cr3t")
    let payload = %*{
      "sid": "session_123",
      "isAdmin": true,
      "score": 100,
      "pi": 3.14
    }

    let token = manager.sign(payload)
    let decodedOpt = manager.verify(token)

    check decodedOpt.isSome()
    let decoded = decodedOpt.get()

    check decoded["sid"].getStr == "session_123"
    check decoded["isAdmin"].getBool == true
    check decoded["score"].getInt == 100
    # Floating point comparison might need tolerance, but simple eq check usually ok for exact json repr
    check decoded["pi"].getFloat == 3.14

  test "JWT Tampering detection":
    let manager = newJwtManager("s3cr3t")
    let token = manager.sign(%*{"user": "alice"})

    # Change last character of signature
    var badToken = token
    if badToken[^1] == 'a': badToken[^1] = 'b'
    else: badToken[^1] = 'a'

    check manager.verify(badToken).isNone()

  test "JWT Wrong secret failure":
    let manager1 = newJwtManager("secret1")
    let manager2 = newJwtManager("secret2")

    let token = manager1.sign(%*{"user": "alice"})
    check manager2.verify(token).isNone()
