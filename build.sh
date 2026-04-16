#!/bin/bash
set -euo pipefail

APP_NAME="HoduPomodoro"

echo "🍊 Building $APP_NAME..."
swift build -c release

echo "📦 Assembling .app bundle..."
rm -rf "$APP_NAME.app"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

cp ".build/release/$APP_NAME" "$APP_NAME.app/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_NAME.app/Contents/Info.plist"

# Optional icon copy (if present)
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP_NAME.app/Contents/Resources/"
fi

chmod +x "$APP_NAME.app/Contents/MacOS/$APP_NAME"

echo "✅ Built $APP_NAME.app"
echo "   Run with: open $APP_NAME.app"
