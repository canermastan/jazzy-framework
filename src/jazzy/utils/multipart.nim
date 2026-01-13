import std/[strutils, tables]
import ../core/types

proc parseMultipart*(body: string, contentType: string): Table[string,
    UploadedFile] =
  result = initTable[string, UploadedFile]()

  # Extract boundary
  # Content-Type: multipart/form-data; boundary=---------------------------974767299852498929531610575
  if not contentType.contains("boundary="):
    return

  let boundaryPrefix = "boundary="
  let boundaryIndex = contentType.find(boundaryPrefix)
  if boundaryIndex == -1: return

  let boundary = "--" & contentType[boundaryIndex + boundaryPrefix.len .. ^1]

  if body.len == 0: return

  # Split by boundary
  # Note: This is an optimistic simplified parser.
  # Real-world multipart parsing is complex (streaming, nested, etc).
  let parts = body.split(boundary)

  for part in parts:
    if part.strip() == "--" or part.strip() == "": continue

    # Structure:
    # Headers \r\n\r\n Content \r\n
    let headerEndFn = part.find("\r\n\r\n")
    if headerEndFn == -1: continue

    let headersRaw = part[0 ..< headerEndFn].strip()
    let content = part[headerEndFn+4 .. ^1]

    # Remove trailing \r\n from content if exists (usually part of boundary separation)
    let cleanContent = if content.endsWith("\r\n"): content[0 ..
        ^3] else: content

    # Parse headers to find Content-Disposition
    # Content-Disposition: form-data; name="avatar"; filename="me.jpg"
    if "filename=\"" in headersRaw:
      var filename = ""
      var fieldname = ""
      var partContentType = "application/octet-stream"

      # Extract field name
      let nameMarker = "name=\""
      let nameStart = headersRaw.find(nameMarker)
      if nameStart != -1:
        let rest = headersRaw[nameStart + nameMarker.len .. ^1]
        let nameEnd = rest.find("\"")
        if nameEnd != -1:
          fieldname = rest[0 ..< nameEnd]

      # Extract filename
      let fnMarker = "filename=\""
      let fnStart = headersRaw.find(fnMarker)
      if fnStart != -1:
        let rest = headersRaw[fnStart + fnMarker.len .. ^1]
        let fnEnd = rest.find("\"")
        if fnEnd != -1:
          filename = rest[0 ..< fnEnd]

      # Extract Content-Type of the file part if present
      if "Content-Type: " in headersRaw:
        # simple extraction
        discard

      if fieldname.len > 0 and filename.len > 0:
        result[fieldname] = UploadedFile(
          filename: filename,
          contentType: partContentType,
          content: cleanContent
        )
