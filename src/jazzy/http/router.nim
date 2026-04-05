import std/[asyncdispatch, httpcore, strutils, tables, sequtils, json]
import types, context
import ../core/server

export types

type
  RouteDef* = object
    httpMethod*: HttpMethod
    path*: string
    parts*: seq[string]
    isDynamic*: bool
    handler*: HandlerProc
    middlewares*: seq[string]

  Middleware* = object
    name*: string
    handler*: MiddlewareProc

  RouterStatic = ref object
    routes*: seq[RouteDef]
    staticRoutes*: array[HttpMethod, Table[string,
        RouteDef]]
    currentStack: seq[Middleware]
    currentPrefix: string

proc initRouter(): RouterStatic =
  new(result)
  result.routes = @[]
  result.currentStack = @[]
  result.currentPrefix = ""
  for methodId in HttpMethod:
    result.staticRoutes[methodId] = initTable[string, RouteDef]()

var Route* = initRouter()

proc splitPath(path: string): seq[string] =
  path.strip(leading = true, trailing = true, chars = {'/'}).split('/')

proc addRoute(router: RouterStatic, httpMethod: HttpMethod, path: string,
    handler: HandlerProc) =
  # Compose middleware
  var composedHandler = handler
  var mwNames: seq[string] = @[]
  
  for i in countdown(router.currentStack.len - 1, 0):
    let mw = router.currentStack[i]
    let next = composedHandler
    mwNames.add(mw.name)
    composedHandler = proc(ctx: Context): Future[void] {.async.} =
      await mw.handler(ctx, next)

  # Handle Prefix
  var fullPath = path
  if router.currentPrefix.len > 0:
    let cleanPath = if path.startsWith("/"): path[1..^1] else: path
    let cleanPrefix = if router.currentPrefix.endsWith(
        "/"): router.currentPrefix[0..^2] else: router.currentPrefix
    if cleanPath.len == 0:
      fullPath = cleanPrefix
    else:
      fullPath = cleanPrefix & "/" & cleanPath

  if not fullPath.startsWith("/"):
    fullPath = "/" & fullPath

  let parts = splitPath(fullPath)
  let isDynamic = parts.anyIt(it.startsWith(":"))

  let routeDef = RouteDef(
    httpMethod: httpMethod,
    path: fullPath,
    parts: parts,
    isDynamic: isDynamic,
    handler: composedHandler,
    middlewares: mwNames
  )

  router.routes.add(routeDef)

  if not isDynamic:
    router.staticRoutes[httpMethod][fullPath] = routeDef

template group*(router: RouterStatic, middlewaresList: seq[Middleware],
    body: untyped) =
  let prevLen = router.currentStack.len
  router.currentStack.add(middlewaresList)
  body
  router.currentStack.setLen(prevLen)

template group*(router: RouterStatic, middlewareItem: Middleware,
    body: untyped) =
  router.group(@[middlewareItem], body)

template groupPath*(router: RouterStatic, prefix: string, middlewaresList: seq[
    Middleware], body: untyped) =
  let prevPrefix = router.currentPrefix
  let prevLen = router.currentStack.len

  router.currentPrefix = if router.currentPrefix.len == 0: prefix
                         elif router.currentPrefix.endsWith(
                             "/"): router.currentPrefix & (if prefix.startsWith(
                             "/"): prefix[1..^1] else: prefix)
                         else: router.currentPrefix & "/" & (
                             if prefix.startsWith("/"): prefix[
                             1..^1] else: prefix)

  router.currentStack.add(middlewaresList)
  body
  router.currentStack.setLen(prevLen)
  router.currentPrefix = prevPrefix

template groupPath*(router: RouterStatic, prefix: string,
    middlewareItem: Middleware, body: untyped) =
  router.groupPath(prefix, @[middlewareItem], body)

template createRouteMethods(methodName, httpMethodEnum) =
  proc methodName*(router: RouterStatic, path: string, handler: proc(
      ctx: Context): Future[void]) =
    let wrapped: HandlerProc = proc(ctx: Context): Future[void] {.async.} =
      {.cast(gcsafe).}:
        await handler(ctx)
    router.addRoute(httpMethodEnum, path, wrapped)

  proc methodName*(router: RouterStatic, path: string, handler: proc(
      ctx: Context) {.gcsafe.}) =
    let wrapped: HandlerProc = proc(ctx: Context): Future[void] {.async.} =
      handler(ctx)
    router.addRoute(httpMethodEnum, path, wrapped)

createRouteMethods(get, HttpGet)
createRouteMethods(post, HttpPost)
createRouteMethods(put, HttpPut)
createRouteMethods(delete, HttpDelete)
createRouteMethods(patch, HttpPatch)
createRouteMethods(options, HttpOptions)

proc matchRoute(route: RouteDef, reqParts: seq[string], params: var Table[
    string, string]): bool =
  if route.parts.len != reqParts.len:
    return false

  for i, part in route.parts:
    if part.startsWith(":"):
      params[part[1..^1]] = reqParts[i]
    elif part != reqParts[i]:
      return false

  return true

proc dispatch*(ctx: Context) {.async.} =
  let reqPath = ctx.request.path
  let reqMethod = ctx.request.httpMethod

  var matchedRoute: RouteDef
  var found = false

  {.gcsafe.}:
    if Route.staticRoutes[reqMethod].hasKey(reqPath):
      matchedRoute = Route.staticRoutes[reqMethod][reqPath]
      found = true
    elif reqMethod == HttpOptions:
      for mId in HttpMethod:
        if mId != HttpOptions and Route.staticRoutes[mId].hasKey(reqPath):
          matchedRoute = Route.staticRoutes[mId][reqPath]
          found = true
          break

    if not found:
      var reqParts: seq[string]
      var partsLoaded = false

      for route in Route.routes:
        if route.httpMethod != reqMethod: continue
        if not route.isDynamic: continue

        if not partsLoaded:
          reqParts = splitPath(reqPath)
          partsLoaded = true

        var attemptParams = initTable[string, string]()
        if matchRoute(route, reqParts, attemptParams):
          matchedRoute = route
          found = true
          ctx.request.params = attemptParams
          break

      # Preflight fallback for dynamic routes
      if not found and reqMethod == HttpOptions:
        if not partsLoaded:
          reqParts = splitPath(reqPath)
          partsLoaded = true

        for route in Route.routes:
          if route.httpMethod == HttpOptions: continue
          if not route.isDynamic: continue

          var attemptParams = initTable[string, string]()
          if matchRoute(route, reqParts, attemptParams):
            matchedRoute = route
            found = true
            ctx.request.params = attemptParams
            break

  if found:
    try:
      await matchedRoute.handler(ctx)
    except ValidationError as e:
      ctx.status(422).json(%*{"errors": e.errors})
    except Exception as e:
      when defined(release):
        discard e
        ctx.status(500).json(%*{"error": "Internal Server Error"})
      else:
        ctx.status(500).json(%*{"error": e.msg})
  else:
    ctx.status(404).text("404 Not Found")
