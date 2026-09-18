import jazzy
import std/[json, strutils]

# Jazzy loads `.env` automatically. Run this example from its own directory so
# Melody can find the local `views/` and `public/` folders.

proc showForm(ctx: Context) {.async.} =
  # Render the 'home.html' view. We pass no extra data for the initial GET.
  ctx.render("home", %*{
    "title": "Contact Us",
    "message": "",
    "success": false
  })

proc submitForm(ctx: Context) {.async.} =
  # Read form inputs from the POST body (application/x-www-form-urlencoded or JSON)
  let name = ctx.input("name")
  let email = ctx.input("email")
  let inquiry = ctx.input("inquiry")

  # Simple validation
  if name.len == 0 or email.len == 0:
    ctx.render("home", %*{
      "title": "Contact Us",
      "message": "Name and Email are required!",
      "success": false,
      "old": {"name": name, "email": email, "inquiry": inquiry}
    })
    return

  # In a real app, you would save this to DB here.
  # For now, we just return a success message to the view.
  ctx.render("home", %*{
    "title": "Thank You",
    "message": "Thanks " & name & ", we received your inquiry!",
    "success": true,
    "old": {"name": "", "email": "", "inquiry": ""}
  })

proc main() =
  Route.get("/", showForm)
  Route.post("/", submitForm)
  Jazzy.serveStatic("public", "/assets")
  Jazzy.serve(8080)

when isMainModule:
  main()
