import jazzy
import router

proc main() =
  registerRoutes()

  Jazzy.serve(8085)

when isMainModule:
  main()
