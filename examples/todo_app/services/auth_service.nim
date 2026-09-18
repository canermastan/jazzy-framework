import jazzy
import ../models/user

proc authClaims*(user: User): JsonNode =
  ## Returns the only user fields that may be stored in an authentication token.
  result = %*{
    "id": user.id,
    "username": user.username
  }

proc login*(username, password: string): Future[Option[User]] {.async.} =
  let user = await User.where("username", username).first()
  if user.isSome and verifyPassword(password, user.get().passwordHash):
    return user
  else:
    return none(User)

proc register*(username, password: string): Future[int64] {.async.} =
  let user = await User.create(User(
    username: username,
    passwordHash: hashPassword(password)
  ))
  user.id
