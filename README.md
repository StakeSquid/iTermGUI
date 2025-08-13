# iTermGUI

A powerful native macOS application for managing SSH profiles with seamless iTerm2 integration.

## Features

### Profile Management
- 🚀 **Quick SSH Connections** - Connect to servers with one click
- 📁 **Import/Export** - Import from ~/.ssh/config, export to various formats
- 🔐 **Secure Storage** - Passwords stored securely in macOS Keychain
- 📋 **Multi-Selection** - Connect to multiple servers in tabs or windows
- 🏷️ **Tag Organization** - Organize profiles with custom tags
- ⭐ **Favorites** - Mark frequently used profiles as favorites
- 🔍 **Smart Search** - Search by name, host, username, or tags
- 📊 **Flexible Sorting** - Sort by name, host, last used, creation date, or favorites

### Connection Features
- 🎨 **iTerm2 Integration** - Creates dynamic iTerm2 profiles automatically
- 🔗 **Jump Hosts** - Configure ProxyJump for bastion hosts
- 🚇 **Port Forwarding** - Local and remote port forwarding support
- 🔑 **Multiple Auth Methods** - Public key, password, keyboard-interactive, certificate
- ⚙️ **Advanced Options** - Compression, timeouts, keep-alive, strict host checking
- 📝 **Custom Commands** - Run commands automatically on connection
- ♻️ **Command Management** - Add, delete, and reorder commands with drag & drop

### Global Settings
- 🎯 **Default Settings** - Configure global defaults for new profiles
- 🔄 **Bulk Updates** - Apply default settings to all existing profiles
- 💾 **Profile Templates** - Save any profile's settings as new defaults
- 🖥️ **Terminal Customization** - Default color schemes, fonts, cursor styles
- ⏱️ **Connection Defaults** - Default timeouts, compression, and security settings

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

### Getting Started

1. **Launch iTermGUI** from your Applications folder
2. **Import existing profiles** from ~/.ssh/config via File → Import
3. **Create new profiles** using the + button in the toolbar

### Managing Profiles

#### Creating Profiles
- Click the **+** button to create a new profile
- New profiles automatically inherit your global default settings
- Configure connection details, authentication, and terminal preferences

#### Organizing Profiles
- **Search**: Use the search bar to filter profiles by name, host, username, or tags
- **Sort**: Click the sort dropdown to organize by name, host, recent usage, or favorites
- **Tags**: Add custom tags to categorize your servers (e.g., "production", "staging", "personal")
- **Groups**: Profiles are automatically grouped (All, Favorites, Recent)

#### Connecting to Servers
- **Single Connection**: Double-click a profile or select and press Enter
- **Multiple Connections**: 
  - Use Cmd+Click to select multiple profiles
  - Choose "Connect in Tabs" or "Connect in Windows" from the toolbar
- **Quick Connect**: Use the context menu (right-click) for quick actions

### Advanced Features

#### SSH Config Wildcards
If you have SSH config entries with wildcards like:
```
Host rpc-br-*
    HostName %h.stakesquid.eu
    User root
    IdentityFile ~/.ssh/stakesquid
```
Just use the base hostname (e.g., `rpc-br-5`) in your profile to avoid domain duplication.

#### Global Defaults
1. Go to **Preferences → Defaults**
2. Configure your preferred terminal and connection settings
3. Click **"Apply Defaults to All Profiles"** to update existing profiles
4. All new profiles will use these settings automatically

#### Command Execution
- Add commands to run automatically after connection
- Drag to reorder commands for specific execution order
- Select multiple commands and delete in bulk
- Commands are executed in the order shown

#### Port Forwarding
Configure local and remote port forwarding in the Advanced tab:
- **Local Forward**: Access remote services through local ports
- **Remote Forward**: Expose local services to the remote server

### Keyboard Shortcuts
- **⌘N** - New profile
- **⌘,** - Preferences
- **⌘F** - Focus search
- **⌘⌫** - Delete selected profiles
- **⏎** - Connect to selected profile(s)
- **⌘Click** - Multi-select profiles

## Development

The project is built with:
- SwiftUI for the native macOS interface
- Swift Package Manager for dependency management
- iTerm2's Dynamic Profiles API for terminal integration

To run in development mode:
```bash
swift run
```

To run tests:
```bash
swift test
```

## Troubleshooting

### Common Issues

#### "iTermGUI can't be opened because it is from an unidentified developer"
- Right-click the app and select "Open" to bypass Gatekeeper
- Or go to System Preferences → Security & Privacy and click "Open Anyway"

#### SSH connection fails with "Could not resolve hostname"
- Check if you have SSH config wildcards that might be causing hostname duplication
- Verify the hostname is correct and doesn't include duplicate domains
- For wildcard configs, use just the base hostname without the domain suffix

#### Profiles not saving
- Ensure iTermGUI has permission to write to ~/Documents
- Check System Preferences → Security & Privacy → Files and Folders

#### iTerm2 doesn't open when connecting
- Verify iTerm2 is installed in /Applications
- Check that iTerm2's AppleScript support is enabled
- Try launching iTerm2 manually first, then using iTermGUI

### Data Storage

iTermGUI stores data in the following locations:
- **Profiles**: `~/Documents/iTermGUI/profiles.json`
- **Groups**: `~/Documents/iTermGUI/groups.json`
- **Global Defaults**: `~/Documents/iTermGUI/defaults.json`
- **Passwords**: macOS Keychain (secure)
- **Dynamic Profiles**: `~/Library/Application Support/iTerm2/DynamicProfiles/`

Note: If you have existing files from an older version in `~/Documents`, they will be automatically migrated to `~/Documents/iTermGUI/` on first launch.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT