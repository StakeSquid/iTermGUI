# Cross-Profile Terminal Persistence Fix

## Problem
When switching between different SSH profiles/servers, the terminal would lose its content and show only a blinking cursor. While tabs within the same profile worked, switching to a different profile would break all terminal sessions.

## Root Cause
The issue occurred at the profile level:
1. `ProfileDetailView` passes `editedProfile` to the terminal view
2. When switching profiles, `editedProfile` changes
3. This caused `EmbeddedTerminalView(profile: editedProfile)` to be recreated
4. All terminal sessions for all profiles were destroyed

The architecture had two levels of recreation problems:
- **Tab level**: Fixed by keeping all tabs alive with opacity (previous fix)
- **Profile level**: Terminal view itself was being recreated (this fix)

## Solution
Created a new `AllTerminalsView` that:
1. **Never gets recreated** - receives only the profile ID, not the profile object
2. **Manages ALL sessions** across ALL profiles simultaneously
3. **Renders every terminal** from every profile in a single ZStack
4. **Shows only the selected terminal** using opacity

### Architecture Changes

#### Before:
```
ProfileDetailView (recreated on profile change)
└── EmbeddedTerminalView(profile: editedProfile) ❌ Recreated!
    └── Terminal sessions (destroyed)
```

#### After:
```
ProfileDetailView
└── AllTerminalsView(currentProfileId: editedProfile.id) ✅ Persistent!
    ├── Manages ALL sessions from ALL profiles
    └── ZStack
        ├── Terminal for Profile A, Tab 1 (opacity: 0)
        ├── Terminal for Profile A, Tab 2 (opacity: 1) ← selected
        ├── Terminal for Profile B, Tab 1 (opacity: 0)
        └── Terminal for Profile B, Tab 2 (opacity: 0)
```

## Implementation Details

### New File: `AllTerminalsView.swift`
- Central view that manages all terminal sessions
- Never recreated (only receives profile ID)
- Renders all terminals simultaneously
- Handles profile switching by changing which sessions are visible

### Key Features:
1. **getAllSessions()**: Collects all sessions from all profiles
2. **switchToProfile()**: Updates UI when profile changes
3. **Tab bar shows only current profile's tabs**: But all terminals remain alive
4. **Single ZStack with all terminals**: Uses opacity for visibility

### Modified: `ProfileDetailView.swift`
```swift
// Before:
EmbeddedTerminalView(profile: editedProfile)

// After:
AllTerminalsView(currentProfileId: editedProfile.id)
```

### Modified: `TerminalSessionManager.swift`
- Made `sessions` property public for `AllTerminalsView` access

## How It Works

### Scenario 1: Multiple Tabs, Same Profile
1. User creates tabs for Profile A
2. All rendered in ZStack, selected one has opacity(1)
3. Switching tabs changes opacity only

### Scenario 2: Switching Profiles
1. User switches from Profile A to Profile B
2. `AllTerminalsView` receives new `currentProfileId`
3. Tab bar updates to show Profile B's sessions
4. Selected session changes to Profile B's first tab
5. **Profile A's terminals remain alive but hidden**

### Scenario 3: Returning to Previous Profile
1. User switches back to Profile A
2. All terminals still alive and connected
3. Content fully preserved

## Benefits

1. **True Persistence**: All terminals stay alive across all profile switches
2. **No Recreation**: View hierarchy remains stable
3. **State Preservation**: Terminal content, SSH connections, scroll position all maintained
4. **Performance**: No overhead of destroying/recreating terminals
5. **User Experience**: Seamless switching between profiles and tabs

## Memory Impact
- Each terminal session uses ~5-10MB
- With 5 profiles × 3 tabs each = 15 terminals = ~75-150MB
- Acceptable for modern systems
- Sessions properly cleaned up when explicitly closed

## Testing Checklist
- [x] Create terminal for Profile A
- [x] Create terminal for Profile B
- [x] Switch between Profile A and B - content preserved
- [x] Multiple tabs per profile work correctly
- [x] Tab bar shows only current profile's tabs
- [x] All terminals remain connected
- [x] No blinking cursor or dead terminals

## Summary
The terminal system now provides true persistence across:
- **Tab switches** within a profile (opacity-based hiding)
- **Profile switches** (all terminals rendered simultaneously)
- **Any navigation** in the app

This creates a professional terminal experience where users never lose their work, regardless of how they navigate through the application.