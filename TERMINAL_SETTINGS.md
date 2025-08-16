# Embedded Terminal Settings

## Overview
The embedded terminal now has comprehensive settings that can be configured per profile. These settings are accessible through the "Terminal Settings" tab in the profile detail view.

## Settings Categories

### 1. Theme Settings
- **Color Theme**: Choose from 7 built-in themes
  - Dark (default)
  - Light
  - Solarized Dark
  - Solarized Light
  - Dracula
  - Nord
  - One Dark
- **Theme Preview**: Live preview of selected theme with sample terminal output

### 2. Appearance Settings
- **Font Family**: Configurable terminal font (default: SF Mono)
- **Font Size**: Adjustable from 9-24pt (default: 13pt)
- **Cursor Style**: Block, Underline, or Bar
- **Cursor Blink**: Enable/disable cursor blinking
- **Bold Fonts**: Use bold font weights
- **Bright Colors**: Use bright colors for bold text

### 3. Behavior Settings
- **Scrollback Lines**: Number of lines to keep in history (default: 10000)
- **Mouse Reporting**: Enable mouse events in terminal applications
- **Copy on Select**: Automatically copy selected text
- **Paste on Middle Click**: Paste with middle mouse button
- **Bell Style**: None, Visual, Sound, or Both

### 4. Connection Settings
- **Auto Reconnect**: Automatically reconnect on disconnection
- **Reconnect Delay**: Seconds to wait before reconnecting (default: 5)
- **Keep Alive Interval**: Seconds between keep-alive packets (default: 60)
- **Commands on Connect**: List of commands to run after connection

### 5. Advanced Settings
- **Terminal Type**: Terminal emulation type (default: xterm-256color)
- **Locale**: Language and character encoding (default: en_US.UTF-8)
- **Sixel Graphics**: Enable sixel image protocol
- **OSC 52**: Enable clipboard integration

## How to Configure

1. Select a profile from the profile list
2. Click "Edit" button in the profile header
3. Navigate to "Terminal Settings" tab
4. Adjust settings as desired
5. Click "Save" to apply changes

## Settings Persistence

- Settings are stored per profile
- Each profile can have unique terminal settings
- Settings are saved automatically when editing
- New terminals use the current settings
- Existing terminals keep their settings until recreated

## Features

### Theme Preview
The theme selector includes a live preview showing:
- Command prompt with colors
- File and directory highlighting
- Error message colors
- Background and foreground colors

### Commands on Connect
You can specify commands to run automatically when a terminal connects:
1. Add commands in the "Commands on Connect" section
2. Commands run in order after SSH connection
3. Useful for setting environment variables or running initialization scripts

### Font Selection
- Enter font name directly
- "Select..." button opens system font picker (simplified version)
- Monospace fonts recommended for best results

## Default Settings

When creating a new profile, terminals use these defaults:
- Theme: Dark
- Font: SF Mono, 13pt
- Cursor: Block, with blink
- Scrollback: 10000 lines
- Mouse reporting: Enabled
- Auto-reconnect: Enabled
- Terminal type: xterm-256color

## Implementation Details

### Files Modified
1. **EmbeddedTerminalSettingsView.swift**: Complete settings UI
2. **ProfileDetailView.swift**: Added "Terminal Settings" tab
3. **EmbeddedTerminalView.swift**: Apply settings to terminals
4. **TerminalSettings.swift**: Extended settings model

### Settings Application
- Font and colors applied when terminal is created
- Environment variables set from terminal type and locale
- Commands run after connection established
- Some settings (like cursor style) may be limited by SwiftTerm API

## Limitations

Some settings are handled internally by SwiftTerm and may not be fully configurable:
- Exact cursor rendering style
- Scrollback buffer implementation
- Bell sound specifics
- Some ANSI escape sequences

## Future Enhancements

Potential improvements for terminal settings:
1. Custom theme creation and editing
2. Import/export themes
3. Per-session settings override
4. Keyboard shortcut customization
5. Tab color customization
6. Session recording settings
7. Search highlighting options
8. Word selection boundaries
9. URL detection patterns
10. Custom escape sequence handlers