#!/bin/bash
# Renders App Store marketing screenshots (iPhone 6.5", 1284x2778) from marketing.html.
set -e
cd "$(dirname "$0")"
for candidate in \
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
  if [ -x "$candidate" ]; then BROWSER="$candidate"; break; fi
done
[ -n "$BROWSER" ] || { echo "Nenhum navegador Chromium encontrado" >&2; exit 1; }
WIDTH=1284
HEIGHT=2778
# Perfil separado para não conflitar com o navegador aberto
PROFILE=$(mktemp -d)
trap 'rm -rf "$PROFILE"' EXIT
shots=(home post game bigo leetcode newsletter)
for lang in pt-BR en; do
  out="../$lang/iphone-6.5"
  mkdir -p "$out"
  for i in "${!shots[@]}"; do
    shot=${shots[$i]}
    file="$out/0$((i + 1))-$shot.png"
    rm -f "$file"
    # O Chrome às vezes sai com código != 0 mesmo gerando a imagem: confere o arquivo
    "$BROWSER" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --user-data-dir="$PROFILE" --allow-file-access-from-files --virtual-time-budget=3000 \
      --window-size=$WIDTH,$HEIGHT --screenshot="$PWD/$file" \
      "file://$PWD/marketing.html?shot=$shot&lang=$lang" >/dev/null 2>&1 || true
    [ -f "$file" ] || { echo "Falhou: $file" >&2; exit 1; }
    echo "$file"
  done
done
