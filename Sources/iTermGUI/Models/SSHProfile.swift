import Foundation
import SwiftUI

struct SSHProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var privateKeyPath: String?
    var password: String?
    var tags: Set<String>
    var jumpHost: String?
    var localForwards: [PortForward]
    var remoteForwards: [PortForward]
    var proxyCommand: String?
    var identityFile: String?
    var strictHostKeyChecking: Bool
    var compression: Bool
    var connectionTimeout: Int
    var serverAliveInterval: Int
    var isFavorite: Bool
    var customCommands: [String]
    var terminalSettings: TerminalSettings
    var lastUsed: Date?
    var createdAt: Date
    var modifiedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String = "",
        authMethod: AuthMethod = .publicKey,
        privateKeyPath: String? = nil,
        password: String? = nil,
        tags: Set<String> = [],
        jumpHost: String? = nil,
        localForwards: [PortForward] = [],
        remoteForwards: [PortForward] = [],
        proxyCommand: String? = nil,
        identityFile: String? = nil,
        strictHostKeyChecking: Bool = true,
        compression: Bool = false,
        connectionTimeout: Int = 30,
        serverAliveInterval: Int = 60,
        isFavorite: Bool = false,
        customCommands: [String] = [],
        terminalSettings: TerminalSettings = TerminalSettings(),
        lastUsed: Date? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.password = password
        self.tags = tags
        self.jumpHost = jumpHost
        self.localForwards = localForwards
        self.remoteForwards = remoteForwards
        self.proxyCommand = proxyCommand
        self.identityFile = identityFile
        self.strictHostKeyChecking = strictHostKeyChecking
        self.compression = compression
        self.connectionTimeout = connectionTimeout
        self.serverAliveInterval = serverAliveInterval
        self.isFavorite = isFavorite
        self.customCommands = customCommands
        self.terminalSettings = terminalSettings
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    var connectionString: String {
        var conn = ""
        if !username.isEmpty {
            conn += "\(username)@"
        }
        conn += host
        if port != 22 {
            conn += ":\(port)"
        }
        return conn
    }
    
    func toSSHConfigEntry() -> String {
        var config = "Host \(name)\n"
        config += "    HostName \(host)\n"
        if port != 22 {
            config += "    Port \(port)\n"
        }
        if !username.isEmpty {
            config += "    User \(username)\n"
        }
        if let keyPath = privateKeyPath ?? identityFile {
            config += "    IdentityFile \(keyPath)\n"
        }
        if let jump = jumpHost {
            config += "    ProxyJump \(jump)\n"
        }
        if let proxy = proxyCommand {
            config += "    ProxyCommand \(proxy)\n"
        }
        for forward in localForwards {
            config += "    LocalForward \(forward.localPort) \(forward.remoteHost):\(forward.remotePort)\n"
        }
        for forward in remoteForwards {
            config += "    RemoteForward \(forward.localPort) \(forward.remoteHost):\(forward.remotePort)\n"
        }
        if compression {
            config += "    Compression yes\n"
        }
        config += "    ConnectTimeout \(connectionTimeout)\n"
        config += "    ServerAliveInterval \(serverAliveInterval)\n"
        config += "    StrictHostKeyChecking \(strictHostKeyChecking ? "yes" : "no")\n"
        
        return config
    }
}

enum AuthMethod: String, Codable, CaseIterable {
    case publicKey = "Public Key"
    case password = "Password"
    case keyboardInteractive = "Keyboard Interactive"
    case certificate = "Certificate"
}

struct PortForward: Codable, Hashable {
    var localPort: Int
    var remoteHost: String
    var remotePort: Int
}

struct TerminalSettings: Codable, Hashable {
    var colorScheme: String
    var fontSize: Int
    var fontFamily: String
    var cursorStyle: CursorStyle
    var scrollbackLines: Int
    
    init(
        colorScheme: String = "Default",
        fontSize: Int = 12,
        fontFamily: String = "Monaco",
        cursorStyle: CursorStyle = .block,
        scrollbackLines: Int = 10000
    ) {
        self.colorScheme = colorScheme
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.cursorStyle = cursorStyle
        self.scrollbackLines = scrollbackLines
    }
}

enum CursorStyle: String, Codable, CaseIterable {
    case block = "Block"
    case underline = "Underline"
    case bar = "Bar"
}