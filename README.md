# iTermGUI

A native macOS application for managing SSH profiles with iTerm2 integration.

## Features

- 🚀 Quick SSH connection management
- 📁 Import from ~/.ssh/config
- 🔐 Secure password storage in macOS Keychain
- 🎨 iTerm2 Dynamic Profiles integration
- 📋 Multi-selection support for batch connections
- 🏷️ Tag-based organization
- ⭐ Favorite profiles for quick access

## Installation

### Option 1: Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/iTermGUI.git
cd iTermGUI
```

2. Build the application:
```bash
./Scripts/build_app.sh
```

3. The app will be created at `Build/iTermGUI.app`. Drag it to your Applications folder.

### Option 2: Download Release

Download the latest DMG from the releases page and:
1. Open the DMG file
2. Drag iTermGUI to your Applications folder
3. Launch from Applications

**Note:** On first launch, you may need to right-click and select "Open" to bypass macOS Gatekeeper.

## Building for Distribution

To create a distributable DMG:
```bash
./Scripts/create_dmg.sh
```

This will create `iTermGUI-1.0.0.dmg` that users can download and install.

## Project Structure

```
iTermGUI/
├── Build/                  # Build artifacts (app bundles, DMGs)
│   └── iTermGUI.app       # The built application
├── Resources/             # App resources
│   ├── icon.png          # Original icon
│   ├── AppIcon.icns      # macOS icon format
│   └── Info.plist        # App configuration
├── Scripts/              # Build and utility scripts
│   ├── build_app.sh      # Build the .app bundle
│   ├── convert_icon.sh   # Convert PNG to ICNS
│   └── create_dmg.sh     # Create DMG installer
├── Sources/              # Swift source code
│   └── iTermGUI/
│       ├── App/          # Application entry point
│       ├── Models/       # Data models
│       ├── Services/     # iTerm2 and SSH services
│       ├── ViewModels/   # View models and state
│       └── Views/        # SwiftUI views
├── Tests/                # Test files
├── Package.swift         # Swift Package Manager config
└── .gitignore           # Git ignore patterns
```

## Requirements

- macOS 13.0 or later
- iTerm2 installed
- Xcode Command Line Tools (for building from source)

## Usage

1. Launch iTermGUI from your Applications folder
2. Import existing SSH profiles from ~/.ssh/config or create new ones
3. Select one or multiple profiles and connect
4. Use Cmd+Click for multi-selection
5. Right-click for context menu options

## Development

The project is built with:
- SwiftUI for the native macOS interface
- Swift Package Manager for dependency management
- iTerm2's Dynamic Profiles API for terminal integration

To run in development mode:
```bash
swift run
```

## License

MIT