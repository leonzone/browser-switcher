#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_DIR="$PROJECT_DIR/dist/DogSwitch.app"
if [ ! -d "$APP_DIR" ]; then
    echo "DogSwitch.app not found, building first..."
    bash "$PROJECT_DIR/scripts/build-app.sh"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
DMG_PATH="$PROJECT_DIR/dist/DogSwitch-$VERSION.dmg"
STAGING_DIR="$PROJECT_DIR/.build/dmg-staging"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/DogSwitch.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "DogSwitch" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"
printf 'Built: %s\n' "$DMG_PATH"
