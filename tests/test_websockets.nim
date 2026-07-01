import unittest, asyncdispatch, tables, httpcore
import jazzy/http/[types, context, router]

suite "WebSocket Route Tests":

  test "WebSocket Route registers correctly":
    var wsCalled = false
    proc mockWsHandler(ws: JazzyWebSocket, event: WsEvent, msg: WsMessage) =
      wsCalled = true

    Route.ws("/test/ws", mockWsHandler)

    let req = JazzyRequest(httpMethod: HttpGet, path: "/test/ws")
    req.headers = newHttpHeaders()
    req.headers["Upgrade"] = "websocket"
    let ctx = newContext(req)

    waitFor dispatch(ctx)
    
    # Check if the handler was assigned to the context
    check ctx.wsHandler != nil
