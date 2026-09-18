# Todo App

An await-first Jazzy API that demonstrates the built-in ORM, `.env` database
configuration, and versioned migrations.

## Run with SQLite

Copy `.env.example` to `.env`, set a private `JWT_SECRET`, then run:

```bash
# With Jazzy installed from Nimble
jazzy migrate
nim c -r app.nim
```

When developing inside this repository, use the source path instead:

```bash
nim c -r --path:../../src ../../src/jazzy_cli.nim migrate
nim c -r --path:../../src app.nim
```

The only migration source kept in the project is
`src/migrations/`. Jazzy generates its compile runner beneath ignored
`.jazzy/` whenever a migration command runs, so there is no `migrate.nim` or
registry file to maintain or accidentally delete.

The server starts on `http://localhost:8085`. Create an account with
`POST /auth/register`, log in with `POST /auth/login`, then use the protected
`/todos` endpoints.

## Try PostgreSQL

Replace the SQLite database block in `.env` with `DB_CONNECTION=postgres` and
`DATABASE_URL`. The migration and the ORM code are unchanged. The repository's
`postgres_example` compose file exposes a ready-to-use local PostgreSQL server
on port `55432`.
