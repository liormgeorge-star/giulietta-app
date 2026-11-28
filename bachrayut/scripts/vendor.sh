#!/bin/bash
# Bundles third-party code into www/vendor so the app needs no CDN. Run after `npm install`.
#  - vendor/ocr: on-device OCR engine (tesseract.js) with Hebrew + English data
#  - vendor/firebase.js: Firebase Auth + Firestore for the shared household
set -e
NM=${1:-node_modules}
OUT=www/vendor/ocr
mkdir -p "$OUT/core" "$OUT/lang"
cp "$NM/tesseract.js/dist/tesseract.min.js" "$NM/tesseract.js/dist/worker.min.js" "$OUT/"
cp "$NM"/tesseract.js-core/tesseract-core-simd-lstm.wasm.js "$NM"/tesseract.js-core/tesseract-core-lstm.wasm.js "$OUT/core/"
cp "$NM/@tesseract.js-data/heb/4.0.0_best_int/heb.traineddata.gz" "$OUT/lang/"
cp "$NM/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz" "$OUT/lang/"
NODE_PATH="$NM" "$NM/.bin/esbuild" cloud/firebase-entry.js --bundle --minify --format=iife --global-name=FB \
  --target=es2019 --outfile=www/vendor/firebase.js --log-level=warning
du -sh www/vendor/*
