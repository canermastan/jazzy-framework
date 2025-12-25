import std/[os, strutils, mimetypes, asyncdispatch, httpcore]
import context, types

proc serveStatic*(rootPath: string, urlPrefix: string = "/public"): MiddlewareProc =
  return proc(ctx: Context, next: HandlerProc): Future[void] {.async.} =
    let reqPath = ctx.request.path

    if not reqPath.startsWith(urlPrefix):
      await next(ctx)
      return

    var relativePath = reqPath[urlPrefix.len .. ^1]
    if relativePath.startsWith("/"):
      relativePath = relativePath[1..^1]

    if ".." in relativePath:
      ctx.status(403).text("Forbidden")
      return

    let fullPath = rootPath / relativePath

    if fileExists(fullPath):
      var m = newMimetypes()
      m.register("css", "text/css")
      m.register("js", "application/javascript")
      m.register("html", "text/html")
      m.register("png", "image/png")
      m.register("jpg", "image/jpeg")
      m.register("jpeg", "image/jpeg")
      m.register("txt", "text/plain")

      let ext = splitFile(fullPath).ext
      let mime = m.getMimetype(ext.replace(".", ""), "application/octet-stream")

      let content = readFile(fullPath)
      ctx.response.headers["Content-Type"] = mime
      ctx.text(content)
    else:
      ctx.status(404).text("File Not Found")
