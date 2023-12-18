import times
import strutils
import strformat
import terminal
import sequtils
import os
import httpclient
import json

const ONE_DAY = initDuration(days = 1)
const HTTP_HEADERS = {"User-Agent": "curl/8.5.0"}

proc mons(mm: openArray[Month], year: int, today: DateTime, holidays: seq[string]) =
  var dts = mm.mapIt(dateTime(year, it, 1, 0, 0, 0))
  for i, dt in dts:
    if i > 0:
      stdout.write "   "
    if today.month == dt.month and today.year == dt.year:
      stdout.styledWrite(styleUnderscore, bgBlue, fmt"{dt.month:^20}")
    else:
      stdout.styledWrite(styleUnderscore, fmt"{dt.month:^20}")
  stdout.writeLine ""

  for i, dt in dts:
    if i > 0:
      stdout.write "   "
    stdout.styledWrite(styleUnderscore, toSeq(dMon..dSun).mapIt(($it)[
        0..1]).join(" "))
  stdout.writeLine ""

  for _ in 1..6:
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
          if dt.format("yyyy-MM-dd") in holidays:
            if today.monthday == dt.monthday and today.month == dt.month and today.year == dt.year:
              stdout.styledWrite(bgRed, fmt"{dt.monthday():2}")
            else:
              stdout.styledWrite(fgRed, fmt"{dt.monthday():2}")
          elif dt.weekDay in [dSun, dSat]:
            if today.monthday == dt.monthday and today.month == dt.month and today.year == dt.year:
              stdout.styledWrite(bgBlue, fmt"{dt.monthday():2}")
            else:
              stdout.styledWrite(fgBlue, fmt"{dt.monthday():2}")
          else:
            if today.monthday == dt.monthday and today.month == dt.month and today.year == dt.year:
              stdout.styledWrite(bgBlue, fmt"{dt.monthday():2}")
            else:
              stdout.write(fmt"{dt.monthday():2}")
          dt += ONE_DAY
          if dt.weekday == dMon:
            break
        if dt.month() != mm[i]:
          stdout.write(" ".repeat(3*(6 - int(weekday(dt - ONE_DAY)))))
      i.inc
    stdout.writeLine ""

proc cacheHolidays(country: string, year: int) =
  let client = newHttpClient(headers = newHttpHeaders(HTTP_HEADERS))
  var c = country
  if country == "":
    c = client.getContent("https://ipinfo.io").parseJson()["country"].getStr().toLower()
  echo fmt "cache {year} {c}"
  let buf = client.getContent(fmt"https://date.nager.at/api/v3/PublicHolidays/{year}/{c}")
  let dir = getCacheDir("ncal")
  if not dirExists(dir):
    createDir(dir)
  if buf.parseJson().getElems().len == 0:
    return
  let file = dir / fmt"{year}_{c}"
  writeFile(file, buf)
  if country == "":
    createSymlink(file, dir / $year)

proc findHolidays(year: int, country: string): (string, seq[string]) =
  let dir = getCacheDir("ncal")
  let file = dir / $year

  if country == "":
    if not fileExists(file):
      cacheHolidays(country, year)
    let elems = readFile(file).parseJson().getElems()
    if elems.len > 0:
      result[0] = elems[0]["countryCode"].getStr().toLower()
    result[1] = elems.mapIt(it["date"].getStr())
    return
  else:
    if not fileExists(file & "_" & country):
      cacheHolidays(country, year)
    result[0] = country
    result[1] = readFile(file & "_" & country).parseJson().getElems().mapIt(it["date"].getStr())
    return

proc printYear(year: int, country: string) =
  let (country, holidays) = findHolidays(year, country)

  stdout.writeLine fmt"{year} ({country})"
  stdout.writeLine ""

  let today = now()
  mons([mJan, mFeb, mMar, mApr], year, today, holidays)
  mons([mMay, mJun, mJul, mAug], year, today, holidays)
  mons([mSep, mOct, mNov, mDec], year, today, holidays)

proc main() =
  var year = 0
  var country = ""
  if paramCount() == 1:
    if paramStr(1) in ["-h", "--help"]:
      echo fmt"{paramStr(0)} [year] [country]"
      quit 0
    else:
      try:
        year = parseInt(paramStr(1))
      except ValueError:
        year = now().year()
        country = paramStr(1)
  elif paramCount() == 2:
    try:
      year = parseInt(paramStr(1))
      country = paramStr(2)
    except ValueError:
      country = paramStr(1)
      year = parseInt(paramStr(2))
  elif paramCount() > 2:
    echo fmt"{paramStr(0)} [year] [country]"
    quit 1
  else:
    year = now().year()

  printYear(year, country)

when isMainModule:
  main()
