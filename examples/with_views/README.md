# Views Example

A small Melody form-rendering example. It does not need a database or a
migration.

Copy `.env.example` to `.env`, set a private `JWT_SECRET`, and run this from
the example directory:

```bash
nim c -r --path:../../src app.nim
```

Open `http://localhost:8080`. In an installed Jazzy project, the equivalent is
simply `nim c -r app.nim`.
