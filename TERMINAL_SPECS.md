# Embedded Terminal Feature Specifications

## Overview
Implement a fully-featured embedded terminal within iTermGUI that allows users to establish SSH connections directly in the app interface, with persistent sessions across profile switches and comprehensive terminal emulation capabilities.

## Core Requirements

### 1. Terminal Integration
- **Location**: New tab in ProfileDetailView alongside existing tabs (Connection, Authentication, Advanced, Terminal Settings, Commands)
- **Tab Name**: "Embedded Terminal" with icon `terminal.fill`
- **Activation**: Terminal launches when tab is selected for a specific profile
- **Persistence**: Terminal sessions remain active when switching between profiles

### 2. Terminal Emulation Engine
- **Framework**: SwiftTerm (native Swift terminal emulator)
- **Protocol Support**: Full VT100/VT220/xterm-256color compatibility
- **PTY Management**: macOS native pseudo-terminal handling
- **Shell Integration**: SSH process spawning with proper TTY allocation

### 3. Tab Management System

#### Features:
- Multiple terminal tabs per profile
- Tab bar with visual indicators:
  - Active/inactive state
  - Connection status (connected/disconnected/connecting)
  - Profile name in tab
- Tab controls:
  - New tab button (+)
  - Close button (X) on each tab
  - Middle-click to close
  - Keyboard shortcuts (Cmd+T for new, Cmd+W to close)
- Drag & drop tab reordering
- Tab overflow handling with scrollable tab bar

#### Persistence:
- Tabs remain open when switching profiles
- Session restoration on app restart (optional)
- Background session management

### 4. Terminal Settings

#### Per-Profile Terminal Configuration:
```swift
struct EmbeddedTerminalSettings: Codable {
    // Visual Settings
    var theme: TerminalTheme
    var fontFamily: String = "SF Mono"
    var fontSize: CGFloat = 13
    var lineSpacing: CGFloat = 1.0
    var cursorStyle: CursorStyle = .block
    var cursorBlink: Bool = true
    var useBoldFonts: Bool = true
    var useBrightColors: Bool = true
    
    // Behavior Settings
    var scrollbackLines: Int = 10000
    var mouseReporting: Bool = true
    var altScreenMouseScroll: Bool = true
    var copyOnSelect: Bool = false
    var pasteOnMiddleClick: Bool = true
    var bellStyle: BellStyle = .visual
    
    // Connection Settings
    var onConnectCommands: [String] = []
    var keepAliveInterval: Int = 60
    var autoReconnect: Bool = true
    var reconnectDelay: Int = 5
    
    // Advanced Settings
    var terminalType: String = "xterm-256color"
    var locale: String = "en_US.UTF-8"
    var enableSixel: Bool = false
    var enableOSC52: Bool = true // Clipboard integration
}
```

#### Terminal Themes:
- Built-in themes: Dark, Light, Solarized Dark, Solarized Light, Dracula, Nord, One Dark
- Custom theme support with color palette editor
- Theme preview in settings

### 5. Resizing & Layout

#### Dynamic Resizing:
- Smooth terminal resizing without content loss
- SIGWINCH signal handling for remote applications
- Proper column/row calculation based on font metrics
- Responsive to window resizing
- Split view support (future enhancement)

#### Layout Constraints:
- Minimum terminal size: 80x24 characters
- Maximum based on window size
- Aspect ratio preservation option

### 6. Input/Output Features

#### Input Handling:
- Full keyboard mapping (including meta keys)
- Custom key bindings
- IME (Input Method Editor) support
- Paste bracketing mode
- Password input handling (no echo)

#### Output Processing:
- ANSI escape sequence parsing
- Unicode support (including emoji)
- Hyperlink detection and click handling
- Image protocol support (iTerm2 inline images)
- Search functionality (Cmd+F)

### 7. Mouse Support

#### Features:
- Mouse tracking modes (normal, button-event, any-event)
- Scroll wheel support
- Selection modes:
  - Character selection
  - Word selection (double-click)
  - Line selection (triple-click)
  - Block selection (Option+drag)
- Context menu on right-click

### 8. tmux Compatibility

#### Requirements:
- Proper terminal capabilities reporting
- Control sequence pass-through
- Title and status line support
- Mouse event forwarding
- Clipboard integration
- Window/pane aware operations

### 9. Session Management

#### Connection Handling:
- Automatic connection on tab creation
- Connection status indicators
- Reconnection logic with exponential backoff
- Clean disconnection handling
- Session logging (optional)

#### State Preservation:
- Scroll position retention
- Selection preservation
- Search state persistence
- Terminal mode tracking

### 10. Performance Optimizations

#### Rendering:
- Metal-accelerated rendering
- Dirty region tracking
- Frame rate limiting (60 FPS)
- Smooth scrolling with momentum

