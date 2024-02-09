import times
import strutils
import strformat
import terminal
import sequtils
import os
import osproc
import json
import tables
import hashes

const NimblePkgVersion {.strdefine.} = "Unknown"
const APP = "ccal"
const ONE_DAY = initDuration(days = 1)
const IP_INFO_URL = "https://ipinfo.io"
const HOLIDAYS_URL = "https://date.nager.at/api/v3/PublicHolidays"
const LOW_YEAR = 100
const DEFAULT_FG_COLOR = if defined(windows): fgWhite else: fgDefault

type
  PTYPE = enum
    Green
    Underscore

  PDay = object
    colors: set[ForegroundColor]
    styles: set[Style]
  PDays = OrderedTable[DateTime, PDay]

proc hash(dt: DateTime): Hash =
  hash(format(dt, "yyyy-MM-dd"))

proc nl() =
  stdout.writeLine ""

proc sp() =
  stdout.write "  "

proc today(): DateTime =
  let todayLocal = now().local()
  dateTime(todayLocal.year, todayLocal.month, todayLocal.monthday, zone = utc())

proc mixColors(colors: set[ForegroundColor]): ForegroundColor =
  result = DEFAULT_FG_COLOR
  if colors == {fgGreen, fgRed}:
    return fgYellow
  elif colors == {fgBlue, fgRed}:
    return fgRed
  else:
    for c in colors:
      return c

proc dayWrite(dt: DateTime, pds: PDays) =
  var pd = pds.getOrDefault(dt)
  if dt.weekday in [dSun, dSat]:
    pd.colors.incl fgBlue
  setForegroundColor mixColors(pd.colors)
  setStyle pd.styles

  stdout.styledWrite fmt"{dt.monthday():2}"

proc mons(mm: openArray[Month], year: int, today: DateTime, pdays: PDays) =
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
          dt.dayWrite(pdays)
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

proc findHolidays(year: int, country: string): (string, PDays) =
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
        result[0] = ""
        return
    if result[0] == "":
      return
  elif country == "":
    let parts = expandSymlink(file).extractFilename().split('_')
    doAssert parts.len == 2
    result[0] = parts[1]

  for d in readFile(file).parseJson().getElems():
    result[1][d["date"].getStr().parse("yyyy-MM-dd", utc())] = Pday(colors: {fgRed})

proc mixDays(a, b: PDays): PDays =
  var keys = initTable[DateTime, bool]()
  for k, _ in a:
    keys[k] = true
  for k, _ in b:
    keys[k] = true
  for k, _ in keys:
    let aa = a.getOrDefault(k)
    let bb = b.getOrDefault(k)
    result[k] = PDay(colors: aa.colors + bb.colors, styles: aa.styles + bb.styles)

proc personalFile(f: string, year: int): PDays =
  var pday = PDay(colors: {fgGreen})
  for l in lines(f):
    try:
      var dt = parse(l, "YYYY-M-d", utc())
      if dt.year < LOW_YEAR:
        dt = dateTime(dt.year + 2000, dt.month, dt.monthday, zone = utc())
      result[dt] = pday
    except TimeParseError:
      try:
        var dt = parse(l, "M-d", utc())
        dt = dateTime(year, dt.month, dt.monthday, zone = utc())
        result[dt] = pday
      except TimeParseError:
        var firstStyle = true
        for str in l.replace(',', ' ').splitWhitespace():
          try:
            let c = parseEnum[ForegroundColor](str) # TODO: Nim exception destructor error
            pday.colors = {c}
          except ValueError:
            try:
              let style = parseEnum[Style](str)
              if firstStyle:
                pday.styles = {style}
                firstStyle = false
              else:
                pday.styles.incl style
            except ValueError:
              stderr.write("Cannot parse: `", str, "` in ", f)
              nl()

proc personal(year = today().year): PDays =
  let confDir = getConfigDir() / APP
  for f in walkFiles(confDir / "*.txt"):
    result = mixDays(result, personalFile(f, year))

proc printYear(year: int, country: string, today: DateTime) =
  let (country, holidays) = findHolidays(year, country)
  defer: resetAttributes()

  sp()
  if year == today.year:
    stdout.styledWrite(bgBlue, $year)
  else:
    stdout.write $year
  stdout.write fmt" ({country.toUpper()})"
  nl()
  nl()

  var pdays = mixDays(holidays, personal(year))
  pdays.mgetOrPut(today, PDay()).styles.incl styleReverse

  for mm in distribute(toSeq(mJan..mDec), 3):
    mons(mm, year, today, pdays)

proc printPersonal() =
  var pdays = personal()
  if pdays.len == 0:
    let confDir = getConfigDir() / APP
    echo """
No personal calendars found

You can create one, for example:
--- """ & confDir & """/mydays.txt ---
fgGreen
2024-06-01
2024-07-01
2024-08-01
styleUnderscore
2024-06-30
2024-07-31
2024-08-31
"""
    return

  pdays.sort(func (a, b: (DateTime, PDay)): int = cmp(a[0], b[0]))
  for dt, v in pdays:
    echo ($dt)[0..9], ": ", v

proc parseArgs(): (seq[int], string) =
  for i in 1..paramCount():
    if paramStr(i) in ["-p"]:
      printPersonal()
      quit 0
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
     -p                    print personal days
     --cleanup             cleanup holidays cache
     --version -v          version
"""
      quit 0
    try:
      let y = parseInt(paramStr(i))
      result[0].add (if y < LOW_YEAR: 2000+y else: y)
    except ValueError:
      result[1] = paramStr(i)

proc main() =
  let (years, country) = parseArgs()
  let today = today()
  if years.len == 0:
    printYear(today.year(), country, today)
  else:
    for i, y in years:
      if i > 0:
        nl()
      printYear(y, country, today)

when isMainModule:
  main()
