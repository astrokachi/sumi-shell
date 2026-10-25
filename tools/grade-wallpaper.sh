#!/usr/bin/env bash
# grade-wallpaper.sh <theme> <input> <output.jpg> [gravity] [extra]
#   Crops to 2560x1440 (cover) and grades the image into the theme's palette:
#   a luminance gradient map in the theme's inks, blended over a partly
#   desaturated original, then a gentle darken. Prints the output's mean
#   luminance (0-1); a dark-theme wallpaper should land roughly 0.10-0.32.
#   gravity: Center (default), North, South, East, West, NorthEast, ... or
#            a crop offset like "+0+300" applied after the cover resize.
#   extra:   optional extra brightness factor, e.g. 0.85 to darken further.
#   CEIL=<percent> (env) caps the brightest output tone; default 80.
set -euo pipefail
theme=$1 in=$2 out=$3 grav=${4:-Center} extra=${5:-1}
case $theme in
  andon)  stops=("#0C0907" "#3A2A1C" "#B08A5A" "#ECDDBF"); amt=55; sat=70; gam=0.85 ;;
  ai)     stops=("#060A14" "#15243F" "#56739A" "#E2E0D6"); amt=85; sat=35; gam=0.85 ;;
  ukiyoe) stops=("#080D15" "#1B2E47" "#8A9AA6" "#E8DCC2"); amt=15; sat=92; gam=0.88 ;;
  urushi) stops=("#090605" "#3A1D13" "#A27A36" "#EAD9AE"); amt=35; sat=85; gam=0.85 ;;
  raku)   stops=("#13100D" "#3B302A" "#8C7B5E" "#E4DACB"); amt=45; sat=65; gam=0.85 ;;
  yoru)   stops=("#07080D" "#1A2030" "#8291A8" "#E2E6EC"); amt=35; sat=70; gam=0.86 ;;
  *) echo "unknown theme $theme" >&2; exit 2 ;;
esac
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
magick -size 256x1 \
  \( -size 90x1 gradient:"${stops[0]}-${stops[1]}" \) \
  \( -size 100x1 gradient:"${stops[1]}-${stops[2]}" \) \
  \( -size 66x1 gradient:"${stops[2]}-${stops[3]}" \) \
  -delete 0 +append "$tmp/clut.png"
if [[ $grav == +* || $grav == -* ]]; then
  magick "$in"'[0]' -auto-orient -colorspace sRGB -alpha off -resize 2560x1440^ -crop "2560x1440$grav" +repage -extent 2560x1440 "$tmp/base.png"
else
  magick "$in"'[0]' -auto-orient -colorspace sRGB -alpha off -resize 2560x1440^ -gravity "$grav" -extent 2560x1440 "$tmp/base.png"
fi
magick "$tmp/base.png" -modulate 100,$sat "$tmp/sat.png"
magick "$tmp/base.png" -colorspace Gray -colorspace sRGB "$tmp/clut.png" -clut "$tmp/map.png"
magick "$tmp/sat.png" "$tmp/map.png" -compose blend -define compose:args=$amt -composite \
  -evaluate multiply "$extra" +level 0%,${CEIL:-80}% -level 0%,100%,$gam \
  -strip -interlace JPEG -sampling-factor 4:2:0 -quality 90 "$out"
magick "$out" -colorspace Gray -format "mean=%[fx:mean]\n" info:
