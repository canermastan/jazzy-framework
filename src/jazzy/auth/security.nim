import nimcrypto/sysrand
import nimcrypto/pbkdf2
import nimcrypto/hmac
import nimcrypto/sha2
import std/[strutils, base64]

const
  SaltLength = 16
  Iterations = 10000
  HashLength = 32

proc generateSalt(): string =
  var salt: array[SaltLength, byte]
  if randomBytes(salt) != SaltLength:
    raise newException(Exception, "Failed to generate random salt")
  return encode(salt)

proc hashPassword*(password: string): string =
  let salt = generateSalt()
  let saltBytes = decode(salt)

  var derivedKey: array[HashLength, byte]
  var ctx: HMAC[sha256]

  discard pbkdf2(
    ctx,
    password,
    saltBytes,
    Iterations,
    derivedKey
  )

  return salt & "$" & encode(derivedKey)

proc verifyPassword*(password: string, storedHash: string): bool =
  try:
    let parts = storedHash.split('$')
    if parts.len != 2:
      return false

    let salt = parts[0]
    let originalHash = parts[1]
    let saltBytes = decode(salt)

    var derivedKey: array[HashLength, byte]
    var ctx: HMAC[sha256]

    discard pbkdf2(
      ctx,
      password,
      saltBytes,
      Iterations,
      derivedKey
    )

    return encode(derivedKey) == originalHash
  except:
    return false
