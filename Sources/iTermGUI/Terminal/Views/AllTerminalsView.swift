import SwiftUI
import SwiftTerm

// This view manages ALL terminal sessions across ALL profiles
// It never gets recreated, ensuring terminal persistence
struct AllTerminalsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @StateObject private var sessionManager = TerminalSessionManager.shared
    
    let currentProfileId: UUID
    @State private var allSessions: [TerminalSession] = []
    @State private var selectedSessionId: UUID?
    
    var currentProfileSessions: [TerminalSession] {
        sessionManager.getActiveSessions(for: currentProfileId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar for current profile
            if !currentProfileSessions.isEmpty {
                TerminalTabBar(
                    sessions: currentProfileSessions,
                    selectedSessionId: Binding(
                        get: { selectedSessionId },
                        set: { newValue in
                            selectedSessionId = newValue
                            if let newValue = newValue {
                                sessionManager.setActiveSession(newValue)
                            }
                        }
                    ),
                    onNewTab: createNewSession,
                    onCloseTab: closeSession,
                    onSelectTab: selectSession
                )
                .frame(height: 36)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
            }
            
            // All terminals (hidden/shown based on selection)
            ZStack {
                if getAllSessions().isEmpty {
                    EmptyTerminalView(onConnect: createNewSession)
                } else {
                    // Render ALL sessions from ALL profiles
                    ForEach(getAllSessions()) { session in
                        TerminalContentView(session: session)
                            .opacity(session.id == selectedSessionId ? 1 : 0)
                            .allowsHitTesting(session.id == selectedSessionId)
                    }
                }
            }
        }
        .onAppear {
            loadSessions()
        }
        .onChange(of: currentProfileId) { _ in
            // When profile changes, update selected session to one from new profile
            switchToProfile()
        }
    }
    
    private func getAllSessions() -> [TerminalSession] {
        var sessions: [TerminalSession] = []
        for (_, profileSessions) in sessionManager.sessions {
            sessions.append(contentsOf: profileSessions)
        }
        return sessions
    }
    
    private func loadSessions() {
        allSessions = getAllSessions()
        
        // If no session selected, select first from current profile
        if selectedSessionId == nil || !currentProfileSessions.contains(where: { $0.id == selectedSessionId }) {
            if currentProfileSessions.isEmpty {
                createNewSession()
            } else {
                selectedSessionId = currentProfileSessions.first?.id
            }
        }
    }
    
    private func switchToProfile() {
        // When switching profiles, select a session from the new profile
        if let firstSession = currentProfileSessions.first {
            selectedSessionId = firstSession.id
            sessionManager.setActiveSession(firstSession.id)
        } else {
            // No sessions for this profile, create one
            createNewSession()
        }
    }
    
    private func createNewSession() {
        // Get the current profile
        guard let profile = profileManager.profiles.first(where: { $0.id == currentProfileId }) else { return }
        
        let settings = profile.embeddedTerminalSettings ?? EmbeddedTerminalSettings()
        let session = sessionManager.createSession(for: profile, settings: settings)
        
        // Update our local state
        allSessions = getAllSessions()
        selectedSessionId = session.id
        sessionManager.setActiveSession(session.id)
    }
    
    private func closeSession(_ session: TerminalSession) {
        sessionManager.closeSession(session)
        allSessions = getAllSessions()
        
        // If we closed the selected session, select another
        if selectedSessionId == session.id {
            if let nextSession = currentProfileSessions.first {
                selectedSessionId = nextSession.id
                sessionManager.setActiveSession(nextSession.id)
            } else {
                selectedSessionId = nil
            }
        }
    }
    
    private func selectSession(_ session: TerminalSession) {
        selectedSessionId = session.id
        sessionManager.setActiveSession(session.id)
    }
}