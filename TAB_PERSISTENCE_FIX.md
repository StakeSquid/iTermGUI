# Terminal Tab Persistence Fix

## Problem
When switching between terminal tabs, the previously active terminal would turn into a blinking cursor with no content displayed, and the terminal would become unresponsive. Both the old and new tabs would stop working.

## Root Cause
The issue was caused by SwiftUI recreating the `TerminalHostingView` when switching tabs due to the `.id()` modifier. This would:
1. Destroy the existing terminal view and its SSH process
2. Create a new terminal view 
3. Lose all terminal content and state
4. Leave the SSH process orphaned

## Solution
Changed the architecture to keep all terminal views alive simultaneously, using opacity to show/hide them instead of recreating them.

### Key Changes

#### 1. Keep All Terminal Views Alive
**File**: `EmbeddedTerminalView.swift`

Changed from conditional rendering to simultaneous rendering with opacity:

**Before:**
```swift
if let selectedSession = sessions.first(where: { $0.id == selectedSessionId }) {
    TerminalContentView(session: selectedSession)
        .id(selectedSession.id) // This caused recreation!
}
```

**After:**
```swift
ZStack {
    ForEach(sessions) { session in
        TerminalContentView(session: session)
            .opacity(session.id == selectedSessionId ? 1 : 0)
            .allowsHitTesting(session.id == selectedSessionId)
    }
}
```

#### 2. Remove View Recreation Triggers
- Removed `.id(sessionId)` from `TerminalContentView`
- Terminal views now persist for the lifetime of their session

#### 3. Simplified Connection Logic
**File**: `TerminalSession.swift`
- Removed `establishSSHConnection()` method
- Connection now handled entirely by `TerminalHostingView`
- `connect()` method kept for API compatibility but does nothing

## How It Works Now

### Tab Creation
1. New session created → Added to sessions array
2. `TerminalContentView` created for the session
3. `TerminalHostingView` creates `LocalProcessTerminalView` once
4. SSH connection established
5. Terminal view stays alive until session is closed

### Tab Switching
1. User clicks different tab → `selectedSessionId` changes
2. Previous tab: `opacity(0)` and `allowsHitTesting(false)`
3. New tab: `opacity(1)` and `allowsHitTesting(true)`
4. Both terminals remain alive and connected
5. Only the visible terminal receives input

### Benefits
- **No Recreation**: Terminal views persist across tab switches
- **State Preservation**: Terminal content, scroll position, and SSH connection maintained
- **Performance**: No overhead of destroying/creating views
- **Stability**: No orphaned processes or memory issues

## Memory Considerations
Since all terminal views remain in memory:
- Each terminal uses ~5-10MB of RAM
- Reasonable for typical usage (5-10 tabs)
- Sessions are properly cleaned up when tabs are closed

## Testing Checklist
- [x] Create first terminal tab - connects properly
- [x] Add additional tabs - each gets its own connection
- [x] Switch between tabs - content preserved
- [x] Type in one tab, switch to another, switch back - input preserved
- [x] Close tabs - memory properly released
- [x] Rapid tab switching - no crashes or content loss

## Architecture Summary
```
EmbeddedTerminalView
├── TerminalTabBar (visible, interactive)
└── ZStack (all terminals rendered)
    ├── TerminalContentView (Session 1) - opacity: 1 (selected)
    ├── TerminalContentView (Session 2) - opacity: 0
    └── TerminalContentView (Session 3) - opacity: 0
```

Each `TerminalContentView` maintains its own:
- `TerminalHostingView` (NSViewRepresentable)
- `LocalProcessTerminalView` (actual terminal)
- SSH process and connection
- Terminal state and content

This ensures complete isolation and persistence of each terminal session.