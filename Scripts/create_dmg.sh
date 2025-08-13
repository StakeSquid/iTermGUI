#!/bin/bash

# Create a DMG installer for iTermGUI
# This creates a distributable disk image with the app

set -e

cd "$(dirname "$0")/.."

APP_NAME="iTermGUI"
DMG_NAME="iTermGUI-1.0.0.dmg"
VOLUME_NAME="iTermGUI Installer"

echo "📀 Creating DMG installer..."

# First build the app if it doesn't exist
if [ ! -d "Build/${APP_NAME}.app" ]; then
    echo "App not found, building first..."
    ./Scripts/build_app.sh
fi

# Clean up any existing DMG
rm -f "${DMG_NAME}"
rm -rf dmg_temp

# Create temporary directory for DMG contents
mkdir dmg_temp

# Copy app to temporary directory
cp -R "Build/${APP_NAME}.app" dmg_temp/

# Create a symbolic link to Applications folder
ln -s /Applications dmg_temp/Applications

# Create the DMG
echo "🔨 Building DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder dmg_temp \
    -ov -format UDZO \
    "${DMG_NAME}"

# Clean up
rm -rf dmg_temp

echo "✅ DMG created successfully!"
echo ""
echo "The installer is ready at: $(pwd)/${DMG_NAME}"
echo ""
echo "Users can:"
echo "  1. Double-click the DMG to mount it"
echo "  2. Drag iTermGUI to the Applications folder"
echo "  3. Eject the DMG"
echo "  4. Launch iTermGUI from Applications"