#!/bin/bash

# Convert PNG icon to ICNS format for macOS app

set -e

cd "$(dirname "$0")/.."

if [ ! -f "Resources/icon.png" ]; then
    echo "❌ Error: Resources/icon.png not found"
    exit 1
fi

echo "🎨 Converting icon.png to AppIcon.icns..."

# Create Resources directory if it doesn't exist
mkdir -p Resources

# Create iconset directory
mkdir -p AppIcon.iconset

# Generate different sizes required for macOS icons
sips -z 16 16     Resources/icon.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     Resources/icon.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     Resources/icon.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     Resources/icon.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   Resources/icon.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   Resources/icon.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   Resources/icon.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   Resources/icon.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   Resources/icon.png --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 Resources/icon.png --out AppIcon.iconset/icon_512x512@2x.png

# Convert iconset to icns
iconutil -c icns AppIcon.iconset -o Resources/AppIcon.icns

# Clean up temporary iconset
rm -rf AppIcon.iconset

echo "✅ Icon converted successfully to Resources/AppIcon.icns"