# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2026-06-21

### 🚀 Added
- **Melody Template Engine**: A blazing-fast, zero-allocation template engine built directly into the framework. Features a developer-friendly syntax (`{{ $var }}`, `{!! $raw !!}`, `@if`, `@foreach`) heavily inspired by Laravel Blade.
- **Two-Pass Layout System**: Build DRY HTML interfaces using `@extends`, `@yield`, `@section`, and `@include` directives.
- **Two-Tier Cache Architecture**: 
  - *Tier-1 (File Cache)*: Automatically monitors file `mtime` and instantly invalidates stale templates in memory without server restarts. Bypassed entirely in development mode for perfect hot-reloading.
  - *Tier-2 (Render Cache)*: Extreme-performance HTML caching via `ctx.renderCached("view", data, ttl=3600)`.
- **Form Data Handling**: `ctx.input()` now natively parses `application/x-www-form-urlencoded` payloads, allowing seamless integration with standard HTML forms.
- **Full Views Example**: Added `examples/with_views` showcasing a complete app structure with layouts, partials, Pico CSS, and form state restoration using the `$old` paradigm.


## [0.3.0] - 2026-04-07

### 🚀 Added
- **Database Raw Queries**: New `DB.raw()` and `DB.rawExec()` for executing custom SQL. Includes variadic parameter support (DX) and returns JsonNode or affected row counts.
- **Dev UI Panel**: A built-in developer console at `/dev-ui` for inspecting routes, environment, and database. **Security**: Automatically disabled in production mode.
- **Protected Static Routes**: New `Route.staticRoute` API for serving files with middleware protection (e.g., authentication) and wildcard support.
- **Rate Limiting**: Built-in IP-based rate limiting middleware with standard HTTP headers (`X-RateLimit-*`).
- **Request ID & Logging System**: Automated unique request tracking via UUID-like IDs and structured logger. Includes `X-Request-Id` header in all responses.
- **Body Limit**: New middleware to restrict request payload sizes, configurable via `BODY_LIMIT_MB` in `.env`.
- **Validation Engine**: Laravel-inspired validation with automatic 422 error responses and rules like `required`, `email`, `min/max`, etc.
- **Enhanced Scaffolding**: `jazzy new` now generates a modern project structure with a complete Todo CRUD example and automated schema setup.

### 🛠 Changed
- **Named Middleware**: Refactored the middleware system from raw `MiddlewareProc` to named `Middleware` objects for better visibility in Dev UI.
- **Auto-Loading Environment**: `Jazzy.serve()` now automatically loads the `.env` file from the current directory, removing the need for manual `loadEnv()` calls.
- **Static File API**: Renamed `Jazzy.static` to `Jazzy.serveStatic` for clarity and consistency across the framework.
- **Framework Architecture**: Reorganized core types into `src/jazzy/http/types.nim` and decoupled HTTP layers to resolve circular dependencies.
- **Scaffold Defaults**: Removed `models/` and `services/` from the default project template to promote a cleaner, controller-focused start.

### 🛡 Fixed & Removed
- **Security**: Fixed a directory traversal vulnerability in the static file serving logic.
- **Thread Safety**: Resolved potential race conditions in Mummy's multithreaded environment by initializing database locks at the module level.
- **Async Safety**: Fixed GC-safety issues in asynchronous global state operations.
- **Clean Up**: Removed deprecated `model.nim` and `makePrototype` templates.
