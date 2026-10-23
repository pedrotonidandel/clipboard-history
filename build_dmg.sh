#!/bin/bash
# Packages ClipboardHistory.app into a distributable .dmg: drag-to-Applications
# layout, a custom volume icon, and a short first-run readme for whoever
# you send it to (they won't have this repo's README).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ClipboardHistory"
DMG_NAME="ClipboardHistory"
STAGING_DIR=".dmg_staging"
DMG_PATH="${DMG_NAME}.dmg"

echo "Building ${APP_NAME}.app..."
./build_app.sh

echo "Preparing DMG contents..."
rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

cp "Resources/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
SetFile -c icnC "${STAGING_DIR}/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "${STAGING_DIR}" 2>/dev/null || true

cat > "${STAGING_DIR}/Read Me First.txt" <<'TXT'
Clipboard History
=================

To install:

1. Drag ClipboardHistory.app into the Applications folder shown next to it.
2. Open it from Applications (or Launchpad/Spotlight). Since it isn't signed
   with a paid Apple Developer certificate, macOS will warn that it's from
   an "unidentified developer" the first time — this is expected. Right-click
   (or Control-click) the app -> Open -> Open, to confirm you trust it. You
   only need to do this once.
3. It'll ask for Accessibility permission (needed to detect the shortcut and
   paste for you) -- grant it in System Settings -> Privacy & Security ->
   Accessibility, then relaunch the app.
4. Press ⌘⇧V (default — changeable later) to show your clipboard history.

From the menu bar icon (clipboard glyph) -> Settings..., you can change the
shortcut, turn on Launch at Login, and see the About page.
TXT

echo "Creating ${DMG_PATH}..."
hdiutil create -volname "${DMG_NAME}" -fs HFS+ -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
SetFile -a C "${DMG_PATH}" 2>/dev/null || true

rm -rf "${STAGING_DIR}"

echo "Done: ${DMG_PATH}"
