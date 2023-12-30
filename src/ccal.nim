import times
import strutils
import strformat
import terminal
import sequtils
import os
import osproc
import json
import tables

const NimblePkgVersion {.strdefine.} = "Unknown"
const APP = "ccal"
const ONE_DAY = initDuration(days = 1)
const IP_INFO_URL = "https://ipinfo.io"
const HOLIDAYS_URL = "https://date.nager.at/api/v3/PublicHolidays"

type
  PTYPE = enum
    Green
    Underscore

  PDaysSet = array[1+int(high(PTYPE)), bool]
  PDays = Table[string, PDaysSet]

proc nl() =
  stdout.writeLine ""

proc sp() =
  stdout.write "  "

proc personal(): PDays =
  let confDir = getConfigDir() / APP
  for pt in low(PTYPE)..high(PTYPE):
    try:
      for l in lines(confDir / toLower($pt) & ".txt"):
        result.mgetOrPut(l, [false, false])[int(pt)] = true
    except IOError:
      discard

proc dayWrite(dt: DateTime, holidays: seq[string], pds: PDays, isToday: bool) =
  let s = fmt"{dt.monthday():2}"
  let f = dt.format("yyyy-MM-dd")
  let pd = pds.getOrDefault(f)
  if pd[int(Underscore)]:
    setStyle {styleUnderscore}

  if pd[int(Green)] or pd[int(Underscore)]:
    if f in holidays:
      setForegroundColor fgYellow
    else:
      setForegroundColor fgGreen
  else:
    if f in holidays:
      setForegroundColor fgRed
    elif dt.weekday in [dSun, dSat]:
      setForegroundColor fgBlue
    else:
      setForegroundColor fgWhite

  if isToday:
    setStyle {styleReverse}      
  
  stdout.styledWrite s

proc mons(mm: openArray[Month], year: int, today: DateTime, holidays: seq[string], pdays: PDays) =
  sp()
  var dts = mm.mapIt(dateTime(year, it, 1, zone = utc()))
  for i, dt in dts:
    if i > 0:
      stdout.write "   "
    if today.month == dt.month and today.year == dt.year:
      stdout.styledWrite(styleUnderscore, bgBlue, fmt"{dt.month:^20}")
    else:
      stdout.styledWrite(styleUnderscore, fmt"{dt.month:^20}")
  nl()

  sp()
  for i, dt in dts:
    if i > 0:
      stdout.write "   "
    stdout.styledWrite(styleUnderscore, toSeq(dMon..dSun).mapIt(($it)[
        0..1]).join(" "))
  nl()

  for _ in 1..6:
    sp()
    var i = 0
    for dt in dts.mitems:
      if i > 0:
        stdout.write "   "
      if dt.month != mm[i]:
        stdout.write(" ".repeat(max(0, 3*7 - 1)))
      else: 
        stdout.write(" ".repeat(max(0, 3*int(dt.weekday()) - 1)))
        while dt.month() == mm[i]:
          if dt.weekDay != dMon:
            stdout.write " "
          dt.dayWrite(holidays, pdays, today == dt)
          dt += ONE_DAY
          if dt.weekday == dMon:
            break
        if dt.month() != mm[i]:
          stdout.write(" ".repeat(3*(6 - int(weekday(dt - ONE_DAY)))))
      i.inc
    nl()

proc fetchJson(url: string): JsonNode =
  let cmd = fmt"curl -m 5 -s '{url}'"
  let (buf, code) = execCmdEx(cmd, {poUsePath})
  if code != 0:
    raise newException(OSError, "Error during exec: " & cmd)
  try:
    return buf.parseJson()
  except:
    raise newException(ValueError, "Cannot parse result of: " & buf)

proc cacheHolidays(cacheDir: string, country: string, year: int): string =
  result = country
  if result == "":
    result = fetchJson(IP_INFO_URL)["country"].getStr().toLower()
  let json = fetchJson(fmt"{HOLIDAYS_URL}/{year}/{result}")
  if json.getElems().len == 0:
    return ""
  if not dirExists(cacheDir):
    createDir(cacheDir)
  let file = cacheDir / fmt"{year}_{result}"
  writeFile(file, $json)
  if country == "":
    createSymlink(file, cacheDir / $year)

proc findHolidays(year: int, country: string): (string, seq[string]) =
  let cacheDir = getCacheDir(APP)
  var file = cacheDir / $year
  if country != "":
    file.add ("_" & country)
    result[0] = country
  if not fileExists(file):
    result[0] =
      try:
        cacheHolidays(cacheDir, country, year)
      except:
        stderr.writeLine getCurrentExceptionMsg()
        return ("", @[])
    if result[0] == "":
      return
  elif country == "":
    let parts = expandSymlink(file).extractFilename().split('_')
    doAssert parts.len == 2
    result[0] = parts[1]

  result[1] = readFile(file).parseJson().getElems().mapIt(it["date"].getStr())

proc printYear(year: int, country: string, today: DateTime) =
  let (country, holidays) = findHolidays(year, country)

  sp()
  if year == today.year:
    stdout.styledWrite(bgBlue, $year)
  else:
    stdout.write $year
  stdout.write fmt" ({country})"
  nl()
  nl()

  let pdays = personal()

  for mm in distribute(toSeq(mJan..mDec), 3):
    mons(mm, year, today, holidays, pdays)

proc parseArgs(): (seq[int], string) =
  for i in 1..paramCount():
    if paramStr(i) in ["--cleanup"]:
      removeDir(getCacheDir(APP))
      quit 0
    elif paramStr(1) in ["-v", "--version"]:
      echo NimblePkgVersion
      quit 0
    elif paramStr(i) in ["-h", "--help"] or paramStr(i).startsWith("-"):
      echo fmt"""
Usage:
{APP} [year(s)] [country]   year (or several) and country code
     [country] [year(s)]
     --cleanup             cleanup holidays cache
     --version -v          version
"""
      quit 0
    try:
      let y = parseInt(paramStr(i))
      result[0].add (if y < 100: 2000+y else: y)
    except ValueError:
      result[1] = paramStr(i)

proc main() =
  let (years, country) = parseArgs()
  let n = now().utc()
  let today = dateTime(n.year, n.month, n.monthday, zone = utc())
  if years.len == 0:
    printYear(today.year(), country, today)
  else:
    for i, y in years:
      if i > 0:
        nl()
      printYear(y, country, today)

proc testColors() =
  for (y, u) in [(false, false), (true, false), (false, true), (true, true)]:
    for (str0, style) in {"workday": fgWhite, "weekend": fgBlue, "holiday": fgRed, "weekend holiday":fgRed}:
      var str = str0
      if u:
        str = "underscore " & str
        setStyle {styleUnderscore}
      if y:
        str = "yellow " & str
        if str.contains "holiday":
          setForegroundColor(fgGreen)
        else:
          setForegroundColor(fgYellow)
      else:
        setForegroundColor(style)
      stdout.write fmt"{str:40}"
      setStyle {styleReverse}
      stdout.styledWrite(fmt"today {str:40}")
      nl()

when isMainModule:
  # testColors()
  main()
