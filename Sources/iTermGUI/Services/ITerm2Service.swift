import Foundation
import AppKit

class ITerm2Service {
    private let dynamicProfilesPath: URL
    private let fileStore: ProfileFileStore
    private let scriptRunner: AppleScriptRunner
    private let processRunner: ProcessRunner
    private let passwordHelper: SSHPasswordHelper

    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let path = appSupport
            .appendingPathComponent("iTerm2")
            .appendingPathComponent("DynamicProfiles")
        self.init(dynamicProfilesRoot: path)
    }

    init(
        dynamicProfilesRoot: URL,
        fileStore: ProfileFileStore = FileManagerStore(),
        scriptRunner: AppleScriptRunner = NSAppleScriptRunner(),
        processRunner: ProcessRunner = FoundationProcessRunner(),
        passwordHelper: SSHPasswordHelper = .shared
    ) {
        self.dynamicProfilesPath = dynamicProfilesRoot
        self.fileStore = fileStore
        self.scriptRunner = scriptRunner
        self.processRunner = processRunner
        self.passwordHelper = passwordHelper
    }

    func openConnection(profile: SSHProfile, mode: ConnectionMode = .windows) {
        let passwordFiles = stagePasswordFiles(for: [profile])
        updateDynamicProfiles(with: [profile], passwordFiles: passwordFiles)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.runScript(self.launchScriptForProfile(profile.name, newWindow: true))
        }
    }

    func openConnections(profiles: [SSHProfile], mode: ConnectionMode) {
        guard !profiles.isEmpty else { return }
        let passwordFiles = stagePasswordFiles(for: profiles)
        updateDynamicProfiles(with: profiles, passwordFiles: passwordFiles)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch mode {
            case .tabs:
                self.runScript(self.launchScriptForTabs(profiles.map { $0.name }))
            case .windows:
                for profile in profiles {
                    self.runScript(self.launchScriptForProfile(profile.name, newWindow: true))
                }
            }
        }
    }

    /// For each profile that uses password auth and has a stored password,
    /// stage a one-shot password file. Returns a `[profileID: passwordFile]`
    /// map so the caller can wire those file paths into the launch command.
    private func stagePasswordFiles(for profiles: [SSHProfile]) -> [UUID: URL] {
        var result: [UUID: URL] = [:]
        for profile in profiles {
            guard profile.authMethod == .password,
                  let password = profile.password, !password.isEmpty,
                  let file = passwordHelper.stagePassword(password) else {
                continue
            }
            result[profile.id] = file
        }
        return result
    }

    private func updateDynamicProfiles(with profiles: [SSHProfile], passwordFiles: [UUID: URL] = [:]) {
        ensureDynamicProfilesDirectory()

        let profileFile = dynamicProfilesPath.appendingPathComponent("iTermGUI.json")
        var existingProfiles: [[String: Any]] = []

        if let existingData = try? fileStore.read(profileFile),
           let existingJson = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any],
           let profiles = existingJson["Profiles"] as? [[String: Any]] {
            existingProfiles = profiles
        }

        for profile in profiles {
            let dynamicProfile = createITerm2Profile(from: profile, passwordFile: passwordFiles[profile.id])
            existingProfiles.removeAll { ($0["Guid"] as? String) == profile.id.uuidString }
            existingProfiles.append(dynamicProfile)
        }

        let profileData = ["Profiles": existingProfiles]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: profileData, options: .prettyPrinted)
            try fileStore.write(jsonData, to: profileFile)
            cleanupOldProfileFiles()
        } catch {
            print("Error updating dynamic profiles: \(error)")
        }
    }

    private func cleanupOldProfileFiles() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: dynamicProfilesPath, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.starts(with: "iTermGUI-") && file.lastPathComponent.hasSuffix(".json") && file.lastPathComponent != "iTermGUI.json" {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            // Ignore errors during cleanup
        }
    }

    func syncAllProfiles(_ profiles: [SSHProfile]) {
        ensureDynamicProfilesDirectory()

        var dynamicProfiles: [[String: Any]] = []
        for profile in profiles {
            dynamicProfiles.append(createITerm2Profile(from: profile))
        }

        let profileData = ["Profiles": dynamicProfiles]
        let profileFile = dynamicProfilesPath.appendingPathComponent("iTermGUI.json")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: profileData, options: .prettyPrinted)
            try fileStore.write(jsonData, to: profileFile)
            cleanupOldProfileFiles()
        } catch {
            print("Error syncing profiles: \(error)")
        }
    }

    func buildSSHCommand(from profile: SSHProfile) -> String {
        return (["ssh"] + sshArguments(for: profile)).joined(separator: " ")
    }

    /// All arguments after the `ssh` program name, in the same order
    /// `buildSSHCommand` emits them. Shared by the iTerm2 launch path and the
    /// SSH_ASKPASS wrapper builder.
    func sshArguments(for profile: SSHProfile) -> [String] {
        var args: [String] = []

        if !profile.username.isEmpty {
            args.append("\(profile.username)@\(profile.host)")
        } else {
            args.append(profile.host)
        }

        if profile.port != 22 {
            args.append(contentsOf: ["-p", "\(profile.port)"])
        }

        if let keyPath = profile.privateKeyPath ?? profile.identityFile {
            args.append(contentsOf: ["-i", keyPath])
        }

        if let jumpHost = profile.jumpHost {
            args.append(contentsOf: ["-J", jumpHost])
        }

        for forward in profile.localForwards {
            args.append(contentsOf: ["-L", "\(forward.localPort):\(forward.remoteHost):\(forward.remotePort)"])
        }

        for forward in profile.remoteForwards {
            args.append(contentsOf: ["-R", "\(forward.localPort):\(forward.remoteHost):\(forward.remotePort)"])
        }

        if profile.compression {
            args.append("-C")
        }

        if !profile.strictHostKeyChecking {
            args.append(contentsOf: ["-o", "StrictHostKeyChecking=no"])
        }

        args.append(contentsOf: ["-o", "ConnectTimeout=\(profile.connectionTimeout)"])
        args.append(contentsOf: ["-o", "ServerAliveInterval=\(profile.serverAliveInterval)"])

        return args
    }

    func createITerm2Profile(from profile: SSHProfile, passwordFile: URL? = nil) -> [String: Any] {
        let command: String
        if let passwordFile {
            command = passwordHelper.iTerm2Command(passwordFile: passwordFile, sshArguments: sshArguments(for: profile))
        } else {
            command = buildSSHCommand(from: profile)
        }

        var initialText = ""
        if !profile.customCommands.isEmpty {
            initialText = profile.customCommands.joined(separator: "; ") + "\n"
        }

        var iterm2Profile: [String: Any] = [
            "Name": profile.name,
            "Guid": profile.id.uuidString,
            "Title Components": 64,  // 64 = Profile Name component
            "Custom Command": "Yes",
            "Command": command,
            "Tags": Array(profile.tags),
            "Badge Text": profile.host,
            "Initial Text": initialText,
            "Normal Font": "\(profile.terminalSettings.fontFamily) \(profile.terminalSettings.fontSize)",
            "Scrollback Lines": profile.terminalSettings.scrollbackLines,
            "Close Sessions On End": true,
            "Terminal Type": "xterm-256color",
            "Columns": 200,
            "Rows": 50
        ]

        switch profile.terminalSettings.cursorStyle {
        case .block:
            iterm2Profile["Cursor Type"] = 2
        case .bar:
            iterm2Profile["Cursor Type"] = 1
        case .underline:
            iterm2Profile["Cursor Type"] = 0
        }

        if let colorScheme = getColorScheme(named: profile.terminalSettings.colorScheme) {
            iterm2Profile.merge(colorScheme) { _, new in new }
        }

        return iterm2Profile
    }

    func launchScriptForProfile(_ profileName: String, newWindow: Bool) -> String {
        """
        tell application "iTerm"
            -- Check if iTerm is already running
            set isRunning to (application "iTerm" is running)

            -- If not running, just create window without activate
            if not isRunning then
                -- Launch iTerm without default window
                launch
                -- Wait a moment for iTerm to initialize
                delay 0.5
                -- Close any default window that might have opened
                if (count of windows) > 0 then
                    close first window
                end if
            end if

            -- Force reload of dynamic profiles
            tell application "System Events"
                tell process "iTerm2"
                    -- This triggers iTerm2 to reload dynamic profiles
                end tell
            end tell

            -- Small delay to ensure profiles are loaded
            delay 0.1

            -- Now create our desired window/tab
            if \(newWindow) or (count of windows) = 0 then
                set newWindow to (create window with profile "\(profileName)")
                tell newWindow
                    tell current session
                        set columns to 200
                        set rows to 50
                        set name to "\(profileName)"
                    end tell
                end tell
            else
                tell current window
                    create tab with profile "\(profileName)"
                    tell current session
                        set columns to 200
                        set rows to 50
                        set name to "\(profileName)"
                    end tell
                end tell
            end if

            -- Activate after creating our window
            activate
        end tell
        """
    }

    func launchScriptForTabs(_ profileNames: [String]) -> String {
        """
        tell application "iTerm"
            -- Check if iTerm is already running
            set isRunning to (application "iTerm" is running)

            -- If not running, just create window without activate
            if not isRunning then
                -- Launch iTerm without default window
                launch
                -- Wait a moment for iTerm to initialize
                delay 0.5
                -- Close any default window that might have opened
                if (count of windows) > 0 then
                    close first window
                end if
            end if

            -- Force reload of dynamic profiles
            tell application "System Events"
                tell process "iTerm2"
                    -- This triggers iTerm2 to reload dynamic profiles
                end tell
            end tell

            -- Small delay to ensure profiles are loaded
            delay 0.1

            -- Create new window with first profile
            set newWindow to (create window with profile "\(profileNames[0])")
            tell newWindow
                tell current session
                    set columns to 200
                    set rows to 50
                    set name to "\(profileNames[0])"
                end tell
            end tell

            -- Add remaining profiles as tabs
            \(profileNames.dropFirst().map { profileName in
                """
                tell newWindow
                    set newTab to (create tab with profile "\(profileName)")
                    tell newTab
                        tell current session
                            set columns to 200
                            set rows to 50
                            set name to "\(profileName)"
                        end tell
                    end tell
                end tell
                """
            }.joined(separator: "\n            "))

            -- Select first tab
            tell newWindow
                select tab 1
            end tell

            -- Activate after creating our windows
            activate
        end tell
        """
    }

    func launchScriptForLocalhost() -> String {
        """
        tell application "iTerm"
            -- Check if iTerm is already running
            set isRunning to (application "iTerm" is running)

            -- If not running, launch iTerm
            if not isRunning then
                launch
                delay 0.5
            end if

            -- Create new window or tab for localhost
            if (count of windows) = 0 then
                set newWindow to (create window with default profile)
                tell newWindow
                    tell current session
                        set name to "Localhost"
                    end tell
                end tell
            else
                tell current window
                    set newTab to (create tab with default profile)
                    tell newTab
                        tell current session
                            set name to "Localhost"
                        end tell
                    end tell
                end tell
            end if

            -- Activate iTerm
            activate
        end tell
        """
    }

    private func runScript(_ source: String) {
        switch scriptRunner.run(source: source) {
        case .success:
            break
        case .failure(let err):
            print("AppleScript error: \(err.message)")
        }
    }

    private func ensureDynamicProfilesDirectory() {
        try? fileStore.createDirectory(at: dynamicProfilesPath)
    }

    func getColorScheme(named name: String) -> [String: Any]? {
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

    func openLocalhost() {
        runScript(launchScriptForLocalhost())
    }

    func buildTestConnectionLaunch(for profile: SSHProfile) -> ProcessLaunch {
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

        return ProcessLaunch(launchPath: "/usr/bin/ssh", arguments: arguments)
    }

    func testConnection(profile: SSHProfile, completion: @escaping (Bool, String?) -> Void) {
        processRunner.run(buildTestConnectionLaunch(for: profile)) { result in
            switch result {
            case .success(let procResult):
                if procResult.isSuccess {
                    completion(true, nil)
                } else {
                    completion(false, procResult.stdoutString + procResult.stderrString)
                }
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }
}
