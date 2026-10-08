#!/bin/bash
# Renders App Store marketing screenshots (iPhone 6.3", 1206x2622) from marketing.html.
set -e
cd "$(dirname "$0")"
BROWSER="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
shots=(home post game bigo leetcode newsletter)
for lang in pt-BR en; do
  out="../$lang/iphone-6.3"
  mkdir -p "$out"
  for i in "${!shots[@]}"; do
    shot=${shots[$i]}
    file="$out/0$((i + 1))-$shot.png"
    "$BROWSER" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --allow-file-access-from-files --virtual-time-budget=3000 --window-size=1206,2622 \
      --screenshot="$PWD/$file" "file://$PWD/marketing.html?shot=$shot&lang=$lang" 2>/dev/null
    echo "$file"
  done
done
