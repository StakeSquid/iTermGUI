#!/bin/bash

# iTermGUI Build Script

set -e

echo "🔨 Building iTermGUI..."

# Clean previous builds
echo "Cleaning previous builds..."
swift package clean

# Build in release mode
echo "Building release version..."
swift build -c release

echo "✅ Build complete!"
echo ""
echo "To run the application:"
echo "  swift run iTermGUI"
echo ""
echo "To install to /Applications:"
echo "  sudo cp -r .build/release/iTermGUI /Applications/"
echo ""
echo "Build artifacts location: .build/release/"