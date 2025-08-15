# iTermGUI

A powerful native macOS application for managing SSH profiles, connections, and file transfers through iTerm2.

## 🚀 Features

### SSH Profile Management
- **Comprehensive Profile System**: Create, edit, and organize SSH profiles with full configuration options
- **Group Organization**: Organize profiles into groups and folders for better management
- **Smart Search**: Real-time search and filtering across all profiles by name, host, username, or tags
- **Batch Operations**: Connect to multiple servers simultaneously in tabs or windows
- **Import/Export**: Import from `~/.ssh/config` and export profiles for backup
- **Favorites System**: Quick access to frequently used connections

### iTerm2 Integration
- **Seamless Connection**: Open SSH sessions directly in iTerm2
- **Window Modes**: Choose between tabs, new windows, or split panes
- **Dynamic Profiles**: Automatically syncs profiles with iTerm2
- **Custom Commands**: Configure startup commands and login scripts
- **Color Schemes**: Choose from iTerm2 color presets
- **Terminal Customization**: Font size, cursor styles, window dimensions

### SFTP File Transfer
- **Dual-Pane Interface**: Side-by-side local and remote file browsers
- **Multi-Protocol Support**: Transfer files between:
  - Local ↔ Local
  - Local ↔ Server
  - Server ↔ Server (via SSH tunneling)
- **Directory Support**: Transfer entire folders with preservation of structure
- **Context Menu Actions**: Right-click to transfer, delete, or refresh
- **Transfer Queue**: Monitor active, completed, and failed transfers with detailed error messages
- **Column Resizing**: Adjustable columns with visual guidelines to prevent flicker
- **Home Button**: Quick navigation back to the initial screen

### Advanced Features
- **SSH Key Management**: Support for multiple identity files and key-based authentication
- **Jump Host Support**: Configure proxy/bastion hosts for complex network topologies
- **Port Forwarding**: Set up local and remote port forwarding rules
- **Global Defaults**: Configure default settings for all profiles
- **Secure Storage**: Passwords stored securely in macOS Keychain
- **SSH Config Wildcards**: Smart handling of wildcard hosts from SSH config

## 📋 Requirements

- **macOS**: 13.0 (Ventura) or later
- **iTerm2**: Latest version recommended
- **Xcode Command Line Tools**: For building from source

## 📦 Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/StakeSquid/iTermGUI.git
cd iTermGUI

# Build the application
./Scripts/build_app.sh

# The app will be created at Build/iTermGUI.app
# Drag it to your Applications folder
```

### Option 2: Using Swift Package Manager

```bash
# Build using Swift Package Manager
swift build --configuration release

# Or open in Xcode
open Package.swift
```

### Option 3: Download Release

Download the latest DMG from the [releases page](https://github.com/StakeSquid/iTermGUI/releases):
1. Open the DMG file
2. Drag iTermGUI to your Applications folder
3. Launch from Applications

**Note:** On first launch, you may need to right-click and select "Open" to bypass macOS Gatekeeper.

## 🎯 Usage

### Quick Start
1. **Launch** iTermGUI from Applications
2. **Import existing profiles** from `~/.ssh/config` via File → Import
3. **Create a Profile**: Click "New Profile" or press ⌘+N
4. **Configure**: Enter host, username, and authentication details
5. **Connect**: Double-click the profile or click "Connect"

### Profile Management
- **Create Profile**: `⌘+N` or click "+" button
- **Edit Profile**: Select profile and click "Edit"
- **Delete Profile**: Right-click → Delete or press `Delete` key
- **Duplicate Profile**: Select profile and duplicate for templates
- **Group Profiles**: Organize profiles with tags and groups
- **Toggle Favorites**: Select profiles and mark as favorites

### SFTP File Transfer
1. **Open SFTP**: 
   - Click "SFTP" button on home screen (no profile required)
   - Or click "SFTP" in a profile view (opens with that server)
2. **Navigate**: Use the dual-pane interface to browse files
   - Left and right panes can each connect to localhost or any server
3. **Transfer Files**:
   - Use arrow buttons (→ ←) in the center
   - Right-click files/folders → Transfer
   - Select multiple items with ⌘+Click
4. **Monitor Transfers**: 
   - Check transfer queue at the bottom
   - Click info button on failed transfers to see error details
   - Error messages show exact paths and SSH errors

### Keyboard Shortcuts
- `⌘+N` - New Profile
- `⌘+K` - Quick Connect
- `⌘+F` - Focus Search
- `⌘+,` - Preferences
- `⌘+Delete` - Delete Selected Profiles
- `Return` - Connect to Selected Profile(s)
- `⌘+Click` - Multi-select Profiles
- `ESC` - Close SFTP Window

### Connection Modes
- **New Tab**: Opens in current iTerm2 window
- **New Window**: Creates a new iTerm2 window  
- **Split Horizontally**: Splits current pane horizontally
- **Split Vertically**: Splits current pane vertically

## 🛠 Configuration

### SSH Options
- **Host**: Server hostname or IP address
- **Port**: SSH port (default: 22)
- **Username**: SSH username
- **Authentication**: Password, SSH key, or keyboard-interactive
- **Identity File**: Path to private key
- **Jump Host**: Proxy/bastion host configuration
- **Certificate File**: For certificate-based authentication

### Terminal Settings
- **Colors**: Choose from iTerm2 color presets
- **Font Size**: Adjust terminal font size (10-24pt)
- **Cursor**: Block, underline, or bar styles
- **Window Size**: Set default columns and rows
- **Login Commands**: Custom commands to run on connection

### Global Settings
Located in `~/Documents/iTermGUI/`:
- `profiles.json` - All SSH profiles
- `groups.json` - Group organization
- `settings.json` - Application preferences
- `defaults.json` - Global default settings

**Note:** Files are automatically migrated from `~/Documents/` to `~/Documents/iTermGUI/` on first launch.

## 🔧 Advanced Features

### Server-to-Server Transfers
Transfer files directly between servers without downloading to your Mac:
1. Open SFTP window
2. Connect left pane to Server A
3. Connect right pane to Server B
4. Select files/folders and transfer directly
5. Data streams through your Mac via SSH tunnel (not saved locally)

### Handling SSH Config Wildcards
For SSH config entries with wildcards like:
```
Host rpc-br-*
    HostName %h.stakesquid.eu
    User root
    IdentityFile ~/.ssh/stakesquid
