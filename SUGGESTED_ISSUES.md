# 🚀 Suggested Issues for Jazzy Framework

Welcome to the future of Jazzy! Here's a curated list of features and improvements we'd love to see. If you're interested, open an issue to claim it!

---

## 🗄️ Database
### 1. Advanced Query Builder
**Description:** Enhance `DB.table()` with more powerful methods:
- `orderBy(col, direction)`
- `groupBy(col)`
- `whereIn(col, values[])`
- `orWhere(col, op, val)`
- `joins(table, localKey, foreignKey)`
**Goal:** Reduce the need for `DB.raw()` for common complex queries.

### 2. Database Transactions
**Description:** Implement `DB.transaction do: ...` to allow multiple operations to be committed or rolled back together.
**Goal:** Ensure data integrity for complex operations.

### 3. PostgreSQL & MySQL Drivers
**Description:** Currently, we are SQLite-only. Implement drivers for larger databases using the same `DB` API.
**Goal:** Make Jazzy enterprise-ready.

---

## 🛠️ Jazzy CLI
### 4. Auth Scaffolding (The Big One! 🚀)
**Description:** Implement a command like `jazzy make:auth`.
- It should ask: "Do you want to generate Login/Register/Forgot Password boilerplate?"
- If yes, it generates the Controllers, Services, and HTML views automatically.
**Goal:** Go from zero to a fully functional Auth system in 1 second.

### 5. Database Migrations
**Description:** Create a system to version-control database changes (e.g., `jazzy make:migration create_users_table`).
**Goal:** Stop manual SQL schema management.

---

## 🖥️ Dev UI
### 6. Interactive SQL Console
**Description:** Add a tab in the Dev UI (`/dev-ui`) where developers can write and run SQL queries directly in the browser.
**Goal:** Faster debugging and data inspection without external tools.

### 7. Real-time Log Viewer
**Description:** A dashboard in the Dev UI to see incoming logs in real-time with filtering by level (Info, Warn, Error).
**Goal:** Monitor the server state visually.

---

## 📚 Documentation & Community
### 8. Core API Docstrings 🟢 Good First Issue
**Description:** Many core procedures lack `##` docstrings. Add them to `src/jazzy/http/context.nim` and `src/jazzy/db/builder.nim`.
**Goal:** Generate beautiful automated docs with `nim doc`.

---

Pick an issue that excites you and let's build the best Nim framework together! 🎷
