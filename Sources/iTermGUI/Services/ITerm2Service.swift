import Foundation
import AppKit

class ITerm2Service {
    private let dynamicProfilesPath: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.dynamicProfilesPath = appSupport
            .appendingPathComponent("iTerm2")
            .appendingPathComponent("DynamicProfiles")
    }
    
    func openConnection(profile: SSHProfile, mode: ConnectionMode = .windows) {
        createDynamicProfile(for: profile)
        launchITerm2WithProfile(profile.name, newWindow: true)
    }
    
    func openConnections(profiles: [SSHProfile], mode: ConnectionMode) {
        guard !profiles.isEmpty else { return }
        
        // Create dynamic profiles for all connections
        for profile in profiles {
            createDynamicProfile(for: profile)
        }
        
        // Launch connections based on mode
        switch mode {
        case .tabs:
            launchITerm2WithProfilesInTabs(profiles.map { $0.name })
        case .windows:
            for profile in profiles {
                launchITerm2WithProfile(profile.name, newWindow: true)
            }
        }
    }
    
    private func createDynamicProfile(for profile: SSHProfile) {
        ensureDynamicProfilesDirectory()
        
        let dynamicProfile = createITerm2Profile(from: profile)
        let profileData = ["Profiles": [dynamicProfile]]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: profileData, options: .prettyPrinted)
            let profileFile = dynamicProfilesPath.appendingPathComponent("iTermGUI-\(profile.id.uuidString).json")
            try jsonData.write(to: profileFile)
        } catch {
            print("Error creating dynamic profile: \(error)")
        }
    }
    
    private func createITerm2Profile(from profile: SSHProfile) -> [String: Any] {
        var sshCommand = "ssh"
        
        if !profile.username.isEmpty {
            sshCommand += " \(profile.username)@\(profile.host)"
        } else {
            sshCommand += " \(profile.host)"
        }
        
        if profile.port != 22 {
            sshCommand += " -p \(profile.port)"
        }
        
        if let keyPath = profile.privateKeyPath ?? profile.identityFile {
            sshCommand += " -i \(keyPath)"
        }
        
        if let jumpHost = profile.jumpHost {
            sshCommand += " -J \(jumpHost)"
        }
        
        for forward in profile.localForwards {
            sshCommand += " -L \(forward.localPort):\(forward.remoteHost):\(forward.remotePort)"
        }
        
        for forward in profile.remoteForwards {
            sshCommand += " -R \(forward.localPort):\(forward.remoteHost):\(forward.remotePort)"
        }
        
        if profile.compression {
            sshCommand += " -C"
        }
        
        if !profile.strictHostKeyChecking {
            sshCommand += " -o StrictHostKeyChecking=no"
        }
        
        sshCommand += " -o ConnectTimeout=\(profile.connectionTimeout)"
        sshCommand += " -o ServerAliveInterval=\(profile.serverAliveInterval)"
        
        var initialText = ""
        if !profile.customCommands.isEmpty {
            initialText = profile.customCommands.joined(separator: "; ") + "\n"
        }
        
        var iterm2Profile: [String: Any] = [
            "Name": profile.name,
            "Guid": profile.id.uuidString,
            "Custom Command": "Yes",
            "Command": sshCommand,
            "Tags": Array(profile.tags),
            "Badge Text": profile.host,
            "Initial Text": initialText,
            "Normal Font": "\(profile.terminalSettings.fontFamily) \(profile.terminalSettings.fontSize)",
            "Scrollback Lines": profile.terminalSettings.scrollbackLines,
            "Close Sessions On End": true,
            "Terminal Type": "xterm-256color"
        ]
        
        switch profile.terminalSettings.cursorStyle {
        case .block:
            iterm2Profile["Cursor Type"] = 2  // Box cursor in iTerm2
        case .bar:
            iterm2Profile["Cursor Type"] = 1  // Vertical bar cursor in iTerm2
        case .underline:
            iterm2Profile["Cursor Type"] = 0  // Underline cursor in iTerm2
        }
        
        if let colorScheme = getColorScheme(named: profile.terminalSettings.colorScheme) {
            iterm2Profile.merge(colorScheme) { _, new in new }
        }
        
        return iterm2Profile
    }
    
    private func launchITerm2WithProfile(_ profileName: String, newWindow: Bool) {
        let script = """
        tell application "iTerm"
            activate
            if \(newWindow) or (count of windows) = 0 then
                set newWindow to (create window with profile "\(profileName)")
            else
                tell current window
                    create tab with profile "\(profileName)"
                end tell
            end if
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
    
    private func launchITerm2WithProfilesInTabs(_ profileNames: [String]) {
        guard !profileNames.isEmpty else { return }
        
        let script = """
        tell application "iTerm"
            activate
            
            -- Create new window with first profile
            set newWindow to (create window with profile "\(profileNames[0])")
            
            -- Add remaining profiles as tabs
            \(profileNames.dropFirst().map { profileName in
                """
                tell newWindow
                    create tab with profile "\(profileName)"
                end tell
                """
            }.joined(separator: "\n            "))
            
            -- Select first tab
            tell newWindow
                select tab 1
            end tell
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
    
    private func ensureDynamicProfilesDirectory() {
        try? FileManager.default.createDirectory(at: dynamicProfilesPath, withIntermediateDirectories: true)
    }
    
    private func getColorScheme(named name: String) -> [String: Any]? {
        let schemes: [String: [String: Any]] = [
            "Default": [:],
            "Solarized Dark": [
                "Background Color": [
                    "Red Component": 0.0,
                    "Green Component": 0.168627,
                    "Blue Component": 0.211765
                ],
                "Foreground Color": [
                    "Red Component": 0.513725,
                    "Green Component": 0.580392,
                    "Blue Component": 0.588235
                ]
            ],
            "Solarized Light": [
                "Background Color": [
                    "Red Component": 0.992157,
                    "Green Component": 0.964706,
                    "Blue Component": 0.890196
                ],
                "Foreground Color": [
                    "Red Component": 0.396078,
                    "Green Component": 0.482353,
                    "Blue Component": 0.513725
                ]
            ],
            "Dracula": [
                "Background Color": [
                    "Red Component": 0.156863,
                    "Green Component": 0.164706,
                    "Blue Component": 0.211765
                ],
                "Foreground Color": [
                    "Red Component": 0.972549,
                    "Green Component": 0.972549,
                    "Blue Component": 0.949020
                ]
            ]
        ]
        
        return schemes[name]
    }
    
    func testConnection(profile: SSHProfile, completion: @escaping (Bool, String?) -> Void) {
        let task = Process()
        task.launchPath = "/usr/bin/ssh"
        
        var arguments = ["-o", "ConnectTimeout=5", "-o", "BatchMode=yes"]
        
        if !profile.username.isEmpty {
            arguments.append("\(profile.username)@\(profile.host)")
        } else {
            arguments.append(profile.host)
        }
        
        if profile.port != 22 {
            arguments.append(contentsOf: ["-p", "\(profile.port)"])
        }
        
        if let keyPath = profile.privateKeyPath ?? profile.identityFile {
            arguments.append(contentsOf: ["-i", keyPath])
        }
        
        arguments.append("echo 'Connection successful'")
        
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.terminationHandler = { process in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    completion(true, nil)
                } else {
                    completion(false, output)
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            completion(false, error.localizedDescription)
        }
    }
}