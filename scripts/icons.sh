#!/bin/bash
# Applies the app icon to the generated Android project.
# To use your own icon, put a square PNG named custom-icon.png in the repo root.
set -e
RES=android/app/src/main/res
cp -r icons/res/* "$RES/"
if [ -f custom-icon.png ]; then
  pip install --quiet --break-system-packages pillow 2>/dev/null || pip install --quiet pillow
  python3 scripts/custom_icon.py custom-icon.png "$RES"
fi
