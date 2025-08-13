#!/bin/bash

# Build script for iTermGUI.app
# This creates a distributable macOS application bundle

set -e

cd "$(dirname "$0")/.."

echo "🔨 Building iTermGUI.app..."

# Create build directory if it doesn't exist
mkdir -p Build

# Clean previous builds
rm -rf Build/iTermGUI.app

# Build the Swift package in release mode
echo "📦 Compiling Swift code..."
swift build -c release

# Create app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p Build/iTermGUI.app/Contents/MacOS
mkdir -p Build/iTermGUI.app/Contents/Resources

# Copy the executable
echo "📋 Copying executable..."
# Try multiple possible locations
if [ -f ".build/arm64-apple-macosx/release/iTermGUI" ]; then
    cp .build/arm64-apple-macosx/release/iTermGUI Build/iTermGUI.app/Contents/MacOS/
elif [ -f ".build/x86_64-apple-macosx/release/iTermGUI" ]; then
    cp .build/x86_64-apple-macosx/release/iTermGUI Build/iTermGUI.app/Contents/MacOS/
elif [ -f ".build/release/iTermGUI" ]; then
    cp .build/release/iTermGUI Build/iTermGUI.app/Contents/MacOS/
else
    echo "❌ Error: Could not find built executable"
    exit 1
fi

# Copy Info.plist
echo "📋 Copying Info.plist..."
cp Resources/Info.plist Build/iTermGUI.app/Contents/

# Copy the app icon
echo "🎨 Copying app icon..."
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns Build/iTermGUI.app/Contents/Resources/
else
    echo "⚠️  Warning: AppIcon.icns not found in Resources/"
    echo "   Run ./Scripts/convert_icon.sh to generate it from icon.png"
fi

# Set executable permissions
chmod +x Build/iTermGUI.app/Contents/MacOS/iTermGUI

# Sign the app (ad-hoc signing for local distribution)
echo "✍️  Signing app..."
codesign --force --deep --sign - Build/iTermGUI.app

echo "✅ Build complete!"
echo ""
echo "The app is ready at: $(pwd)/Build/iTermGUI.app"
echo ""
echo "To install:"
echo "  1. Drag Build/iTermGUI.app to your Applications folder"
echo "  2. On first launch, you may need to right-click and select 'Open' to bypass Gatekeeper"
echo ""
echo "To create a DMG for distribution:"
echo "  ./Scripts/create_dmg.sh"