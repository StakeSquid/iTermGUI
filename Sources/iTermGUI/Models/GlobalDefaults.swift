import Foundation

struct GlobalDefaults: Codable {
    var terminalSettings: TerminalSettings
    var embeddedTerminalSettings: EmbeddedTerminalSettings
    var customCommands: [String]
    var connectionTimeout: Int
    var serverAliveInterval: Int
    var strictHostKeyChecking: Bool
    var compression: Bool
    
    static let standard = GlobalDefaults(
        terminalSettings: TerminalSettings(),
        embeddedTerminalSettings: EmbeddedTerminalSettings(),
        customCommands: [],
        connectionTimeout: 30,
        serverAliveInterval: 60,
        strictHostKeyChecking: true,
        compression: false
    )
    
    func applyToProfile(_ profile: inout SSHProfile) {
        profile.terminalSettings = terminalSettings
        profile.embeddedTerminalSettings = embeddedTerminalSettings
        profile.customCommands = customCommands
        profile.connectionTimeout = connectionTimeout
        profile.serverAliveInterval = serverAliveInterval
        profile.strictHostKeyChecking = strictHostKeyChecking
        profile.compression = compression
        profile.modifiedAt = Date()
    }
}