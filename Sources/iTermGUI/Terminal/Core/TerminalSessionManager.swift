import Foundation
import SwiftUI
import Combine

class TerminalSessionManager: ObservableObject {
    static let shared = TerminalSessionManager()
    
    @Published private(set) var sessions: [UUID: [TerminalSession]] = [:]
    @Published var activeSessionId: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSavedSessions()
    }
    
    func createSession(for profile: SSHProfile, settings: EmbeddedTerminalSettings) -> TerminalSession {
        let session = TerminalSession(profile: profile, settings: settings)
        
        if sessions[profile.id] == nil {
            sessions[profile.id] = []
        }
        
        sessions[profile.id]?.append(session)
        
        // Make the new session active
        activeSessionId = session.id
        
        // Auto-connect
        session.connect()
        
        saveSessions()
        
        return session
    }
    
    func closeSession(_ session: TerminalSession) {
        session.disconnect()
        
        if var profileSessions = sessions[session.profileId] {
            profileSessions.removeAll { $0.id == session.id }
            
            if profileSessions.isEmpty {
                sessions[session.profileId] = nil
            } else {
                sessions[session.profileId] = profileSessions
                
                // Activate another session if the closed one was active
                if activeSessionId == session.id {
                    activeSessionId = profileSessions.first?.id
                }
            }
        }
        
        saveSessions()
    }
    
    func closeAllSessions(for profileId: UUID) {
        if let profileSessions = sessions[profileId] {
            for session in profileSessions {
                session.disconnect()
            }
            sessions[profileId] = nil
        }
        
        saveSessions()
    }
    
    func getActiveSessions(for profileId: UUID) -> [TerminalSession] {
        return sessions[profileId] ?? []
    }
    
    func setActiveSession(_ sessionId: UUID) {
        activeSessionId = sessionId
        
        // Update session active states
        for profileSessions in sessions.values {
            for session in profileSessions {
                session.isActive = (session.id == sessionId)
            }
        }
    }
    
    func reconnectAll() {
        for profileSessions in sessions.values {
            for session in profileSessions {
                if case .disconnected = session.state {
                    session.connect()
                } else if case .error = session.state {
                    session.connect()
                }
            }
        }
    }
    
    private func saveSessions() {
        // Save session metadata for restoration
        var sessionData: [[String: Any]] = []
        
        for (profileId, profileSessions) in sessions {
            for session in profileSessions {
                sessionData.append([
                    "profileId": profileId.uuidString,
                    "sessionId": session.id.uuidString,
                    "title": session.title
                ])
            }
        }
        
        UserDefaults.standard.set(sessionData, forKey: "TerminalSessions")
    }
    
    private func loadSavedSessions() {
        // Load session metadata (actual reconnection happens on demand)
        guard UserDefaults.standard.array(forKey: "TerminalSessions") as? [[String: Any]] != nil else {
            return
        }
        
        // Sessions will be recreated when profiles are loaded
        // This is just for reference
    }
    
    func debugInfo() -> String {
        var info = "Terminal Session Manager Debug Info:\n"
        info += "Total profiles with sessions: \(sessions.count)\n"
        info += "Active session ID: \(activeSessionId?.uuidString ?? "none")\n\n"
        
        for (profileId, profileSessions) in sessions {
            info += "Profile \(profileId.uuidString.prefix(8)):\n"
            for session in profileSessions {
                info += "  - Session \(session.id.uuidString.prefix(8)): \(session.state)\n"
            }
        }
        
        return info
    }
}

// Extension for debugging
extension TerminalSessionState: CustomStringConvertible {
    var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}