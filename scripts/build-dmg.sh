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
RW_DMG="$PROJECT_DIR/.build/DogSwitch-rw.dmg"
STAGING_DIR="$PROJECT_DIR/.build/dmg-staging"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/.background"
cp -R "$APP_DIR" "$STAGING_DIR/DogSwitch.app"
ln -s /Applications "$STAGING_DIR/Applications"
swift "$PROJECT_DIR/scripts/render-dmg-background.swift" "$STAGING_DIR/.background/background.png"

rm -f "$RW_DMG" "$DMG_PATH"
hdiutil create -volname "DogSwitch" -srcfolder "$STAGING_DIR" -ov -format UDRW "$RW_DMG" >/dev/null

# Detach stale mounts from previous runs so the volume name is predictable.
for v in /Volumes/DogSwitch*; do
    [ -e "$v" ] && hdiutil detach "$v" -quiet || true
done

MOUNT_POINT="$(hdiutil attach -readwrite -noverify "$RW_DMG" | tail -1 | awk '{print $NF}')"
trap 'hdiutil detach "$MOUNT_POINT" -quiet || true' EXIT
VOLUME_NAME="$(basename "$MOUNT_POINT")"

osascript - "$MOUNT_POINT" "$VOLUME_NAME" <<'APPLESCRIPT'
on run argv
    set mountPoint to item 1 of argv
    set volumeName to item 2 of argv
    tell application "Finder"
        tell disk volumeName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {400, 100, 940, 460}
            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 96
            set background picture of viewOptions to (POSIX file (mountPoint & "/.background/background.png")) as alias
            set position of item "DogSwitch.app" of container window to {140, 185}
            set position of item "Applications" of container window to {400, 185}
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
APPLESCRIPT

hdiutil detach "$MOUNT_POINT" -quiet
trap - EXIT

hdiutil convert "$RW_DMG" -format UDZO -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGING_DIR"
printf 'Built: %s\n' "$DMG_PATH"
