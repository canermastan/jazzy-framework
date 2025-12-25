# 🚀 Suggested Issues for JazzyNim

Here is a list of potential contributions to help build the community. If you are new to the project, look for the **🟢 Good First Issue** tag!

### 1. Implement Request Logger Middleware 🟢 Good First Issue
**Description:** Create a built-in middleware that logs incoming requests (Method, Path, IP) and response status/time to the console.
**Skills:** Nim, String Formatting.
**File:** `src/jazzy/middlewares/logger.nim` (New)

### 2. Add CORS Middleware 🟢 Good First Issue
**Description:** Implement `Cross-Origin Resource Sharing` support to allow frontend apps on different ports to communicate with Jazzy.
**Skills:** HTTP Headers.
**File:** `src/jazzy/middlewares/cors.nim` (New)

### 3. Improve API Documentation 🟢 Good First Issue
**Description:** Many core procedures lack inline documentation. Add `##` docstrings to public procs in `src/jazzy/core/context.nim` and `src/jazzy/db/builder.nim`.
**Skills:** Documentation, English.

### 4. PostgreSQL Support
**Description:** Currently, Jazzy only supports SQLite.
**Skills:** Database, SQL, Generics.

### 5. File Upload Helper
**Description:** Enhance `ctx.file("key")` to include a simpler API for saving files to disk, e.g., `file.saveTo("public/uploads")`.
**Skills:** File I/O.

### 6. Global Exception Handler
**Description:** Allow users to define a custom closure to handle exceptions globally, rather than the default 500 JSON response.
**Skills:** Error Handling, Macros/Templates.

### 7. Database Migrations
**Description:** Implement a simple migration system to version control database schema changes (up/down scripts).
**Skills:** System Design, SQL.
