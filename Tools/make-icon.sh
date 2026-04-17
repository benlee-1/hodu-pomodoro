#!/bin/bash
# Generates Resources/AppIcon.icns from the Hodu sprite.
# Requires: swift, sips, iconutil (all bundled with macOS + Xcode CLT).
set -euo pipefail

cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
SRC_PNG="build/icon-1024.png"

mkdir -p build
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "🎨 Rendering 1024×1024 icon..."
swift Tools/GenerateIcon.swift "$SRC_PNG"

echo "🔁 Downscaling to icon-set sizes..."
sips -z 16   16   "$SRC_PNG" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32   32   "$SRC_PNG" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32   32   "$SRC_PNG" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64   64   "$SRC_PNG" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128  128  "$SRC_PNG" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256  256  "$SRC_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256  256  "$SRC_PNG" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512  512  "$SRC_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512  512  "$SRC_PNG" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$SRC_PNG" "$ICONSET/icon_512x512@2x.png"

echo "📦 Packing .icns..."
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

echo "✅ Resources/AppIcon.icns"
