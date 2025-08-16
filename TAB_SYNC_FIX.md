# Terminal Tab Synchronization Fix

## Issues Fixed

### 1. First Terminal Connection Without Tab
**Problem**: When clicking "Embedded Terminal" for the first time, it would create a connection but not show a tab.

**Solution**: 
- Added `ensureValidSelection()` that always creates a session if none exist
- Tab bar now always shows, even with placeholder text when empty
- Session creation immediately updates the tab bar

### 2. Wrong Terminal Shown When Switching Profiles
**Problem**: When switching between profiles, it would continue showing the previous profile's terminal until you clicked a tab.

**Solution**:
- Added `ensureValidSelection()` that runs on:
  - View appear
  - Profile change
  - Session list change
- This ensures the selected terminal always matches the current profile

## Key Changes

### PersistentTerminalView.swift

1. **Improved Selection Logic**:
```swift
private func ensureValidSelection() {
    // Check if current selection is valid for current profile
    if let selectedId = selectedSessionId,
       currentProfileSessions.contains(where: { $0.id == selectedId }) {
        return // Selection is valid
    }
    
    // Select first session or create new one
    if let firstSession = currentProfileSessions.first {
        selectedSessionId = firstSession.id
        sessionManager.setActiveSession(firstSession.id)
    } else {
        createNewSession()
    }
}
```

2. **Multiple Triggers for Selection Update**:
- `.onAppear` - When terminal tab is selected
- `.onChange(of: currentProfileId)` - When switching profiles
- `.onReceive(sessionManager.$sessions)` - When sessions are added/removed

3. **Always Visible Tab Bar**:
- Shows tabs when sessions exist
- Shows "No active sessions" placeholder when empty
- "+" button always available

## How It Works Now

### Scenario 1: First Time Opening Terminal
1. User clicks "Embedded Terminal" tab
2. `onAppear` triggers → `ensureValidSelection()`
3. No sessions exist → `createNewSession()`
4. New session created and selected
5. Tab appears immediately

### Scenario 2: Switching Between Profiles
1. User selects different profile
2. `onChange(of: currentProfileId)` triggers
3. `ensureValidSelection()` checks if current selection is valid
4. Selects first session of new profile (or creates one)
5. Correct terminal shows immediately

### Scenario 3: Multiple Tabs Per Profile
1. Each profile maintains its own sessions
2. Tab bar shows only current profile's sessions
3. Selection persists within each profile
4. All terminals remain alive in background

## Testing Checklist

- [x] First terminal opens with tab visible
- [x] Switching profiles shows correct terminal immediately
- [x] Tab bar updates when switching profiles
- [x] Multiple tabs per profile work correctly
- [x] Sessions persist across profile switches
- [x] "+" button creates new session with tab
- [x] Closing tabs updates selection appropriately

## Architecture Summary

```
PersistentTerminalView
├── Tab Bar (shows current profile's sessions)
│   ├── Session tabs
│   └── "+" button
└── ZStack (all terminals)
    ├── Profile A terminals (hidden)
    └── Profile B terminals (visible for selected)
```

The key insight: Always ensure there's a valid selection for the current profile, and update it immediately when the profile changes.