# Package

version       = "0.4.5"
author        = "inv2004"
description   = "calendar with local holidays via ip location"
license       = "MIT"
srcDir        = "src"
bin           = @["ccal"]


# Dependencies

requires "nim >= 2.0.0"

task static, "build static release":
  exec "nim -d:release -d:NimblePkgVersion="&version&" --opt:size --gcc.exe:musl-gcc --gcc.linkerexe:musl-gcc --passC:-flto --passL:'-flto -static' -o:"&bin[0]&" c src/ccal.nim && strip -s ccal"
