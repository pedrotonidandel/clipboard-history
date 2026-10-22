#!/bin/bash
# Builds ClipboardHistory and wraps it into a double-clickable .app bundle.
# A real bundle (with a stable bundle identifier) is what System Settings
# needs to remember the Accessibility permission grant.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ClipboardHistory"
BUNDLE_ID="com.local.clipboardhistory"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"

echo "Building release binary..."
swift build -c release

echo "Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Logo.png" "${APP_DIR}/Contents/Resources/Logo.png"
cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Clipboard History</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Signing with local dev identity..."
codesign --force --deep --sign "ClipboardHistory Dev" "${APP_DIR}"

echo "Done: ${APP_DIR}"
echo "Run with: open ${APP_DIR}"
