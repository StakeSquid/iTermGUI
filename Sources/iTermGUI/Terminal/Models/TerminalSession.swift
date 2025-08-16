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
    private var processDelegate: TerminalProcessDelegate?
    
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    
    let settings: EmbeddedTerminalSettings
    private let sshProfile: SSHProfile
    
    init(profile: SSHProfile, settings: EmbeddedTerminalSettings) {
        self.profileId = profile.id
        self.profileName = profile.name
        self.title = profile.name
        self.sshProfile = profile
        self.settings = settings
    }
    
    func connect() {
        guard state != .connected && state != .connecting else { return }
        
        state = .connecting
        reconnectAttempts = 0
        
        DispatchQueue.main.async { [weak self] in
            self?.establishSSHConnection()
        }
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
    
    private func establishSSHConnection() {
        guard let terminal = terminal else {
            self.state = .error("Terminal not initialized")
            return
        }
        
        // Build SSH command
        var sshArgs: [String] = []
        
        // Basic connection
        sshArgs.append("-o")
        sshArgs.append("ConnectTimeout=\(sshProfile.connectionTimeout)")
        sshArgs.append("-o")
        sshArgs.append("ServerAliveInterval=\(sshProfile.serverAliveInterval)")
        sshArgs.append("-o")
        sshArgs.append("StrictHostKeyChecking=\(sshProfile.strictHostKeyChecking ? "yes" : "no")")
        
        if sshProfile.compression {
            sshArgs.append("-C")
        }
        
        // Port
        if sshProfile.port != 22 {
            sshArgs.append("-p")
            sshArgs.append("\(sshProfile.port)")
        }
        
        // Authentication
        if sshProfile.authMethod == .publicKey, let keyPath = sshProfile.privateKeyPath {
            sshArgs.append("-i")
            sshArgs.append(keyPath)
        }
        
        // Jump host
        if let jumpHost = sshProfile.jumpHost, !jumpHost.isEmpty {
            sshArgs.append("-J")
            sshArgs.append(jumpHost)
        }
        
        // Proxy command
        if let proxyCommand = sshProfile.proxyCommand, !proxyCommand.isEmpty {
            sshArgs.append("-o")
            sshArgs.append("ProxyCommand=\(proxyCommand)")
        }
        
        // Port forwarding
        for forward in sshProfile.localForwards {
            sshArgs.append("-L")
            sshArgs.append("\(forward.localPort):\(forward.remoteHost):\(forward.remotePort)")
        }
        
        for forward in sshProfile.remoteForwards {
            sshArgs.append("-R")
            sshArgs.append("\(forward.localPort):\(forward.remoteHost):\(forward.remotePort)")
        }
        
        // Connection string
        let connectionString = sshProfile.username.isEmpty ? sshProfile.host : "\(sshProfile.username)@\(sshProfile.host)"
        sshArgs.append(connectionString)
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = settings.terminalType
        environment["LANG"] = settings.locale
        environment["LC_ALL"] = settings.locale
        
        // Set up termination handler - store delegate to prevent deallocation
        let delegate = TerminalProcessDelegate(session: self)
        self.processDelegate = delegate
        terminal.processDelegate = delegate
        
        // Convert environment dictionary to array format
        let envArray = environment.map { "\($0.key)=\($0.value)" }
        
        // Start SSH process using LocalProcessTerminalView
        terminal.startProcess(
            executable: "/usr/bin/ssh",
            args: sshArgs,
            environment: envArray
        )
        self.state = .connected
        
        // Run initial commands after a short delay to allow connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.runInitialCommands()
        }
    }
    
    private func runInitialCommands() {
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