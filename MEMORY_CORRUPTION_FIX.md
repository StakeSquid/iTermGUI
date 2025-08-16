# Terminal Tab Memory Corruption Fix

## Problem
When switching between terminal tabs, the application crashed with memory corruption errors:
- "corrupted size vs prev_size"
- "invalid pointer"

These are critical memory management errors that occur when memory is being accessed incorrectly.

## Root Cause
The issue was caused by attempting to reuse `LocalProcessTerminalView` instances across different SwiftUI view contexts. `LocalProcessTerminalView` is an NSView that:
- Manages its own process and PTY (pseudo-terminal)
- Has complex internal state and memory management
- Cannot be safely moved or shared between different view contexts

The previous implementation tried to:
1. Store the terminal view in the session
2. Reuse it when switching tabs
3. Move the NSView between different SwiftUI hosting contexts

This caused memory corruption because NSViews have specific lifecycle requirements and can't be arbitrarily moved around.

## Solution
Completely restructured the terminal view architecture to ensure proper memory management:

### 1. Removed Terminal View Reuse
- Each tab now creates its own isolated `LocalProcessTerminalView`
- Terminal views are never shared or moved between contexts
- Each view is properly managed by SwiftUI's lifecycle

### 2. New Architecture

#### Before (Problematic):
```
TerminalContentView (State-based)
    ├── Creates terminal once
    ├── Stores in session.terminal
    └── Tries to reuse when switching tabs ❌
```

#### After (Fixed):
```
TerminalContentView (Lightweight wrapper)
    └── TerminalHostingView (NSViewRepresentable)
        ├── Creates fresh terminal in makeNSView
        ├── Terminal lives within this context
        └── Properly cleaned up when view is destroyed ✅
```

### 3. Key Changes

**TerminalContentView**:
- Now a simple wrapper that creates `TerminalHostingView`
- Uses `@ObservedObject` for session state updates
- Handles overlay displays for errors/disconnections

**TerminalHostingView** (New):
- Proper `NSViewRepresentable` implementation
- Creates terminal in `makeNSView` (called once per view lifecycle)
- Handles all SSH connection logic directly
- Terminal is never stored or reused - it lives and dies with this view

**TerminalSession**:
- Removed complex terminal management
- Now just tracks connection state
- SSH profile made public for access by view

## Implementation Details

### File: `EmbeddedTerminalView.swift`

1. **Simplified TerminalContentView**:
   - Just creates a `TerminalHostingView` with unique ID
   - Handles error/disconnection overlays

2. **New TerminalHostingView**:
   - Creates `LocalProcessTerminalView` in `makeNSView`
   - Configures terminal appearance and options
   - Starts SSH connection directly
   - Properly manages terminal lifecycle

3. **Removed**:
   - `setupTerminal()` method
   - `TerminalViewWrapper` 
   - Terminal reuse logic

### File: `TerminalSession.swift`

1. **Made public**:
   - `sshProfile` property
   - `runInitialCommands()` method

2. **Removed**:
   - Complex connection logic (moved to view)
   - Terminal storage and management

## Benefits

1. **Memory Safety**: Each terminal view is properly isolated
2. **Proper Lifecycle**: Views are created and destroyed correctly
3. **No Corruption**: No attempts to move NSViews between contexts
4. **Cleaner Code**: Simpler, more maintainable architecture
5. **SwiftUI Compliant**: Follows SwiftUI/NSViewRepresentable best practices

## Testing
1. Open first terminal tab - connects properly ✅
2. Add new tab with "+" - new terminal created ✅
3. Switch between tabs - no memory corruption ✅
4. Close tabs - memory properly released ✅
5. Rapid tab switching - stable, no crashes ✅

## Key Lesson
NSViews (like `LocalProcessTerminalView`) must be created and managed within a single `NSViewRepresentable` context. They cannot be stored externally and reused across different SwiftUI view instances. Each SwiftUI view that needs an NSView should create its own instance.