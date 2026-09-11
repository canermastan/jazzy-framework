import std/[json, unittest]
import ../examples/todo_app/services/auth_service

suite "Todo App Authentication Example":

  test "authentication claims never include a password hash":
    let user = %*{
      "id": 1,
      "username": "ada",
      "password": "pbkdf2-sha256$600000$salt$hash"
    }
    let claims = authClaims(user)

    check claims == %*{"id": 1, "username": "ada"}
    check not claims.hasKey("password")
