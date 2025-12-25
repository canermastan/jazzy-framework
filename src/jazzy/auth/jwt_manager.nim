import std/[json, times, options, strutils, tables]
import jwt

type
  JwtManager* = ref object
    secret: string
    algorithm: string

proc newJwtManager*(secret: string, algorithm: string = "HS256"): JwtManager =
  new(result)
  result.secret = secret
  result.algorithm = algorithm

proc sign*(manager: JwtManager, payload: JsonNode,
    expiresInSeconds: int = 3600): string =
  var claimsNode = newJObject()

  if payload.kind == JObject:
    for k, v in payload:
      claimsNode[k] = v

  if not claimsNode.hasKey("exp"):
    claimsNode["exp"] = %(getTime().toUnix() + expiresInSeconds)

  var fullToken = newJObject()
  fullToken["header"] = %*{"typ": "JWT", "alg": manager.algorithm}
  fullToken["claims"] = claimsNode

  var jwtToken = toJWT(fullToken)

  jwtToken.sign(manager.secret)
  result = $jwtToken

proc verify*(manager: JwtManager, token: string): Option[JsonNode] =
  try:
    let jwtToken = token.toJWT()
    if jwtToken.verify(manager.secret, HS256):
      var payload = newJObject()
      let claims = jwtToken.claims

      for k, v in claims:
        try:
          payload[k] = v.node
        except:
          discard

      if payload.hasKey("exp"):
        let expNode = payload["exp"]
        var exp: int64 = 0

        case expNode.kind
        of JInt: exp = expNode.getInt
        of JFloat: exp = expNode.getFloat.int64
        of JString:
          try: exp = parseBiggestInt(expNode.getStr)
          except: discard
        else: discard

        if exp > 0 and getTime().toUnix() > exp:
          return none(JsonNode)

      return some(payload)
    else:
      return none(JsonNode)
  except:
    return none(JsonNode)
