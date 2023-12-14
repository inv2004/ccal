import times
import strutils
import strformat
import terminal
import sequtils
import tables

const events = {
  "2023-04-09": 2,
  "2023-04-15": 2,
  "2023-04-22": 2,
  "2023-04-29": 1,
  "2023-04-30": 1,
  "2023-05-01": 1,
  "2023-05-20": 1,
  "2023-05-21": 1,
  "2023-05-27": 2,
  "2023-05-28": 1,
  "2023-06-10": 1,
  "2023-06-11": 1,
  "2023-06-17": 1,
  "2023-06-18": 1,
  "2023-07-01": 1,
  "2023-07-08": 1,
  "2023-07-15": 1,
  "2023-07-16": 1,
  "2023-07-22": 1,
  "2023-07-23": 1,
  "2023-07-30": 2,
  "2023-08-05": 1,
  "2023-08-13": 2,
  "2023-08-26": 1,
  "2023-08-27": 1,
  "2023-09-03": 1,
  "2023-09-16": 1,
  "2023-09-17": 2,
}.toTable

proc mons(mm: seq[Month], y: int) =
  var dts = mm.mapIt(initDateTime(1, it, y, 0, 0, 0, utc()))
  for dt in dts:
    stdout.styledWrite(styleUnderscore, fmt"{dt.month:^20}")
    stdout.write "   "
  
  stdout.writeLine ""
  for dt in dts:
    stdout.styledWrite(styleUnderscore, toSeq(dMon..dSun).mapIt(($it)[0..1]).join(" "))
    stdout.write "   "

  for dt in dts:
    discard

proc mon(m: Month, y: int) =
  var dt = initDateTime(1, m, y, 0, 0, 0, utc())
  stdout.styledWriteLine(styleUnderscore, fmt"{dt.month:^20}")
  stdout.styledWriteLine(styleUnderscore, toSeq(dMon..dSun).mapIt(($it)[0..1]).join(" "))
  stdout.write("   ".repeat(int(dt.weekday())))
  for _ in 0..<getDaysInMonth(m, y):
    let f = dt.format("yyyy-MM-dd")
    if f in events:
      if events[f] == 1:
        stdout.styledWrite(fgRed, fmt"{dt.monthday():2}")
      else:
        stdout.styledWrite(fgBlue, fmt"{dt.monthday():2}")
    else:
      stdout.write(fmt"{dt.monthday():2}")
    if dt.weekday == dSun:
      stdout.writeLine ""
    else:
      stdout.write " "
    dt += initDuration(days = 1)
  stdout.writeLine ""

proc main() =
  let y = 2023
  for m in mApr..mSep:
    mon(m, y)

when isMainModule:
  main()
