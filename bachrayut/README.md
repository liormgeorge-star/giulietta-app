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
`scripts/vendor.sh` copies the OCR engine and language data into `www/vendor/ocr` after `npm install`,
so scanning works offline in the APK. Opened as a plain web page without that folder, the app loads them from jsDelivr.

## Shared household (Firebase)
Sync uses Firebase Authentication (email + password) and Cloud Firestore; no Cloud Storage, so the free Spark plan is enough.
Invoice images are stored as Firestore documents (each kept under 1MB).
1. Firebase console > Authentication > Sign-in method: enable **Email/Password**.
2. Firestore Database > Create database, then Rules: paste `firestore.rules` and Publish.
3. Put the web app config in `www/firebase-config.js` (or paste it in the app: Settings > סנכרון בענן).
Roles are enforced by the rules: owner and "מוסיף/ה" write, "צפייה" reads only. Invite codes are valid for 7 days.

## Updates
Every build stamps its run number into the app and the release notes (`build: N`). The app checks the `bachrayut-latest`
release when it opens and offers the new APK. Write the user-facing "what is new" lines in `whatsnew.txt` before pushing.
