import jazzy
import std/[json, strutils]

# Create a Jazzy app
# By default, it will look for the "views" directory in the current working directory.
# In this example, make sure you run this from the "examples/with_views" folder!

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

# Register routes
Route.get("/", showForm)
Route.post("/", submitForm)

# Start the server on port 8080
Jazzy.serveStatic("public", "/assets")
Jazzy.serve(8080)
