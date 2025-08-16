# Terminal Tab Connection Fix

## Problem
When clicking the "+" button to create a new terminal tab, the session would show "Disconnected" with a reconnect modal. Clicking reconnect would then show "Connection Error: Terminal not initialized". The first tab always worked, but subsequent tabs failed.

## Root Cause
The issue occurred because:
1. Each `TerminalSession` needs its own `LocalProcessTerminalView` instance
2. When creating a new session via the "+" button, a new `TerminalContentView` was created but `setupTerminal()` wasn't being called properly for the new session
3. SwiftUI view lifecycle wasn't triggering `onAppear` when switching between sessions

## Solution Applied

### 1. Fixed Session-Terminal Binding
**File**: `EmbeddedTerminalView.swift`

Added session change detection:
```swift
.onChange(of: session.id) { _ in
    setupTerminal()
}
.id(session.id) // Force view recreation
```

### 2. Prevented Duplicate Terminal Creation
**File**: `EmbeddedTerminalView.swift` (setupTerminal method)

Added check to reuse existing terminal:
```swift
if session.terminal != nil {
    self.terminalView = session.terminal
    return
}
```

### 3. Fixed View Identity
**File**: `EmbeddedTerminalView.swift`

Added `.id()` modifiers to force proper view recreation:
```swift
TerminalContentView(session: selectedSession)
    .id(selectedSession.id) // Force recreation when session changes
```

## How It Works Now

1. **First Tab**: 
   - Creates session → Shows TerminalContentView → Calls setupTerminal() → Creates terminal → Connects

2. **Additional Tabs** (via "+" button):
   - Creates new session → Updates selectedSessionId → TerminalContentView recreates with new ID
   - onChange triggers → setupTerminal() called → New terminal created for new session → Connects

3. **Switching Tabs**:
   - Changes selectedSessionId → TerminalContentView updates → Reuses existing terminal for that session

## Testing
1. Open the app and create/select an SSH profile
2. Go to "Embedded Terminal" tab - first terminal connects
3. Click "+" to add a new tab - new terminal connects without error
4. Switch between tabs - each maintains its own session
5. Close tabs with X button - remaining tabs continue working

## Key Points
- Each session maintains its own `LocalProcessTerminalView` instance
- SwiftUI properly recreates views when session changes
- No "Terminal not initialized" errors on new tabs
- Sessions persist when switching between tabs