```
Just use the base hostname (e.g., `rpc-br-5`) to avoid domain duplication.

### Batch Operations
- Select multiple profiles with `⌘+Click`
- Connect to all simultaneously
- Choose tabs or separate windows
- Apply settings to multiple profiles at once

### Profile Templates
1. Set up a profile with common settings
2. Save as global defaults via Preferences
3. All new profiles inherit these settings
4. Apply defaults to existing profiles in bulk

## 🐛 Troubleshooting

### Common Issues

**"iTermGUI can't be opened because it is from an unidentified developer"**
- Right-click the app and select "Open"
- Or go to System Settings → Privacy & Security → "Open Anyway"

**SSH connection fails**
- Verify credentials and network connectivity
- Check SSH key permissions (should be 600)
- Ensure jump host configuration is correct
- For wildcard hosts, use base hostname only

**SFTP transfer fails**
- Check the error details in the transfer queue (click info button)
- Common issues:
  - File/folder doesn't exist: Verify paths
  - Permission denied: Check read/write permissions
  - Tilde expansion: Paths like `~/.ssh` are now properly handled
  - Directory transfers: Folders are now supported with recursive copying

**Profiles not syncing with iTerm2**
- Ensure iTerm2 is running
- Check Dynamic Profiles: `~/Library/Application Support/iTerm2/DynamicProfiles/`
- Restart iTerm2 if needed

### Debug Mode
Run from terminal to see debug output:
```bash
/Applications/iTermGUI.app/Contents/MacOS/iTermGUI
```

### Data Storage Locations
- **Profiles**: `~/Documents/iTermGUI/profiles.json`
- **Groups**: `~/Documents/iTermGUI/groups.json`  
- **Defaults**: `~/Documents/iTermGUI/defaults.json`
- **Passwords**: macOS Keychain (secure)
- **iTerm2 Profiles**: `~/Library/Application Support/iTerm2/DynamicProfiles/`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development

To run in development:
```bash
swift run
```

To run tests:
```bash
swift test
```

### Project Structure
```
iTermGUI/
├── Sources/iTermGUI/
│   ├── App/          # Application entry point
│   ├── Models/       # Data models (profiles, transfers)
│   ├── Services/     # iTerm2 and SFTP services
│   ├── ViewModels/   # Profile manager and state
│   └── Views/        # SwiftUI views
├── Resources/        # Icons and Info.plist
├── Scripts/          # Build scripts
├── Tests/            # Unit tests
└── Package.swift     # SPM configuration
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with SwiftUI for native macOS experience
- Integrates with [iTerm2](https://iterm2.com/) for terminal emulation
- Uses macOS Keychain for secure credential storage
- SSH tunneling for direct server-to-server transfers

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/StakeSquid/iTermGUI/issues)
- **Discussions**: [GitHub Discussions](https://github.com/StakeSquid/iTermGUI/discussions)

---

Made with ❤️ for the macOS community by [StakeSquid](https://github.com/StakeSquid)