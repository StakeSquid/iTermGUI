# iTermGUI

A native macOS application for managing SSH profiles with seamless iTerm2 integration.

<img width="1670" height="824" alt="Screenshot 2025-08-15 at 7 24 45 PM" src="https://github.com/user-attachments/assets/7a9c3caf-1236-4605-a69b-1aafd968ad9d" />

<img width="1312" height="712" alt="Screenshot 2025-08-15 at 7 24 19 PM" src="https://github.com/user-attachments/assets/a924181f-07ed-4e86-bb48-9672a82e4da4" />

## Features

### SSH Profile Management
- Create, edit, and organize SSH profiles with full configuration options
- Organize profiles into customizable, draggable groups
- Real-time search and filtering across all profiles
- Batch operations for connecting to multiple servers simultaneously
- Import from `~/.ssh/config` and export profiles for backup
- Favorites system for quick access to frequently used connections

### iTerm2 Integration
- Open SSH sessions directly in iTerm2
- Multiple connection modes: tabs, windows, or split panes
- Automatic profile syncing with iTerm2's dynamic profiles
- Custom startup commands and login scripts
- Terminal customization (fonts, colors, cursor styles)
- Quick localhost console access from the home screen

### SFTP File Transfer
- Dual-pane file browser interface
- Transfer files between local and remote systems
- Server-to-server transfers via SSH tunneling
- Directory transfer support with structure preservation
- Transfer queue with detailed error reporting
- Context menu actions for file operations

### Advanced Features
- SSH key management with multiple identity files
- Jump host support for complex network topologies
- Port forwarding configuration (local and remote)
- Global default settings for all profiles
- Secure password storage in macOS Keychain
- Embedded terminal view within the application

## System Requirements

- macOS 13.0 (Ventura) or later
- iTerm2 (latest version recommended)
- Xcode Command Line Tools (for building from source)

## Installation

### Download Release

Download the latest release from the [releases page](https://github.com/StakeSquid/iTermGUI/releases).

### Build from Source

```bash
# Clone the repository
git clone https://github.com/StakeSquid/iTermGUI.git
cd iTermGUI

# Build the application
./Scripts/build_app.sh

# The app will be created at Build/iTermGUI.app
# Drag it to your Applications folder
```

### Using Swift Package Manager

```bash
# Build using Swift Package Manager
swift build --configuration release

# Or open in Xcode
open Package.swift
```

## Usage

### Getting Started
1. Launch iTermGUI from Applications
2. Import existing profiles from `~/.ssh/config` via File → Import
3. Create new profiles with the "New Profile" button or ⌘+N
4. Double-click any profile to connect

### Profile Management
- **Create**: ⌘+N or click "+" button
- **Edit**: Select profile and click "Edit"
- **Delete**: Right-click → Delete or press Delete key
- **Group**: Drag groups in the sidebar to reorder them
- **Favorites**: Mark frequently used profiles as favorites

### SFTP File Transfer
1. Click "SFTP" from the home screen or profile view
2. Navigate using the dual-pane interface
3. Transfer files using the arrow buttons or right-click menu
4. Monitor transfers in the queue at the bottom

### Keyboard Shortcuts
- `⌘+N` - New Profile
- `⌘+K` - Quick Connect
- `⌘+F` - Focus Search
- `⌘+,` - Preferences
- `⌘+Delete` - Delete Selected Profiles
- `Return` - Connect to Selected Profile
- `⌘+Click` - Multi-select Profiles
- `ESC` - Close SFTP Window

## Configuration

### SSH Options
- Host (hostname or IP address)
- Port (default: 22)
- Username
- Authentication method (password, SSH key, keyboard-interactive)
- Identity file path
- Jump host configuration
- Port forwarding rules

### Terminal Settings
- Color schemes
- Font family and size
- Cursor style
- Window dimensions
- Startup commands

### Data Storage
Configuration files are stored in `~/Documents/iTermGUI/`:
- `profiles.json` - SSH profiles
- `groups.json` - Group organization
- `settings.json` - Application preferences
- `defaults.json` - Global default settings

Passwords are securely stored in the macOS Keychain.

## Troubleshooting

### Common Issues

**"iTermGUI can't be opened because it is from an unidentified developer"**
- Right-click the app and select "Open"
- Or go to System Settings → Privacy & Security → "Open Anyway"

**SSH connection fails**
- Verify credentials and network connectivity
- Check SSH key permissions (should be 600)
- Ensure jump host configuration is correct

**SFTP transfer fails**
- Check error details in the transfer queue
- Verify file paths and permissions
- Ensure sufficient disk space

**Profiles not syncing with iTerm2**
- Ensure iTerm2 is running
- Check `~/Library/Application Support/iTerm2/DynamicProfiles/`
- Restart iTerm2 if needed

### Debug Mode
Run from terminal to see debug output:
```bash
/Applications/iTermGUI.app/Contents/MacOS/iTermGUI
```

## Development

### Project Structure
```
iTermGUI/
├── Sources/iTermGUI/
│   ├── App/          # Application entry point
│   ├── Models/       # Data models
│   ├── Services/     # iTerm2 and SFTP services
│   ├── ViewModels/   # Profile manager
│   ├── Views/        # SwiftUI views
│   └── Terminal/     # Embedded terminal components
├── Resources/        # Icons and Info.plist
├── Scripts/          # Build scripts
├── Tests/            # Unit tests
└── Package.swift     # SPM configuration
```

### Building
```bash
# Development build
swift run

# Production build
swift build --configuration release

# Run tests
swift test
```

## Contributing

Contributions are welcome. Please submit issues and pull requests on GitHub.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- [GitHub Issues](https://github.com/StakeSquid/iTermGUI/issues)
- [GitHub Discussions](https://github.com/StakeSquid/iTermGUI/discussions)

---

Made for the macOS community by [StakeSquid](https://github.com/StakeSquid)