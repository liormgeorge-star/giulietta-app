#!/bin/bash
# Applies the app icon to the generated Android project.
# To use your own icon (e.g. a logo you own), add a square PNG named custom-icon.png (1024x1024 is ideal) to the repo root.
set -e
RES=android/app/src/main/res
cp -r icons/res/* "$RES/"
if [ -f custom-icon.png ]; then
  IM=$(command -v magick || command -v convert)
  for d in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
    IFS=: read n s f <<<"$d"
    $IM custom-icon.png -resize ${s}x${s} "$RES/mipmap-$n/ic_launcher.png"
    $IM custom-icon.png -resize ${s}x${s} \( -size ${s}x${s} xc:none -fill white -draw "circle $((s/2)),$((s/2)) $((s/2)),0" \) -compose DstIn -composite "$RES/mipmap-$n/ic_launcher_round.png"
    p=$((f*61/100))
    $IM custom-icon.png -resize ${p}x${p} -background none -gravity center -extent ${f}x${f} "$RES/mipmap-$n/ic_launcher_foreground.png"
  done
  echo "Applied custom-icon.png"
fi
