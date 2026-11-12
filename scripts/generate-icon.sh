#!/bin/bash
# Regenerates the app icon from QuoteGlyph (Sources/SnippetsBar/UI/AppIcon.swift):
#   Resources/AppIcon.icon/Assets/glyph.png   glyph layer of the Icon Composer icon
#   Resources/Assets.car                      compiled icon for macOS 26+ (native shape and glass)
#   Resources/AppIcon.icns                    compiled icon for earlier macOS versions
# Needs Xcode 26 or later (actool with Icon Composer support). The outputs are committed,
# so building the app (build-app.sh, CI) doesn't need this script.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/main.swift" <<'EOF'
import AppKit
import SwiftUI

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: QuoteGlyph(size: 1024))
    guard let image = renderer.cgImage else { fatalError("rendering failed") }
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
EOF

swiftc -o "$TMP/render" Sources/SnippetsBar/UI/AppIcon.swift "$TMP/main.swift"
"$TMP/render" Resources/AppIcon.icon/Assets/glyph.png

xcrun actool "$PWD/Resources/AppIcon.icon" --compile "$TMP" --platform macosx \
    --minimum-deployment-target 13.0 --app-icon AppIcon \
    --output-partial-info-plist "$TMP/partial.plist" > /dev/null
cp "$TMP/Assets.car" "$TMP/AppIcon.icns" Resources/
echo "✅ Resources/AppIcon.icon, Resources/Assets.car, Resources/AppIcon.icns"
