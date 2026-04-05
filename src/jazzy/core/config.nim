import std/[os, strutils, tables]

var configs = initTable[string, string]()

proc loadEnv*(filename: string = ".env", silent: bool = false) =
  if fileExists(filename):
    for line in lines(filename):
      let trimmed = line.strip()
      if trimmed.len == 0 or trimmed.startsWith("#"):
        continue
      let parts = trimmed.split('=', 1)
      if parts.len == 2:
        configs[parts[0].strip()] = parts[1].strip()
  else:
    if not silent:
      echo "⚠️  Warning: " & filename & " not found."

proc getConfig*(key: string, default: string = ""): string =
  {.cast(gcsafe).}:
    if configs.hasKey(key):
      return configs[key]
  return getEnv(key, default)

proc getAllConfigs*(): Table[string, string] =
  {.cast(gcsafe).}:
    return configs

# --- Environment Helpers ---

proc getAppEnv*(): string =
  ## Returns current environment (development, production, etc.)
  getConfig("APP_ENV", "development").toLowerAscii()

proc isDevelopment*(): bool =
  ## Returns true if APP_ENV is "development" (default)
  getAppEnv() == "development"

proc isProduction*(): bool =
  ## Returns true if APP_ENV is "production"
  getAppEnv() == "production"

# Auto-load .env if it exists in the current directory (silent)
loadEnv(silent = true)

