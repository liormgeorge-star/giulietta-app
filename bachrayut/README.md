# באחריות – warranty and invoice keeper

A separate app from the Giulietta tracker. Web app in `www/`, packaged as an Android APK with Capacitor by
`.github/workflows/build-bachrayut.yml`. Download the latest APK from the **Releases** page (tag `bachrayut-latest`).

## What it does
- Photograph an invoice (or pick one from the gallery). On-device OCR (tesseract.js, Hebrew + English) fills in the
  product name, store, purchase date, amount, warranty length, serial number and brand, and sorts the product into a category.
- The brand links the product to its warranty provider: phone, email and official service page. The "צור קשר" card
  builds a ready claim message from the product's details.
- View the invoice full screen; send it by WhatsApp or email (Android share sheet with the image attached).
- Share with family: an invite over WhatsApp carries the install link and a data file; updates from each side merge
  (newest version of each product wins). Roles: view and add, or view only.
- Everything stays on the device (IndexedDB). Settings > Backup exports one file with all products and invoices.

## Build notes
`scripts/vendor_ocr.sh` copies the OCR engine and language data into `www/vendor/ocr` after `npm install`,
so scanning works offline in the APK. Opened as a plain web page without that folder, the app loads them from jsDelivr.
