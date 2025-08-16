# Copy and Paste Features for Embedded Terminal

## Features Implemented

### 1. Copy on Select
- **Location**: Terminal Settings → Behavior → Copy on Select
- **How it works**: When enabled, text is automatically copied to clipboard when you select it with the mouse
- **Implementation**: Uses `selectionChanged` callback to detect selection changes and copies text to pasteboard

### 2. Paste on Right Click
- **Location**: Terminal Settings → Behavior → Paste on Right Click  
- **How it works**: When enabled, right-clicking pastes clipboard contents directly into terminal
- **Alternative**: When disabled, right-click shows a context menu with copy/paste options

### 3. Paste on Middle Click (existing)
- **Location**: Terminal Settings → Behavior → Paste on Middle Click
- **How it works**: Middle mouse button pastes clipboard contents (already existed, still works)

## Context Menu
When "Paste on Right Click" is disabled, right-clicking shows a menu with:
- Copy (Cmd+C)
- Paste (Cmd+V)
- Select All (Cmd+A)
- Clear (Cmd+K) - Clears terminal screen

## Technical Implementation

### CustomTerminalView
- Extends `LocalProcessTerminalView` from SwiftTerm
- Overrides `selectionChanged` to handle copy on select
- Overrides `rightMouseDown` to handle paste on right-click
- Provides custom context menu when right-click paste is disabled

### Settings Persistence
- Settings stored in `EmbeddedTerminalSettings`
- Saved to `~/Documents/iTermGUI/profiles.json`
- Loaded on app startup
- Applied to each terminal when created

## Usage

1. **Enable Copy on Select**:
   - Go to Terminal Settings tab
   - Check "Copy on Select" 
   - Click Edit → Save
   - Now selecting text automatically copies it

2. **Configure Right Click**:
   - Go to Terminal Settings tab
   - Check "Paste on Right Click" for direct paste
   - Uncheck for context menu
   - Click Edit → Save

3. **Keyboard Shortcuts** (always work):
   - Cmd+C: Copy selected text
   - Cmd+V: Paste from clipboard
   - Cmd+A: Select all text

## Testing
1. Open embedded terminal
2. Run some commands to generate text
3. Select text with mouse - should auto-copy if enabled
4. Right-click - should paste or show menu based on setting
5. Try Cmd+C/Cmd+V for manual copy/paste