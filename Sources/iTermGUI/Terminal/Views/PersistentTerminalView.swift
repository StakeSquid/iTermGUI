import SwiftUI
import SwiftTerm

// This view uses the simplest approach: render all terminals always, just change opacity
struct PersistentTerminalView: View {
    @StateObject private var sessionManager = TerminalSessionManager.shared
    @EnvironmentObject var profileManager: ProfileManager
    
    let currentProfileId: UUID
    @State private var selectedSessionId: UUID?
    
    var currentProfileSessions: [TerminalSession] {
        sessionManager.getActiveSessions(for: currentProfileId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar for current profile - always visible
            HStack(spacing: 1) {
                // Show tabs for current profile
                if !currentProfileSessions.isEmpty {
                    ForEach(currentProfileSessions) { session in
                        TerminalTab(
                            session: session,
                            isSelected: session.id == selectedSessionId,
                            isHovered: false,
                            onSelect: {
                                selectedSessionId = session.id
                                sessionManager.setActiveSession(session.id)
                            },
                            onClose: {
                                closeSession(session)
                            }
                        )
                    }
                } else {
                    // Show placeholder when no sessions
                    Text("No active sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }
                
                // New tab button - always visible
                Button(action: createNewSession) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(height: 36)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Render ALL terminals from ALL profiles, use opacity to show/hide
            ZStack {
                // Get all sessions from all profiles
                ForEach(getAllSessions()) { session in
                    TerminalHostingView(session: session)
                        .opacity(session.id == selectedSessionId ? 1 : 0)
                        .allowsHitTesting(session.id == selectedSessionId)
                }
                
                // Empty state - only show if no sessions for current profile
                if currentProfileSessions.isEmpty {
                    EmptyTerminalView(onConnect: createNewSession)
                }
            }
        }
        .onAppear {
            // Ensure we have a selection when view appears
            ensureValidSelection()
        }
        .onChange(of: currentProfileId) { _ in
            // When profile changes, immediately select appropriate session
            ensureValidSelection()
        }
        .onReceive(sessionManager.$sessions) { _ in
            // When sessions change, ensure selection is still valid
            ensureValidSelection()
        }
    }
    
    private func getAllSessions() -> [TerminalSession] {
        var allSessions: [TerminalSession] = []
        for (_, sessions) in sessionManager.sessions {
            allSessions.append(contentsOf: sessions)
        }
        return allSessions
    }
    
    private func ensureValidSelection() {
        // Check if current selection is valid for current profile
        if let selectedId = selectedSessionId,
           currentProfileSessions.contains(where: { $0.id == selectedId }) {
            // Selection is valid for current profile
            return
        }
        
        // Need to select a session for current profile
        if let firstSession = currentProfileSessions.first {
            // Select first existing session
            selectedSessionId = firstSession.id
            sessionManager.setActiveSession(firstSession.id)
        } else {
            // No sessions for this profile, create one
            createNewSession()
        }
    }
    
    private func createNewSession() {
        guard let profile = profileManager.profiles.first(where: { $0.id == currentProfileId }) else { return }
        
        let settings = profile.embeddedTerminalSettings ?? EmbeddedTerminalSettings()
        let session = sessionManager.createSession(for: profile, settings: settings)
        
        selectedSessionId = session.id
        sessionManager.setActiveSession(session.id)
    }
    
    private func closeSession(_ session: TerminalSession) {
        sessionManager.closeSession(session)
        
        if selectedSessionId == session.id {
            if let nextSession = currentProfileSessions.first {
                selectedSessionId = nextSession.id
                sessionManager.setActiveSession(nextSession.id)
            } else {
                selectedSessionId = nil
            }
        }
    }
}