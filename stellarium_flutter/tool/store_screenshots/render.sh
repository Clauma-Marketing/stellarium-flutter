#!/bin/zsh
# Render localized App Store screenshots from captured scenes + shots.html.
#
#   ./render.sh              render all locales
#   ./render.sh en de        render only the given locales
#
# Output: out/<locale>/APP_IPHONE_67_N.png (1290x2796)
#         out/<locale>/APP_IPAD_PRO_3GEN_129_N.png (2048x2732)
set -euo pipefail

DIR="${0:A:h}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LOCALES=("$@")
(( $#LOCALES )) || LOCALES=(en de es fr zh tr it pl ro)

# Store order: hero, star, constellations, planet, dusk
PHONE_SHOTS=(constellations planet hero star search found dusk)
IPAD_SHOTS=(constellations planet star)

for lang in $LOCALES; do
  out="$DIR/out/$lang"
  mkdir -p "$out"
  i=0
  for shot in $PHONE_SHOTS; do
    i=$((i+1))
    "$CHROME" --headless=new --window-size=1290,2796 --hide-scrollbars --virtual-time-budget=15000 \
      --screenshot="$out/APP_IPHONE_67_$i.png" \
      "file://$DIR/shots_v8.html?fmt=phone&shot=$shot&lang=$lang" 2>/dev/null
    echo "$lang APP_IPHONE_67_$i.png ($shot)"
  done
  i=0
  for shot in $IPAD_SHOTS; do
    i=$((i+1))
    "$CHROME" --headless=new --window-size=2048,2732 --hide-scrollbars --virtual-time-budget=15000 \
      --screenshot="$out/APP_IPAD_PRO_3GEN_129_$i.png" \
      "file://$DIR/shots_v8.html?fmt=ipad&shot=$shot&lang=$lang" 2>/dev/null
    echo "$lang APP_IPAD_PRO_3GEN_129_$i.png ($shot)"
  done
done
