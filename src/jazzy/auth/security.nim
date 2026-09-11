import nimcrypto/sysrand
import nimcrypto/pbkdf2
import nimcrypto/hmac
import nimcrypto/sha2
import std/[strutils, base64]
import ../core/config

type
  JwtConfigurationError* = object of CatchableError

const
  ## Legacy sentinel retained only for backwards-compatible configuration checks.
  DefaultJwtSecret* = "CHANGE_ME_IN_PROD_SECRET_KEY"
  SaltLength = 16
  LegacyIterations = 10_000
  PasswordHashIterations* = 600_000
  HashLength = 32
  JwtSecretLength = 32

proc generateEphemeralJwtSecret(): array[JwtSecretLength, byte] =
  if randomBytes(result) != JwtSecretLength:
    raise newException(Exception, "Failed to generate an ephemeral JWT secret")

let ephemeralJwtSecret = generateEphemeralJwtSecret()

proc ephemeralJwtSecretString(): string {.gcsafe.} =
  for b in ephemeralJwtSecret:
    result.add(toHex(int(b), 2))
  result = result.toLowerAscii()

proc constantTimeCompare*(a, b: string): bool =
  if a.len != b.len:
    return false
  var diff: byte = 0
  for i in 0 ..< a.len:
    diff = diff or (a[i].byte xor b[i].byte)
  return diff == 0

proc isSecureJwtSecret*(secret: string): bool =
  ## Returns whether a JWT signing secret is suitable for production.
  secret.len >= 32 and secret != DefaultJwtSecret

proc jwtSigningSecret*(): string {.gcsafe.} =
  ## Returns the configured signing secret, or a safe fallback.
  ##
  ## A missing or weak secret must never fall back to Jazzy's known legacy value.
  ## The ephemeral fallback preserves application availability, while deliberately
  ## invalidating tokens after a restart until configured.
  let configuredSecret = getConfig("JWT_SECRET")
  if not isSecureJwtSecret(configuredSecret):
    return ephemeralJwtSecretString()
  configuredSecret

proc jwtConfigurationWarnings*(): seq[string] =
  ## Returns migration warnings for insecure legacy JWT configuration.
  if not isSecureJwtSecret(getConfig("JWT_SECRET")):
    result.add("[Jazzy Deprecation] JWT_SECRET is missing, too short, or uses " &
      "the legacy default. Jazzy generated an ephemeral signing secret for this " &
      "process, so all JWTs will be invalid after restart. Set JWT_SECRET to a " &
      "cryptographically random value of at least 32 characters.")

proc requireSecureJwtSecret*() =
  ## Raises when production JWT configuration is not secure.
  ## Applications can call this to opt in to fail-closed startup now.
  if isProduction() and not isSecureJwtSecret(getConfig("JWT_SECRET")):
    raise newException(JwtConfigurationError,
      "JWT_SECRET must be set to a random value of at least 32 characters " &
      "when APP_ENV=production")

proc generateSalt(): string =
  var salt: array[SaltLength, byte]
  if randomBytes(salt) != SaltLength:
    raise newException(Exception, "Failed to generate random salt")
  return encode(salt)

proc hashPassword*(password: string): string =
  ## Hashes a password using versioned PBKDF2-HMAC-SHA256 parameters.
  let salt = generateSalt()
  let saltBytes = decode(salt)

  var derivedKey: array[HashLength, byte]
  var ctx: HMAC[sha256]

  discard pbkdf2(
    ctx,
    password,
    saltBytes,
    PasswordHashIterations,
    derivedKey
  )

  return "pbkdf2-sha256$" & $PasswordHashIterations & "$" & salt & "$" &
      encode(derivedKey)

proc passwordHashNeedsRehash*(storedHash: string): bool =
  ## Returns true for legacy hashes or hashes using an older work factor.
  let parts = storedHash.split('$')
  if parts.len != 4 or parts[0] != "pbkdf2-sha256":
    return true
  try:
    return parseInt(parts[1]) < PasswordHashIterations
  except ValueError:
    return true

proc verifyPassword*(password: string, storedHash: string): bool =
  ## Verifies both the current versioned and legacy `salt$hash` formats.
  try:
    let parts = storedHash.split('$')
    var salt: string
    var originalHash: string
    var iterations: int

    if parts.len == 4 and parts[0] == "pbkdf2-sha256":
      iterations = parseInt(parts[1])
      salt = parts[2]
      originalHash = parts[3]
    elif parts.len == 2:
      iterations = LegacyIterations
      salt = parts[0]
      originalHash = parts[1]
    else:
      return false

    if iterations <= 0 or iterations > PasswordHashIterations:
      return false

    let saltBytes = decode(salt)

    var derivedKey: array[HashLength, byte]
    var ctx: HMAC[sha256]

    discard pbkdf2(
      ctx,
      password,
      saltBytes,
      iterations,
      derivedKey
    )

    return constantTimeCompare(encode(derivedKey), originalHash)
  except:
    return false
