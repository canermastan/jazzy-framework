import std/[unittest, json, os, strutils, tables]
import jazzy/views/engine

# All layout/include tests need real files on disk.
# We create a temp directory structure before each suite and clean it up after.

let tmpDir = getTempDir() / "jazzy_layout_tests"

proc write(path, content: string) =
  createDir(parentDir(path))
  writeFile(path, content)

suite "JazzyViews @include":

  setup:
    createDir(tmpDir / "partials")

  teardown:
    try: removeDir(tmpDir) except CatchableError: discard

  test "Basic @include embeds a partial":
    write(tmpDir / "nav.html", "<nav>Menu</nav>")
    let tmpl = "<header>@include(\"nav\")</header>"
    check renderString(tmpl, newJObject(), tmpDir) == "<header><nav>Menu</nav></header>"

  test "@include resolves variables from current data context":
    write(tmpDir / "greeting.html", "<p>Hello {{ $name }}</p>")
    let data = %*{"name": "Caner"}
    check renderString("@include(\"greeting\")", data, tmpDir) == "<p>Hello Caner</p>"

  test "@include supports explicit .html extension":
    write(tmpDir / "foot.html", "<footer>Bottom</footer>")
    check renderString("@include(\"foot.html\")", newJObject(), tmpDir) == "<footer>Bottom</footer>"

  test "@include inside @foreach sees loop variable":
    write(tmpDir / "item.html", "<li>{{ $item.label }}</li>")
    let data = %*{"items": [{"label": "A"}, {"label": "B"}]}
    let tmpl = "<ul>@foreach(items as item)@include(\"item\")@endforeach</ul>"
    check renderString(tmpl, data, tmpDir) == "<ul><li>A</li><li>B</li></ul>"

  test "@include inside @if is evaluated correctly":
    write(tmpDir / "badge.html", "[ADMIN]")
    let tmpl = "@if(admin)@include(\"badge\")@endif"
    check renderString(tmpl, %*{"admin": true},  tmpDir) == "[ADMIN]"
    check renderString(tmpl, %*{"admin": false}, tmpDir) == ""

  test "Missing @include raises ViewError":
    expect ViewError:
      discard renderString("@include(\"nonexistent\")", newJObject(), tmpDir)

  test "@include without viewsDir raises ViewError":
    expect ViewError:
      discard renderString("@include(\"nav\")", newJObject())

suite "JazzyViews @extends / @yield / @section":

  setup:
    createDir(tmpDir / "layouts")
    createDir(tmpDir / "partials")

  teardown:
    try: removeDir(tmpDir) except CatchableError: discard

  test "Basic layout inheritance":
    write(tmpDir / "layouts" / "app.html",
      "<html><body>@yield(\"content\")</body></html>")
    let child = """
@extends("layouts/app")
@section("content")
<h1>Hello</h1>
@endsection"""
    let result = renderString(child, newJObject(), tmpDir)
    check result.contains("<html><body>")
    check result.contains("<h1>Hello</h1>")
    check not result.contains("@extends")
    check not result.contains("@section")

  test "@yield slot receives rendered (not raw) content":
    write(tmpDir / "layouts" / "base.html", "@yield(\"main\")")
    let data = %*{"name": "World"}
    let child = """
@extends("layouts/base")
@section("main")Hello {{ $name }}@endsection"""
    check renderString(child, data, tmpDir) == "Hello World"

  test "Multiple @yield slots are filled independently":
    write(tmpDir / "layouts" / "full.html",
      "<title>@yield(\"title\")</title><body>@yield(\"content\")</body>")
    let child = """
@extends("layouts/full")
@section("title")My Page@endsection
@section("content")<main>Body</main>@endsection"""
    let result = renderString(child, newJObject(), tmpDir)
    check result == "<title>My Page</title><body><main>Body</main></body>"

  test "Undefined @yield slot emits empty string":
    write(tmpDir / "layouts" / "sparse.html", "A@yield(\"missing\")B")
    let child = "@extends(\"layouts/sparse\")"
    check renderString(child, newJObject(), tmpDir) == "AB"

  test "@section content supports all template directives":
    write(tmpDir / "layouts" / "base.html", "@yield(\"main\")")
    let data = %*{"users": [{"name": "Ali"}, {"name": "Ayse"}]}
    let child = """
@extends("layouts/base")
@section("main")
@foreach(users as u)<p>{{ $u.name }}</p>@endforeach
@endsection"""
    let result = renderString(child, data, tmpDir)
    check result.contains("<p>Ali</p>")
    check result.contains("<p>Ayse</p>")

  test "@section content can use @include":
    write(tmpDir / "layouts" / "base.html", "@yield(\"main\")")
    write(tmpDir / "partials" / "alert.html", "<div class=\"alert\">{{ $msg }}</div>")
    let data = %*{"msg": "Success!"}
    let child = """
@extends("layouts/base")
@section("main")
@include("partials/alert")
@endsection"""
    let result = renderString(child, data, tmpDir)
    check result.contains("<div class=\"alert\">Success!</div>")

  test "Layout itself can use @include":
    write(tmpDir / "layouts" / "withNav.html",
      "@include(\"partials/nav\")@yield(\"content\")")
    write(tmpDir / "partials" / "nav.html", "<nav>NAV</nav>")
    let child = """
@extends("layouts/withNav")
@section("content")<main>Page</main>@endsection"""
    let result = renderString(child, newJObject(), tmpDir)
    check result == "<nav>NAV</nav><main>Page</main>"

  test "Missing layout raises ViewError":
    let child = "@extends(\"layouts/nonexistent\")"
    expect ViewError:
      discard renderString(child, newJObject(), tmpDir)

  test "Content outside @section is ignored when @extends is present":
    write(tmpDir / "layouts" / "simple.html", "@yield(\"body\")")
    let child = """
@extends("layouts/simple")
This text should be ignored.
@section("body")REAL CONTENT@endsection
Also ignored."""
    let result = renderString(child, newJObject(), tmpDir)
    check result == "REAL CONTENT"

suite "JazzyViews extractSections (unit)":

  test "Extracts single section correctly":
    let tmpl = "@section(\"content\")<h1>Hi</h1>@endsection"
    let s = extractSections(tmpl)
    check s.hasKey("content")
    check s["content"] == "<h1>Hi</h1>"

  test "Extracts multiple sections":
    let tmpl = "@section(\"title\")T@endsection@section(\"body\")B@endsection"
    let s = extractSections(tmpl)
    check s["title"] == "T"
    check s["body"]  == "B"

  test "extractExtends returns layout name":
    check extractExtends("@extends(\"layouts/app\")") == "layouts/app"

  test "extractExtends returns empty string when absent":
    check extractExtends("<h1>Hello</h1>") == ""
