# Terminal Persistence - Final Solution

## The Core Problem
The terminal views were being destroyed when switching profiles because:
1. `ContentView` had `.id(profile.id)` which forced complete view recreation
2. This destroyed the entire `ProfileDetailView` and all its children
3. Any terminal views inside were destroyed, killing SSH processes

## The Solution

### 1. Removed Forced Recreation
**File: ContentView.swift**
- Removed `.id(profile.id)` from ProfileDetailView
- Now the view updates internally instead of being recreated

### 2. Created PersistentTerminalView
**File: PersistentTerminalView.swift**
- Renders ALL terminals from ALL profiles simultaneously
- Uses opacity to show/hide terminals
- Never destroys terminal views, just hides them

### Architecture:
```
ContentView (stable)
└── ProfileDetailView (no longer recreated on profile change)
    └── TabView
        └── PersistentTerminalView
            └── ZStack (contains ALL terminals)
                ├── Profile A - Terminal 1 (opacity: 0)
                ├── Profile A - Terminal 2 (opacity: 0)
                ├── Profile B - Terminal 1 (opacity: 1) ← visible
                └── Profile B - Terminal 2 (opacity: 0)
```

## Key Components

### PersistentTerminalView
- Renders all terminals in a ZStack
- Only shows terminals for current profile in tab bar
- Changes opacity based on selection
- Never destroys terminals

### TerminalHostingView
- NSViewRepresentable that creates LocalProcessTerminalView
- Created once per session, never recreated
- Manages SSH connection directly

### TerminalSessionManager
- Singleton that tracks all sessions across all profiles
- Sessions persist until explicitly closed

## How It Works

1. **First Profile Terminal**: Creates session, renders terminal
2. **Switch to Different Profile**: 
   - ProfileDetailView updates (not recreated)
   - PersistentTerminalView changes which sessions show in tab bar
   - Previous profile's terminals set to opacity(0)
   - New profile's terminal set to opacity(1)
3. **Switch Back**: All terminals still alive, just change opacity

## Testing Steps

1. Open app, select Profile A
2. Go to Embedded Terminal tab
3. Terminal connects to Server A
4. Type some commands
5. Select Profile B (different server)
6. Go to Embedded Terminal tab
7. Terminal connects to Server B
8. Type some commands
9. Switch back to Profile A
10. Terminal for Server A should still be connected with content preserved

## Verification Checklist

- [ ] ContentView no longer has `.id(profile.id)`
- [ ] ProfileDetailView uses PersistentTerminalView
- [ ] All terminals render simultaneously in ZStack
- [ ] Opacity controls visibility
- [ ] Tab bar shows only current profile's sessions
- [ ] Switching profiles preserves all terminals

## If Still Not Working

Check these potential issues:

1. **ProfileDetailView still being recreated**: 
   - Add logging in ProfileDetailView.init() to verify
   - Check for other .id() modifiers higher up

2. **Terminal views being destroyed**:
   - Add logging in TerminalHostingView.makeNSView()
   - Should only be called once per session

3. **Session manager issues**:
   - Verify sessions persist in TerminalSessionManager
   - Check that sessions aren't being cleared

4. **SwiftUI view identity**:
   - Ensure no .id() modifiers on terminal views
   - Check for environment changes that force recreation

## Debug Code

Add this to verify views aren't being recreated:

```swift
// In ProfileDetailView.init()
print("ProfileDetailView INIT for profile: \(profile.name)")

// In TerminalHostingView.makeNSView()
print("Creating terminal for session: \(session.id)")

// In PersistentTerminalView.body
print("Rendering \(getAllSessions().count) total sessions")
```

If you see multiple INIT or makeNSView calls for the same profile/session, something is still forcing recreation.