import SwiftUI
import SwiftTerm

// Global container that lives at the app level and never gets recreated
struct GlobalTerminalContainer: View {
    @StateObject private var sessionManager = TerminalSessionManager.shared
    let currentProfileId: UUID?
    
    @State private var allTerminalViews: [UUID: AnyView] = [:]
    @State private var terminalViewsCreated: Set<UUID> = []
    
    var body: some View {
        ZStack {
            if let profileId = currentProfileId {
                // Get all sessions across all profiles
                let allSessions = getAllSessions()
                
                if allSessions.isEmpty {
                    EmptyTerminalView(onConnect: {
                        createNewSessionForProfile(profileId)
                    })
                } else {
                    // Create views for all sessions
                    ForEach(allSessions) { session in
                        Group {
                            if terminalViewsCreated.contains(session.id) {
                                // Terminal already created, just show/hide it
                                TerminalHostingView(session: session)
                                    .opacity(shouldShowSession(session, currentProfileId: profileId) ? 1 : 0)
                                    .allowsHitTesting(shouldShowSession(session, currentProfileId: profileId))
                                    .id(session.id)
                            } else {
                                // First time showing this session, create the terminal
                                TerminalHostingView(session: session)
                                    .opacity(shouldShowSession(session, currentProfileId: profileId) ? 1 : 0)
                                    .allowsHitTesting(shouldShowSession(session, currentProfileId: profileId))
                                    .id(session.id)
                                    .onAppear {
                                        terminalViewsCreated.insert(session.id)
                                    }
                            }
                        }
                    }
                }
            } else {
                Text("Select a profile to view terminals")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func getAllSessions() -> [TerminalSession] {
        var sessions: [TerminalSession] = []
        for (_, profileSessions) in sessionManager.sessions {
            sessions.append(contentsOf: profileSessions)
        }
        return sessions
    }
    
    private func shouldShowSession(_ session: TerminalSession, currentProfileId: UUID) -> Bool {
        // Show session if it belongs to current profile and is active
        return session.profileId == currentProfileId && session.id == sessionManager.activeSessionId
    }
    
    private func createNewSessionForProfile(_ profileId: UUID) {
        // This will be called from the tab bar
    }
}

// Simplified terminal tab interface that just controls which session is visible
struct TerminalTabInterface: View {
    @EnvironmentObject var profileManager: ProfileManager
    @StateObject private var sessionManager = TerminalSessionManager.shared
    
    let currentProfileId: UUID
    
    var currentProfileSessions: [TerminalSession] {
        sessionManager.getActiveSessions(for: currentProfileId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if !currentProfileSessions.isEmpty || true { // Always show tab bar
                HStack(spacing: 1) {
                    ForEach(currentProfileSessions) { session in
                        TerminalTab(
                            session: session,
                            isSelected: session.id == sessionManager.activeSessionId,
                            isHovered: false,
                            onSelect: {
                                sessionManager.setActiveSession(session.id)
                            },
                            onClose: {
                                sessionManager.closeSession(session)
                            }
                        )
                    }
                    
                    // New tab button
                    Button(action: {
                        createNewSession()
                    }) {
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
            }
            
            // Terminal container (persistent across profile changes)
            GlobalTerminalContainer(currentProfileId: currentProfileId)
        }
    }
    
    private func createNewSession() {
        guard let profile = profileManager.profiles.first(where: { $0.id == currentProfileId }) else { return }
        
        let settings = profile.embeddedTerminalSettings ?? EmbeddedTerminalSettings()
        let session = sessionManager.createSession(for: profile, settings: settings)
        sessionManager.setActiveSession(session.id)
    }
}