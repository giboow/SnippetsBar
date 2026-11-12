#!/bin/bash
# Builds SnippetsBar and creates SnippetsBar.app (menu bar app, no Dock icon).
set -euo pipefail
cd "$(dirname "$0")"

# Version: first argument, else the VERSION variable, else 0.0.0-dev.
VERSION="${1:-${VERSION:-0.0.0-dev}}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

# Universal binary (Apple Silicon + Intel).
SWIFT_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${SWIFT_FLAGS[@]}"

APP="SnippetsBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)/SnippetsBar" "$APP/Contents/MacOS/SnippetsBar"
cp -R Localization/*.lproj "$APP/Contents/Resources/"
# App icon (regenerate with scripts/generate-icon.sh): Assets.car for macOS 26+, .icns before.
cp Resources/Assets.car Resources/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SnippetsBar</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string><string>fr</string><string>es</string><string>it</string>
    <string>de</string><string>pt-BR</string><string>ja</string><string>zh-Hans</string>
  </array>
  <key>CFBundleDisplayName</key><string>SnippetsBar</string>
  <key>CFBundleIdentifier</key><string>local.snippetsbar</string>
  <key>CFBundleExecutable</key><string>SnippetsBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "✅ $APP $VERSION ($BUILD) created. Move it to /Applications and launch it."
