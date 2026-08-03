#!/bin/bash
# Builds senti.app: release binary + Info.plist + icon + bundled scrcpy + ad-hoc signature.
#
# Ad-hoc signing means the code signature changes on every build, so macOS treats each build as
# a different app. Any permission already granted (notifications) stops matching silently.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="senti"
BUNDLE_ID="com.local.senti"
# Bump +0.1 for a normal round of changes, +1.0 for a major one. See CHANGELOG.md.
VERSION="1.5"
SCRCPY_TARBALL="scrcpy-macos-aarch64-v4.0.tar.gz"
APP="build/${APP_NAME}.app"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/Senti" "$APP/Contents/MacOS/${APP_NAME}"

echo "==> Bundling scrcpy"
# Unpacked into Application Support on first launch. Shipping the tarball rather than the
# unpacked tree keeps the bundle one file and the extraction step honest.
cp "Resources/${SCRCPY_TARBALL}" "$APP/Contents/Resources/"

echo "==> Rendering app icon"
swift Tools/make-icon.swift Assets/icon.svg "$APP/Contents/Resources/${APP_NAME}.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <!-- Menu-bar app: no Dock icon. Flips to .regular while the main window is open. -->
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP"

echo
echo "Built ${APP}"
echo "Install with:  ./install.sh"