#### Memory Management:
- Scrollback buffer compression
- Inactive session hibernation
- Resource cleanup on tab close

## Architecture Design

### Component Structure:
```
Terminal/
├── Core/
│   ├── TerminalEmulator.swift      # Terminal emulation engine
│   ├── PTYManager.swift            # Pseudo-terminal management
│   ├── SSHSession.swift            # SSH connection handling
│   └── ANSIParser.swift            # ANSI escape sequence parser
├── Views/
│   ├── EmbeddedTerminalView.swift  # Main terminal view
│   ├── TerminalTabBar.swift        # Tab management UI
│   ├── TerminalCanvas.swift        # Rendering surface
│   └── TerminalSettingsView.swift  # Settings UI
├── Models/
│   ├── TerminalSession.swift       # Session data model
│   ├── TerminalTheme.swift         # Theme definitions
│   └── TerminalBuffer.swift        # Screen buffer management
└── Utils/
    ├── KeyMapper.swift              # Keyboard mapping
    ├── MouseHandler.swift           # Mouse event processing
    └── ClipboardManager.swift       # Clipboard integration
```

### Data Flow:
1. User selects "Embedded Terminal" tab
2. TerminalManager creates/retrieves session for profile
3. SSH connection established via PTYManager
4. Terminal emulator processes I/O stream
5. TerminalCanvas renders buffer content
6. User input forwarded to PTY

### State Management:
- TerminalSessionManager (singleton) maintains all active sessions
- Per-profile session dictionary
- Tab state persistence in UserDefaults
- Connection state machine per session

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Basic terminal emulator integration
- [ ] Single terminal view in ProfileDetailView
- [ ] SSH connection establishment
- [ ] Basic input/output handling

### Phase 2: Tab System (Week 2)
- [ ] Tab bar implementation
- [ ] Multiple sessions per profile
- [ ] Tab persistence across profile switches
- [ ] Tab controls (add, close, reorder)

### Phase 3: Terminal Features (Week 3)
- [ ] Resizing support
- [ ] Mouse handling
- [ ] Selection and copy/paste
- [ ] ANSI color support
- [ ] Settings UI

### Phase 4: Advanced Features (Week 4)
- [ ] Theme system
- [ ] tmux compatibility testing
- [ ] Reconnection logic
- [ ] Performance optimizations
- [ ] Search functionality

### Phase 5: Polish & Testing (Week 5)
- [ ] Bug fixes
- [ ] Performance tuning
- [ ] Documentation
- [ ] User testing

## Testing Strategy

### Unit Tests:
- ANSI parser correctness
- Key mapping accuracy
- Buffer management
- Session state transitions

### Integration Tests:
- SSH connection lifecycle
- Tab management operations
- Settings persistence
- Profile switching behavior

### Manual Testing:
- Interactive applications (vim, htop, etc.)
- tmux session management
- Terminal resizing during active sessions
- Network interruption handling
- Performance with large output

## Dependencies

### Required Packages:
- SwiftTerm or similar terminal emulator library
- AsyncSSH or libssh2 wrapper for SSH
- Compression library for scrollback

### System Requirements:
- macOS 12.0+ (for latest PTY APIs)
- Swift 5.7+
- SSH client binary or library

## Security Considerations

- Secure credential storage in Keychain
- No plain text password storage
- SSH key permission validation
- Session isolation between profiles
- Audit logging for connections

## Future Enhancements

1. **Split Panes**: Divide terminal into multiple panes
2. **Session Recording**: Record and replay terminal sessions
3. **Scripting**: AppleScript/JavaScript automation support
4. **Synchronization**: Sync sessions across devices
5. **AI Assistant**: Integrated command suggestions
6. **File Transfer**: Drag & drop file upload/download
7. **Snippet Manager**: Quick command insertion
8. **Session Sharing**: Collaborative terminal sessions
9. **Terminal Multiplexing**: Built-in tmux-like functionality
10. **Plugin System**: Extensibility for custom features

## Success Metrics

- Terminal renders correctly for common CLI tools
- < 50ms input latency
- Smooth scrolling at 60 FPS
- No memory leaks with long-running sessions
- tmux compatibility score > 95%
- User satisfaction with responsiveness

## Questions for Review

1. **Preference on terminal emulator library**: SwiftTerm vs custom implementation?
2. **Session persistence across app restarts**: Required or optional?
3. **Theme customization depth**: Preset themes only or full customization?
4. **Logging requirements**: Session recording needed?
5. **Multi-window support**: Allow terminal in separate windows?
6. **Performance targets**: Specific benchmarks to meet?
7. **Accessibility features**: Screen reader support priority?

## Next Steps

After review and approval of these specifications:
1. Set up development environment with chosen libraries
2. Create branch for terminal feature
3. Implement Phase 1 foundation
4. Weekly progress reviews and testing
5. Iterate based on feedback