import unittest, tables
import jazzy/utils/multipart
import jazzy/core/types

suite "Multipart Parser Tests":

  test "Should parse basic multipart body":
    let boundary = "---------------------------974767299852498929531610575"
    let contentType = "multipart/form-data; boundary=" & boundary

    let body = "--" & boundary & "\r\n" &
               "Content-Disposition: form-data; name=\"avatar\"; filename=\"me.jpg\"\r\n" &
               "Content-Type: image/jpeg\r\n\r\n" &
               "BINARY_DATA_HERE" & "\r\n" &
               "--" & boundary & "--"

    let files = parseMultipart(body, contentType)

    check files.len == 1
    check files.hasKey("avatar")
    check files["avatar"].filename == "me.jpg"
    check files["avatar"].content == "BINARY_DATA_HERE"

  test "Should return empty if no boundary":
    let files = parseMultipart("data", "application/json")
    check files.len == 0
