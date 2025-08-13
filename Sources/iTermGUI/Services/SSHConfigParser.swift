import Foundation

class SSHConfigParser {
    
    func parseDefaultConfig() async throws -> [SSHProfile] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDirectory.appendingPathComponent(".ssh/config")
        return try await parseConfigFile(at: configPath)
    }
    
    func parseConfigFile(at url: URL) async throws -> [SSHProfile] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseConfigContent(content)
    }
    
    private func parseConfigContent(_ content: String) -> [SSHProfile] {
        var profiles: [SSHProfile] = []
        var currentHost: String?
        var currentConfig: [String: String] = [:]
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            if trimmedLine.lowercased().hasPrefix("host ") {
                if let host = currentHost {
                    if let profile = createProfile(from: host, config: currentConfig) {
                        profiles.append(profile)
                    }
                }
                
                currentHost = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                currentConfig = [:]
            } else if currentHost != nil {
                let parts = trimmedLine.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
                if parts.count == 2 {
                    let key = String(parts[0]).lowercased()
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    currentConfig[key] = value
                }
            }
        }
        
        if let host = currentHost {
            if let profile = createProfile(from: host, config: currentConfig) {
                profiles.append(profile)
            }
        }
        
        return profiles
    }
    
    private func createProfile(from hostAlias: String, config: [String: String]) -> SSHProfile? {
        guard !hostAlias.contains("*") else { return nil }
        
        let hostname = config["hostname"] ?? hostAlias
        let port = Int(config["port"] ?? "22") ?? 22
        let user = config["user"] ?? NSUserName()
        let identityFile = config["identityfile"]
        let proxyJump = config["proxyjump"]
        let proxyCommand = config["proxycommand"]
        let compression = config["compression"]?.lowercased() == "yes"
        let strictHostKeyChecking = config["stricthostkeychecking"]?.lowercased() != "no"
        let connectTimeout = Int(config["connecttimeout"] ?? "30") ?? 30
        let serverAliveInterval = Int(config["serveraliveinterval"] ?? "60") ?? 60
        
        var localForwards: [PortForward] = []
        if let forward = config["localforward"] {
            if let parsed = parsePortForward(forward, isLocal: true) {
                localForwards.append(parsed)
            }
        }
        
        var remoteForwards: [PortForward] = []
        if let forward = config["remoteforward"] {
            if let parsed = parsePortForward(forward, isLocal: false) {
                remoteForwards.append(parsed)
            }
        }
        
        let authMethod: AuthMethod = identityFile != nil ? .publicKey : .password
        
        return SSHProfile(
            name: hostAlias,
            host: hostname,
            port: port,
            username: user,
            authMethod: authMethod,
            privateKeyPath: identityFile?.expandingTildeInPath(),
            jumpHost: proxyJump,
            localForwards: localForwards,
            remoteForwards: remoteForwards,
            proxyCommand: proxyCommand,
            identityFile: identityFile?.expandingTildeInPath(),
            strictHostKeyChecking: strictHostKeyChecking,
            compression: compression,
            connectionTimeout: connectTimeout,
            serverAliveInterval: serverAliveInterval
        )
    }
    
    private func parsePortForward(_ forward: String, isLocal: Bool) -> PortForward? {
        let parts = forward.split(whereSeparator: { $0.isWhitespace || $0 == ":" })
        if parts.count >= 3 {
            let localPort = Int(String(parts[0])) ?? 0
            let remoteHost = String(parts[1])
            let remotePort = Int(String(parts[2])) ?? 0
            return PortForward(localPort: localPort, remoteHost: remoteHost, remotePort: remotePort)
        }
        return nil
    }
}

extension String {
    func expandingTildeInPath() -> String {
        if self.hasPrefix("~/") {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            return self.replacingOccurrences(of: "~", with: homeDirectory, range: self.startIndex..<self.index(self.startIndex, offsetBy: 1))
        }
        return self
    }
}