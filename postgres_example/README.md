# Jazzy PostgreSQL example

From this directory:

```bash
docker compose up -d
nim c -r app.nim
```

Then try:

```bash
curl http://localhost:8080/health
curl -X POST http://localhost:8080/todos -H "Content-Type: application/json" -d "{\"title\":\"Learn Jazzy\"}"
curl http://localhost:8080/todos
curl -X PATCH http://localhost:8080/todos/1 -H "Content-Type: application/json" -d "{\"completed\":true}"
curl -X DELETE http://localhost:8080/todos/1
```

The `.env` file already points at the Compose database. PostgreSQL is exposed
on host port `55432` to avoid colliding with a local PostgreSQL installation.

To stop the database while keeping its data:

```bash
docker compose stop
```

To remove its database volume too:

```bash
docker compose down -v
```
