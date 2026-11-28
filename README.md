# Giulietta – maintenance tracker

Web app in `www/`, packaged as an Android APK with Capacitor by GitHub Actions.
Download the latest APK from the **Releases** page (tag `latest`).

## App icon
The default icon is an original design (`icons/`). To use your own icon, add a square PNG named
`custom-icon.png` (1024x1024 recommended) to the repo root; the build applies it automatically.

## Updating without losing data
Builds are signed with the fixed key in `signing/debug.keystore`, so a new APK installs over the old one
and keeps your data (no uninstall needed). Use Settings > Backup before the first switch to this key.

## באחריות
A second app, the warranty and invoice keeper, lives in `bachrayut/` (see its README). APK tag: `bachrayut-latest`.
