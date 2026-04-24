# iTermGUI

A native macOS app for managing SSH profiles and launching them in iTerm2 — with an embedded terminal and SFTP file transfer for when you don't need iTerm2 at all.

[![Latest release](https://img.shields.io/github/v/release/StakeSquid/iTermGUI?display_name=tag&sort=semver)](https://github.com/StakeSquid/iTermGUI/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Highlights

- **SSH profile manager** — host, port, user, jump host, proxy command, identity file, port forwarding, custom startup commands, tags, and per-profile terminal settings.
- **iTerm2 integration** — opens connections in iTerm2 tabs or separate windows, syncing each profile to iTerm2's Dynamic Profiles directory.
- **Embedded terminal** — built-in SwiftTerm session per profile with seven themes (Dark, Light, Solarized Dark/Light, Dracula, Nord, One Dark) when you don't want to leave the app.
- **SFTP file transfer** — dual-pane browser, server-to-server transfers via SSH tunneling, recursive directory transfers, queued progress.
- **Organization** — Smart groups (All / Favorites / Recent), custom drag-to-reorder groups, tags, and search across name / host / username / tags.
- **Quick Connect** — menu bar dropdown for launching favorites or recent profiles in one click.
- **Secure** — passwords stored in the macOS Keychain; everything else lives in plain JSON you can back up or version-control.

## Requirements

- macOS 13 (Ventura) or later
- [iTerm2](https://iterm2.com) for external terminal sessions (the embedded terminal works without it)

## Install

### Pre-built app

1. Download `iTermGUI-vX.Y.Z.zip` from the [latest release](https://github.com/StakeSquid/iTermGUI/releases/latest).
2. Unzip and drag **iTermGUI.app** to **/Applications**.
3. First launch: right-click the app → **Open** to bypass Gatekeeper (the app is ad-hoc signed).

### Build from source

```bash
git clone https://github.com/StakeSquid/iTermGUI.git
cd iTermGUI
./Scripts/build_app.sh        # produces Build/iTermGUI.app
./Scripts/create_dmg.sh       # optional: package as a .dmg
```

Or run directly via Swift Package Manager:

```bash
swift run                     # debug
swift build -c release        # release binary at .build/release/iTermGUI
```

## Quick start

1. Launch iTermGUI.
2. Either click **Import** on the welcome screen to read existing entries from `~/.ssh/config`, or **New Profile** (`⌘N`) to create one.
3. Double-click a profile (or hit `↩` on the selection) to open it in iTerm2.

Multi-select profiles and pick **Connect → Tabs / Separate Windows** from the toolbar to launch many at once.

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘N` | New profile |
| `⌘⇧I` | Import from `~/.ssh/config` |
| `⌘⇧E` | Export profiles |
| `⌘↩` | Connect to selected profile |
| `⌘,` | Settings |
| `↩` | Connect to selection / submit form |
| `Esc` | Cancel popover or sheet |
| `Delete` | Remove selected profile(s) |

## Where things live

| Path | Contents |
|------|----------|
| `~/Documents/iTermGUI/profiles.json` | All SSH profiles |
| `~/Documents/iTermGUI/groups.json` | Custom groups and ordering |
| `~/Documents/iTermGUI/defaults.json` | Global default settings applied to new profiles |
| `~/Library/Application Support/iTerm2/DynamicProfiles/` | iTerm2-side profile mirror managed by the app |
| macOS Keychain | Profile passwords (entry per profile) |

## Project layout

```
Sources/iTermGUI/
├── App/                Application entry point and AppDelegate
├── Extensions/         Shared SwiftUI helpers (ProfileAvatar, glass effects)
├── Models/             SSHProfile, ProfileGroup, GlobalDefaults, terminal settings
├── Services/           ITerm2Service, SFTPService, ProfileStorage, SSHConfigParser
│   └── Runners/        AppleScript / Process / Keychain / file-store protocols
├── Terminal/           SwiftTerm-based embedded session (Models, Views, Core)
├── ViewModels/         ProfileManager (the app's central @ObservableObject)
└── Views/              SwiftUI views (sidebar, list, detail, settings, SFTP, quick connect)

Tests/iTermGUITests/    379 tests across Models / ViewModels / Services / Terminal / Views
```

## Development

```bash
swift test                                      # full suite
swift test --parallel --enable-code-coverage    # what CI runs
swift build -c release                          # release binary
```

The codebase uses dependency-injected services (`ProfileFileStore`, `AppleScriptRunner`, `ProcessRunner`, `KeychainStore`) so most logic can be unit-tested without touching iTerm2, the filesystem, or the real Keychain. See `Tests/iTermGUITests/Support/` for the in-memory fakes and fixtures.

## Troubleshooting

**App won't open ("unidentified developer")** — right-click the app → **Open**, or System Settings → Privacy & Security → **Open Anyway**.

**Profile doesn't show up in iTerm2** — make sure iTerm2 is running, then check `~/Library/Application Support/iTerm2/DynamicProfiles/` for a JSON file named after the profile. Restart iTerm2 if you don't see it pick up changes.

**SSH key auth fails** — keys must be `chmod 600`. iTermGUI shells out to the system `ssh`, so anything `ssh -i` accepts in your terminal will work here.

**Verbose logging** — run the binary directly:
```bash
/Applications/iTermGUI.app/Contents/MacOS/iTermGUI
```

## Contributing

Issues and PRs welcome at [github.com/StakeSquid/iTermGUI](https://github.com/StakeSquid/iTermGUI). Please run `swift test` before opening a PR — CI runs the same suite with code coverage.

## License

MIT — see [LICENSE](LICENSE).
