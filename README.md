# ```ccal```

Calendar with local holidays via ip location

* Caches holidays and location in local cache folder
* Personal calendars
* Custom highlight [here](#custom-style)

![image](.github/images/ccal.png)

## Install

### Static binary
```bash
curl -LO https://github.com/inv2004/ccal/releases/latest/download/ccal \
&& chmod +x ccal \
&& mv ccal ~/bin/
```

### Nimble
```bash
nimble install ccal
```

### Custom style
`$HOME/.config/ccal/myevents.txt`
```
fgGreen
2024-01-05
2024-06-01
2024-07-01
2024-08-01
styleDim styleUnderscore
2024-06-02
2024-07-31
2024-08-17
```

* it mixes colors sometimes: if it is "red" holiday and your "green day" => yellow

## Usage
```bash
Usage:
ccal [year(s)] [country]   year (or several) and country code
     [country] [year(s)]
     -p                    print personal days
     --cleanup             cleanup holidays cache
     --version -v          version
```
