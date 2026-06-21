import std/[unittest, json]
import jazzy/views/engine

suite "JazzyViews Engine":

  test "Escaped output {{ $var }}":
    let data = %*{"name": "<b>Caner</b>", "user": {"age": 25}}

    check renderString("Hello {{ $name }}", data) == "Hello &lt;b&gt;Caner&lt;/b&gt;"
    check renderString("Age: {{ $user.age }}", data) == "Age: 25"
    # Missing path -> silent empty string
    check renderString("Missing: {{ $no.such.key }}", data) == "Missing: "

  test "Raw output {!! $var !!}":
    let data = %*{"html": "<strong>bold</strong>"}

    check renderString("{!! $html !!}", data) == "<strong>bold</strong>"
    # Escaped variant should escape it
    check renderString("{{ $html }}", data) == "&lt;strong&gt;bold&lt;/strong&gt;"

  test "@if conditionals":
    let data = %*{"isAdmin": true, "isUser": false, "user": {"name": "Admin"}}

    check renderString("@if(isAdmin)Welcome@endif", data) == "Welcome"
    check renderString("@if(isUser)User@elseNot User@endif", data) == "Not User"
    check renderString("@if(isAdmin)Hello {{ $user.name }}@endif", data) == "Hello Admin"
    # Missing key -> falsy
    check renderString("@if(missingKey)Yes@elseNo@endif", data) == "No"

  test "@if nested":
    let data = %*{"a": true, "b": true, "c": false}

    let tmpl = "@if(a)outer@if(b)inner@endif@endif"
    check renderString(tmpl, data) == "outerinner"

    let tmpl2 = "@if(a)@if(c)deep@else!deep@endif@endif"
    check renderString(tmpl2, data) == "!deep"

  test "@foreach loops":
    let data = %*{"users": [{"name": "Ali"}, {"name": "Ayse"}]}

    check renderString("@foreach(users as u){{ $u.name }} @endforeach", data) ==
      "Ali Ayse "
    # Nested @if inside @foreach
    check renderString(
      "@foreach(users as u)@if(u.name)[{{ $u.name }}]@endif@endforeach", data) ==
      "[Ali][Ayse]"

  test "@foreach nested":
    let data = %*{
      "rows": [
        {"cells": [{"v": 1}, {"v": 2}]},
        {"cells": [{"v": 3}]}
      ]
    }
    let tmpl = "@foreach(rows as r)(@foreach(r.cells as c){{ $c.v }}@endforeach)@endforeach"
    check renderString(tmpl, data) == "(12)(3)"

  test "@for counted loop":
    let data = newJObject()

    check renderString("@for($i = 0; $i < 3; $i++){{ $i }}@endfor", data) == "012"
    check renderString("@for($x = 1; $x <= 4; $x++){{ $x }},@endfor", data) == "1,2,3,4,"
    # Descending
    check renderString("@for($i = 3; $i > 0; $i--){{ $i }}@endfor", data) == "321"

  test "MAX_LOOP_ITER protection":
    let data = %*{"big": newJArray()}
    for _ in 1 .. 10_001:
      data["big"].add(%*{"v": 1})

    expect ViewError:
      discard renderString("@foreach(big as x){{ $x.v }}@endforeach", data)

  test "MAX_BLOCK_DEPTH protection":
    # Build a deeply nested @if chain that exceeds MAX_BLOCK_DEPTH
    var tmpl = ""
    for _ in 1 .. 70:
      tmpl.add("@if(ok)")
    tmpl.add("deep")
    for _ in 1 .. 70:
      tmpl.add("@endif")

    let data = %*{"ok": true}
    expect ViewError:
      discard renderString(tmpl, data)

  test "resolvePath edge cases":
    let data = %*{"a": {"b": {"c": 42}}, "arr": [1, 2, 3]}

    check resolvePath(data, "a.b.c").getInt() == 42
    check resolvePath(data, "a.b.missing").kind == JNull
    check resolvePath(data, "").kind == JNull
    check resolvePath(data, "$a.b.c").getInt() == 42   # $ sigil stripped

  test "Malformed tags are emitted literally":
    let data = newJObject()
    # Unclosed {{ should not crash, emit as-is
    let t1 = "Hello {{ world"
    check renderString(t1, data) == "Hello {{ world"
    # Unclosed @if — emit literally
    let t2 = "@if(ok)no end"
    check renderString(t2, data) == "@if(ok)no end"
