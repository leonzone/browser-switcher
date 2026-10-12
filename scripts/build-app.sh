#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
swift build -c release --product BrowserSwitcher
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/DogSwitch.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/BrowserSwitcher" "$APP_DIR/Contents/MacOS/BrowserSwitcher"
ICONSET_DIR="$PROJECT_DIR/.build/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$PROJECT_DIR/Assets/AppIcon-source.png" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE_SIZE=$((SIZE * 2))
    sips -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$PROJECT_DIR/Assets/AppIcon-source.png" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
if command -v pngquant >/dev/null 2>&1; then
    for PNG in "$ICONSET_DIR"/*.png; do
        pngquant --quality=85-100 --speed 1 --force --output "$PNG" "$PNG" || true
    done
else
    echo "note: pngquant not found, icons left unoptimized (brew install pngquant)"
fi
swift "$PROJECT_DIR/scripts/build-icns.swift" "$APP_DIR/Contents/Resources/AppIcon.icns" "$ICONSET_DIR"
sips -z 18 18 "$PROJECT_DIR/Assets/StatusIcon-source.png" --out "$APP_DIR/Contents/Resources/StatusIconTemplate.png" >/dev/null
sips -z 36 36 "$PROJECT_DIR/Assets/StatusIcon-source.png" --out "$APP_DIR/Contents/Resources/StatusIconTemplate@2x.png" >/dev/null
if command -v pngquant >/dev/null 2>&1; then
    for PNG in "$APP_DIR/Contents/Resources/StatusIconTemplate.png" "$APP_DIR/Contents/Resources/StatusIconTemplate@2x.png"; do
        pngquant --quality=85-100 --speed 1 --force --output "$PNG" "$PNG" || true
    done
fi
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>BrowserSwitcher</string>
    <key>CFBundleIdentifier</key><string>io.reiserxu.BrowserSwitcher</string>
    <key>CFBundleName</key><string>DogSwitch</string>
    <key>CFBundleDisplayName</key><string>DogSwitch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
plutil -lint "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
