import unittest, std/[os, httpcore, json]
import jazzy/http/[context, types]

suite "IP Extraction Logic":
  setup:
    putEnv("TRUST_PROXY", "true")

  test "ip() should prefer X-Forwarded-For first element":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": " 203.0.113.195 , 70.41.3.18, 150.172.238.178"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "203.0.113.195"

  test "ip() should support IPv6 in X-Forwarded-For":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": "2001:db8::1"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "2001:db8::1"

  test "ip() should support Forwarded header (RFC 7239)":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"Forwarded": "for=203.0.113.195;proto=https"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "203.0.113.195"

  test "ip() should support IPv6 with brackets in Forwarded":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"Forwarded": "for=\"[2001:db8::1]\""})
    )
    let ctx = newContext(req)
    check ctx.ip() == "2001:db8::1"

  test "ip() should fallback to X-Real-IP":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Real-IP": " 203.0.113.195 "})
    )
    let ctx = newContext(req)
    check ctx.ip() == "203.0.113.195"

  test "ip() should skip invalid IPs and find the first valid one":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": "unknown, 203.0.113.195, -"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "203.0.113.195"

  test "ip() should NOT trust proxy headers if TRUST_PROXY is false":
    putEnv("TRUST_PROXY", "false")
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": "203.0.113.195"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "10.0.0.1"

  test "ip() should fallback to request IP if no valid headers":
    let req = JazzyRequest(
      ip: "127.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": "invalid-ip"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "127.0.0.1"

  test "ip() should skip private IPs in X-Forwarded-For and find real client":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": "203.0.113.195, 10.0.0.5, 192.168.1.2"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "203.0.113.195"

  test "ip() should support Cloudflare header (CF-Connecting-IP)":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"CF-Connecting-IP": "203.0.113.195"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "203.0.113.195"

  test "ip() should fallback to private IP if no public IPs in chain":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": "10.0.0.5, 192.168.1.2"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "10.0.0.5"

  test "ip() should support IPv6 private filtering":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({"X-Forwarded-For": "2001:db8::1, ::1"})
    )
    let ctx = newContext(req)
    check ctx.ip() == "2001:db8::1"

  test "Priority test: X-Forwarded-For > Cloudflare > Forwarded > X-Real-IP":
    let req = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({
        "X-Forwarded-For": "1.1.1.1",
        "CF-Connecting-IP": "2.2.2.2",
        "Forwarded": "for=3.3.3.3",
        "X-Real-IP": "4.4.4.4"
      })
    )
    let ctx = newContext(req)
    check ctx.ip() == "1.1.1.1"

    let req2 = JazzyRequest(
      ip: "10.0.0.1",
      headers: newHttpHeaders({
        "CF-Connecting-IP": "2.2.2.2",
        "Forwarded": "for=3.3.3.3",
        "X-Real-IP": "4.4.4.4"
      })
    )
    let ctx2 = newContext(req2)
    check ctx2.ip() == "2.2.2.2"
