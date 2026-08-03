#!/bin/bash
# Installs build/senti.app to /Applications and launches it.
#
#   ./install.sh            keep existing settings and unpacked tools
#   ./install.sh --fresh    wipe every trace first, so the next launch is a true first launch
#
# Use --fresh before any handover build. Leftover state hides bugs: an already-unpacked
# toolchain hides a broken extraction, and a stored preference hides a bad default.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="senti"
BUNDLE_ID="com.local.senti"
APP="build/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

if [[ ! -d "$APP" ]]; then
    echo "No ${APP} — run ./package-app.sh first." >&2
    exit 1
fi

echo "==> Quitting any running copy"
osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" 2>/dev/null || true
# scrcpy and adb are child processes that outlive the app if it was killed rather than quit.
pkill -f scrcpy 2>/dev/null || true
sleep 1

if [[ "${1:-}" == "--fresh" ]]; then
    echo "==> Wiping all state (fresh install)"
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    killall cfprefsd 2>/dev/null || true
    rm -f "$HOME/Library/Preferences/${BUNDLE_ID}.plist"
    rm -rf "$HOME/Library/Application Support/senti"
    rm -rf "$HOME/Library/Saved Application State/${BUNDLE_ID}.savedState"
    rm -rf "$HOME/Library/Caches/${BUNDLE_ID}"
    # ~/Movies/senti holds the user's own recordings and is deliberately left alone.
fi

echo "==> Installing to ${DEST}"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> Launching"
open "$DEST"

echo
echo "Installed ${DEST}"
