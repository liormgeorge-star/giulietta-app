#!/bin/bash
# Copies the on-device OCR engine (tesseract.js) and the Hebrew + English language data into www/vendor/ocr,
# so invoice scanning works inside the app without any download. Run after `npm install`.
set -e
NM=${1:-node_modules}
OUT=www/vendor/ocr
mkdir -p "$OUT/core" "$OUT/lang"
cp "$NM/tesseract.js/dist/tesseract.min.js" "$NM/tesseract.js/dist/worker.min.js" "$OUT/"
cp "$NM"/tesseract.js-core/tesseract-core-simd-lstm.wasm.js "$NM"/tesseract.js-core/tesseract-core-lstm.wasm.js "$OUT/core/"
cp "$NM/@tesseract.js-data/heb/4.0.0_best_int/heb.traineddata.gz" "$OUT/lang/"
cp "$NM/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz" "$OUT/lang/"
du -sh "$OUT"
