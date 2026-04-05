import std/[strutils, net, httpcore]
import ../core/config

proc isPrivate*(ip: string): bool =
  if ip.len == 0: return false
  try:
    let address = parseIpAddress(ip)
    case address.family
    of IpAddressFamily.IPv4:
      let octets = address.address_v4
      if octets[0] == 10: return true
      if octets[0] == 172 and octets[1] >= 16 and octets[1] <= 31: return true
      if octets[0] == 192 and octets[1] == 168: return true
      if octets[0] == 127: return true
      if octets[0] == 169 and octets[1] == 254: return true
      return false
    of IpAddressFamily.IPv6:
      let octets = address.address_v6
      if octets == [0'u8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          1]: return true
      if (octets[0] and 0b11111111) == 0b11111110 and (octets[1] and
          0b11000000) == 0b10000000: return true
      if (octets[0] and 0b11111110) == 0b11111100: return true
      return false
  except:
    return false

proc isValidIp*(ip: string): bool =
  if ip.len == 0: return false
  try:
    discard parseIpAddress(ip)
    return true
  except ValueError:
    return false

proc parseForwarded*(forwarded: string): string =
  for part in forwarded.split(';'):
    let p = part.strip()
    if p.toLowerAscii().startsWith("for="):
      var val = p[4..^1].strip()
      if val.startsWith("\"") and val.endsWith("\""):
        val = val[1..^2]
      if val.startsWith("[") and val.endsWith("]"):
        val = val[1..^2]
      return val
  return ""

proc getClientIp*(headers: HttpHeaders, remoteAddress: string): string =
  let trustProxy = getConfig("TRUST_PROXY", "false").toLowerAscii() == "true"

  if not trustProxy or headers.isNil:
    return remoteAddress

  # X-Forwarded-For
  if headers.hasKey("X-Forwarded-For"):
    let forwarded = headers["X-Forwarded-For"]
    if forwarded.len > 0:
      let ips = forwarded.split(",")
      for ipRaw in ips:
        let ip = ipRaw.strip()
        if isValidIp(ip) and not isPrivate(ip):
          return ip
      for ipRaw in ips:
        let ip = ipRaw.strip()
        if isValidIp(ip):
          return ip

  # Cloudflare
  if headers.hasKey("CF-Connecting-IP"):
    let ip = headers["CF-Connecting-IP"].strip()
    if isValidIp(ip):
      return ip

  # Forwarded (RFC 7239)
  if headers.hasKey("Forwarded"):
    let forwarded = headers["Forwarded"]
    if forwarded.len > 0:
      let ip = parseForwarded(forwarded)
      if isValidIp(ip):
        return ip

  # X-Real-IP
  if headers.hasKey("X-Real-IP"):
    let realIp = headers["X-Real-IP"]
    if realIp.len > 0:
      let ip = realIp.strip()
      if isValidIp(ip):
        return ip

  return remoteAddress
