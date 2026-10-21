#!/bin/bash

# Droid Bridge macOS Installation & Gatekeeper Fix Helper

set -e

APP_NAME="Droid Bridge.app"
ALT_APP_NAME="droid_bridge.app"
TARGET_DIR="/Applications"

echo "=== Droid Bridge macOS Installer & Gatekeeper Fix ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH=""

if [ -d "$SCRIPT_DIR/$APP_NAME" ]; then
    APP_PATH="$SCRIPT_DIR/$APP_NAME"
elif [ -d "$SCRIPT_DIR/$ALT_APP_NAME" ]; then
    APP_PATH="$SCRIPT_DIR/$ALT_APP_NAME"
elif [ -d "/Applications/$APP_NAME" ]; then
    APP_PATH="/Applications/$APP_NAME"
elif [ -d "/Applications/$ALT_APP_NAME" ]; then
    APP_PATH="/Applications/$ALT_APP_NAME"
fi

if [ -z "$APP_PATH" ]; then
    echo "Searching for Droid Bridge.app..."
    APP_PATH=$(find "$SCRIPT_DIR" -maxdepth 2 -name "*.app" | head -n 1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Droid Bridge.app not found in $SCRIPT_DIR or /Applications."
    echo "Please place install.sh next to Droid Bridge.app and run again."
    return 1 2>/dev/null || true
fi

echo "Found app bundle at: $APP_PATH"

if [ "$APP_PATH" != "/Applications/Droid Bridge.app" ] && [ "$APP_PATH" != "/Applications/droid_bridge.app" ]; then
    echo "Installing to /Applications..."
    cp -R "$APP_PATH" "$TARGET_DIR/"
    INSTALLED_PATH="$TARGET_DIR/$(basename "$APP_PATH")"
else
    INSTALLED_PATH="$APP_PATH"
fi

echo "Clearing macOS quarantine attribute (com.apple.quarantine)..."
xattr -cr "$INSTALLED_PATH" || true
chmod -R +x "$INSTALLED_PATH/Contents/MacOS" || true

echo "=========================================================="
echo "Successfully installed and verified Droid Bridge!"
echo "You can now launch Droid Bridge from Applications or Spotlight."
echo "=========================================================="
