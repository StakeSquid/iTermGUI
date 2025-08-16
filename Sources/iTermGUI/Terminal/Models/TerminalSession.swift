import Foundation
import SwiftUI
import SwiftTerm

enum TerminalSessionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
}

class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    let profileId: UUID
    let profileName: String
    
    @Published var state: TerminalSessionState = .disconnected
    @Published var title: String
    @Published var isActive: Bool = false
    
    var terminal: LocalProcessTerminalView?
    
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    
    let settings: EmbeddedTerminalSettings
    let sshProfile: SSHProfile
    var processDelegate: TerminalProcessDelegate?
    
    init(profile: SSHProfile, settings: EmbeddedTerminalSettings) {
        self.profileId = profile.id
        self.profileName = profile.name
        self.title = profile.name
        self.sshProfile = profile
        self.settings = settings
    }
    
    func connect() {
        // Connection is now handled by TerminalHostingView
        // This method is kept for compatibility but does nothing
        // The actual connection happens in TerminalHostingView.startSSHConnection
    }
    
    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        // Note: LocalProcessTerminalView doesn't expose public termination methods
        // The process will be terminated when the terminal view is deallocated
        // or when the session manager closes the session
        state = .disconnected
    }
    
    func reconnect() {
        guard settings.autoReconnect else {
            state = .disconnected
            return
        }
        
        guard reconnectAttempts < maxReconnectAttempts else {
            state = .error("Maximum reconnection attempts reached")
            return
        }
        
        reconnectAttempts += 1
        state = .reconnecting
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.reconnectDelay), repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
    
    
    func runInitialCommands() {
        guard state == .connected else { return }
        
        // Run profile-specific commands
        for command in sshProfile.customCommands {
            sendCommand(command)
        }
        
        // Run terminal settings commands
        for command in settings.onConnectCommands {
            sendCommand(command)
        }
    }
    
    func sendCommand(_ command: String) {
        guard let terminal = terminal else { return }
        
        let commandWithNewline = command + "\n"
        terminal.send(txt: commandWithNewline)
    }
    
    func sendInput(_ text: String) {
        guard let terminal = terminal else { return }
        
        terminal.send(txt: text)
    }
    
    func handleDisconnection() {
        if settings.autoReconnect && reconnectAttempts < maxReconnectAttempts {
            reconnect()
        } else {
            state = .disconnected
        }
    }
    
    func resize(columns: Int, rows: Int) {
        terminal?.resize(cols: columns, rows: rows)
    }
}

// Terminal process delegate for handling SSH connection events
class TerminalProcessDelegate: LocalProcessTerminalViewDelegate {
    weak var session: TerminalSession?
    
    init(session: TerminalSession) {
        self.session = session
    }
    
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.session?.handleDisconnection()
        }
    }
    
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // Optional: Update UI with current directory
    }
    
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        DispatchQueue.main.async { [weak self] in
            self?.session?.title = title
        }
    }
    
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // Terminal size changed, no action needed as this is handled elsewhere
    }
    
    func requestOpenLink(_ terminalView: LocalProcessTerminalView, link: String, params: [String : String]) {
        // Optional: Handle link opening
    }
}