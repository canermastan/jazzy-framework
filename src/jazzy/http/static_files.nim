import std/[os, strutils, mimetypes, asyncdispatch, httpcore, times, asyncfile]
import context, types, router

var m: MimeDb
m = newMimetypes()
m.register("svg", "image/svg+xml")
m.register("ico", "image/x-icon")
m.register("json", "application/json")
m.register("webp", "image/webp")

proc getMimeType(ext: string): string =
  {.cast(gcsafe).}:
    result = m.getMimetype(ext, "application/octet-stream")

proc serveStatic*(rootPath: string, urlPrefix: string = "/public"): Middleware =
  let absRoot = normalizedPath(absolutePath(rootPath))

  let handler: MiddlewareProc = proc(ctx: Context, next: HandlerProc): Future[void] {.async, gcsafe.} =
    let reqPath = ctx.request.path

    if not reqPath.startsWith(urlPrefix):
      await next(ctx)
      return

    var relativePath = reqPath[urlPrefix.len..^1]
    if relativePath.startsWith("/"):
      relativePath = relativePath[1..^1]

    var fullPath = normalizedPath(absRoot / relativePath)
    let absFile = normalizedPath(absolutePath(fullPath))

    if not (absFile == absRoot or absFile.startsWith(absRoot & DirSep)):
      ctx.status(403).text("Forbidden")
      return

    if dirExists(fullPath):
      fullPath = fullPath / "index.html"

    if not fileExists(fullPath):
      await next(ctx)
      return

    let lastMod = getLastModificationTime(fullPath).utc
    let etag = "\"" & $lastMod.toTime().toUnix() & "\""

    if not ctx.request.headers.isNil and ctx.request.headers.hasKey("If-None-Match"):
      if ctx.request.headers["If-None-Match"] == etag:
        ctx.status(304).text("")
        return

    let ext = splitFile(fullPath).ext.replace(".", "").toLowerAscii()
    let mime = getMimeType(ext)

    let file = openAsync(fullPath, fmRead)
    var content = ""
    try:
      content = await file.readAll()
    except Exception as e:
      file.close()
      ctx.status(500).text("Internal Server Error")
      return

    file.close()

    ctx.response.headers["Content-Type"] = mime
    ctx.response.headers["Cache-Control"] = "public, max-age=3600"
    ctx.response.headers["Last-Modified"] = lastMod.format("ddd, dd MMM yyyy HH:mm:ss 'GMT'")
    ctx.response.headers["ETag"] = etag

    ctx.response.body = content
    discard ctx.status(200)
    return
  
  return Middleware(name: "StaticFiles(" & rootPath & ")", handler: handler)
