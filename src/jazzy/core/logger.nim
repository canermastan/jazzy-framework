import std/[times, strutils]
import config

type
  LogLevel* = enum
    Debug
    Info
    Warn
    Error
    Fatal
    None ## Disables all logging

  JazzyLogger* = object
    discard

const
  AnsiReset = "\e[0m"
  AnsiBold = "\e[1m"
  AnsiGray = "\e[90m"
  AnsiGreen = "\e[32m"
  AnsiYellow = "\e[33m"
  AnsiRed = "\e[31m"
  AnsiRedBg = "\e[41;97m"

var
  Log* = JazzyLogger()
  currentLogLevel: LogLevel = None
  levelInitialized = false

proc levelColor(level: LogLevel): string =
  case level
  of Debug: AnsiGray
  of Info: AnsiGreen
  of Warn: AnsiYellow
  of Error: AnsiRed
  of Fatal: AnsiRedBg
  of None: ""

proc getMinLevel*(): LogLevel =
  ## Returns current log level. Initializes from config on first call.
  if not levelInitialized:
    {.cast(gcsafe).}:
      let raw = getConfig("LOG_LEVEL", "").toUpperAscii()
      currentLogLevel = case raw
        of "DEBUG": Debug
        of "INFO": Info
        of "WARN": Warn
        of "ERROR": Error
        of "FATAL": Fatal
        of "NONE": None
        else:
          if isProduction(): Info
          else: Debug
      levelInitialized = true
  return currentLogLevel

proc setLogLevel*(level: LogLevel) =
  ## Allows changing log level at runtime
  currentLogLevel = level
  levelInitialized = true

proc log*(logger: JazzyLogger, level: LogLevel, msg: string) =
  ## Core log proc — checks level, formats and outputs
  if level == None: return
  let minLevel = getMinLevel()
  if ord(level) < ord(minLevel):
    return

  let ts = now().format("yyyy-MM-dd HH:mm:ss")
  let color = levelColor(level)
  let label = ($level).toUpperAscii().alignLeft(5)
  echo AnsiGray & ts & AnsiReset & " " &
       color & AnsiBold & "[" & label & "]" & AnsiReset & " " & msg

proc debug*(logger: JazzyLogger, msg: string) =
  logger.log(Debug, msg)

proc info*(logger: JazzyLogger, msg: string) =
  logger.log(Info, msg)

proc warn*(logger: JazzyLogger, msg: string) =
  logger.log(Warn, msg)

proc error*(logger: JazzyLogger, msg: string) =
  logger.log(Error, msg)

proc fatal*(logger: JazzyLogger, msg: string) =
  logger.log(Fatal, msg)
