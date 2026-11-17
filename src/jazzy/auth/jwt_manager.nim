import std/[base64, json, options, strutils, times]
import nimcrypto/[hmac, sha2]
import ./security

type
  JwtManager* = ref object
    secret: string
    algorithm: string

proc newJwtManager*(secret: string, algorithm: string = "HS256"): JwtManager =
  new(result)
  result.secret = secret
  result.algorithm = algorithm

proc base64UrlEncode(data: string): string =
  if data.len == 0:
    return ""
  result = base64.encode(data, safe = true)
  while result.len > 0 and result[^1] == '=':
    result.setLen(result.len - 1)

proc base64UrlDecode(encoded: string): string =
  for ch in encoded:
    if ch notin {'A'..'Z', 'a'..'z', '0'..'9', '-', '_'}:
      raise newException(ValueError, "Invalid Base64URL character")
  let rem = encoded.len mod 4
  if rem == 1:
    raise newException(ValueError, "Invalid Base64URL length")
  var padded = encoded
  if rem > 0:
    padded.add(repeat('=', 4 - rem))
  result = base64.decode(padded)

proc signHs256(secret, signingInput: string): string =
  let digest = sha256.hmac(secret, signingInput)
  result = newString(digest.data.len)
  for i, b in digest.data:
    result[i] = char(b)

proc sign*(manager: JwtManager, payload: JsonNode,
    expiresInSeconds: int = 3600): string =
  if manager.algorithm != "HS256":
    raise newException(ValueError, "Unsupported JWT algorithm: " & manager.algorithm)

  var claimsNode = newJObject()

  if payload != nil and payload.kind == JObject:
    for k, v in payload:
      claimsNode[k] = v

  if not claimsNode.hasKey("exp"):
    claimsNode["exp"] = %(getTime().toUnix() + expiresInSeconds)

  let headerNode = %*{"typ": "JWT", "alg": manager.algorithm}
  let signingInput = base64UrlEncode($headerNode) & "." & base64UrlEncode($claimsNode)
  let signature = signHs256(manager.secret, signingInput)
  result = signingInput & "." & base64UrlEncode(signature)

proc verify*(manager: JwtManager, token: string): Option[JsonNode] =
  if manager.algorithm != "HS256":
    return none(JsonNode)

  try:
    let parts = token.split('.')
    if parts.len != 3 or parts[0].len == 0 or parts[1].len == 0 or parts[2].len == 0:
      return none(JsonNode)

    let headerNode = parseJson(base64UrlDecode(parts[0]))
    if headerNode.kind != JObject or not headerNode.hasKey("alg") or
        headerNode["alg"].kind != JString or headerNode["alg"].getStr != manager.algorithm:
      return none(JsonNode)

    let signingInput = parts[0] & "." & parts[1]
    let expectedSig = signHs256(manager.secret, signingInput)
    let providedSig = base64UrlDecode(parts[2])
    if not constantTimeCompare(providedSig, expectedSig):
      return none(JsonNode)

    let payload = parseJson(base64UrlDecode(parts[1]))
    if payload.kind != JObject:
      return none(JsonNode)

    let now = getTime().toUnix()
    if payload.hasKey("exp"):
      let expNode = payload["exp"]
      var exp: int64 = 0
      var hasExp = false

      case expNode.kind
      of JInt:
        exp = expNode.getBiggestInt
        hasExp = true
      of JFloat:
        exp = expNode.getFloat.int64
        hasExp = true
      of JString:
        try:
          exp = parseBiggestInt(expNode.getStr)
          hasExp = true
        except:
          return none(JsonNode)
      else:
        return none(JsonNode)

      if hasExp and exp > 0 and now > exp:
        return none(JsonNode)

    if payload.hasKey("nbf"):
      let nbfNode = payload["nbf"]
      var nbf: int64 = 0
      var hasNbf = false

      case nbfNode.kind
      of JInt:
        nbf = nbfNode.getBiggestInt
        hasNbf = true
      of JFloat:
        nbf = nbfNode.getFloat.int64
        hasNbf = true
      of JString:
        try:
          nbf = parseBiggestInt(nbfNode.getStr)
          hasNbf = true
        except:
          return none(JsonNode)
      else:
        return none(JsonNode)

      if hasNbf and nbf > 0 and now < nbf:
        return none(JsonNode)

    return some(payload)
  except:
    return none(JsonNode)
