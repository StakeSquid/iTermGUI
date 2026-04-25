import Foundation

/// Auto-types stored SSH passwords by leaning on OpenSSH's built-in
/// `SSH_ASKPASS` mechanism. With `SSH_ASKPASS_REQUIRE=force`, ssh always
/// invokes our small askpass helper when it needs a password or passphrase;
/// the helper reads the password from a single-use 0600 file and prints it on
/// stdout, then removes the file so it can't be reused.
final class SSHPasswordHelper {
    static let shared = SSHPasswordHelper()

    /// Bumped whenever `scriptContent` changes so existing installs are refreshed.
    static let scriptVersion = "1"

    /// Env var used by the helper script to find the staged password file.
    static let askpassFileEnvVar = "ITERMGUI_ASKPASS_FILE"

    static let scriptContent: String = """
    #!/bin/sh
    # iTermGUI SSH askpass helper (v\(scriptVersion))
    #
    # ssh invokes this program when SSH_ASKPASS / SSH_ASKPASS_REQUIRE=force is
    # set. It writes the password (read from the file referenced by
    # $\(askpassFileEnvVar)) to stdout and then deletes the file so it can't
    # be reused. ssh's prompt text is passed in $1 and ignored.
    set -u
    file="${\(askpassFileEnvVar):-}"
    if [ -n "$file" ] && [ -f "$file" ]; then
        cat -- "$file"
        rm -f -- "$file"
    fi
    """

    private let rootDirectory: URL
    private let fileManager: FileManager

    var scriptURL: URL {
        rootDirectory.appendingPathComponent("ssh_askpass_helper.sh")
    }

    var passwordsDirectory: URL {
        rootDirectory.appendingPathComponent("password_inbox")
    }

    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.init(rootDirectory: appSupport.appendingPathComponent("iTermGUI"))
    }

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    /// Materializes the helper script and locks down the staging directory.
    /// Idempotent — only writes when the on-disk content differs.
    @discardableResult
    func ensureInstalled() -> Bool {
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: passwordsDirectory, withIntermediateDirectories: true, attributes: nil)
            try? fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o700))],
                ofItemAtPath: passwordsDirectory.path
            )

            let needsWrite: Bool = {
                guard fileManager.fileExists(atPath: scriptURL.path) else { return true }
                guard let existing = try? String(contentsOf: scriptURL, encoding: .utf8) else { return true }
                return existing != Self.scriptContent
            }()

            if needsWrite {
                try Self.scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            }

            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o700))],
                ofItemAtPath: scriptURL.path
            )
            return true
        } catch {
            print("SSHPasswordHelper.ensureInstalled failed: \(error)")
            return false
        }
    }

    /// Writes `password` to a one-shot 0600 file and returns its URL. The
    /// askpass script deletes the file as soon as it reads the password.
    func stagePassword(_ password: String) -> URL? {
        guard ensureInstalled() else { return nil }
        guard let data = password.data(using: .utf8) else { return nil }
        let fileURL = passwordsDirectory.appendingPathComponent("pw-\(UUID().uuidString)")
        do {
            try data.write(to: fileURL, options: [.atomic])
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))],
                ofItemAtPath: fileURL.path
            )
            return fileURL
        } catch {
            print("SSHPasswordHelper.stagePassword failed: \(error)")
            return nil
        }
    }

    /// Removes any password files left over from a crashed launch. Called on
    /// app start as defense-in-depth.
    func cleanupStalePasswordFiles(olderThan: TimeInterval = 60) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: passwordsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-olderThan)
        for url in entries {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, modified < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Builds the iTerm2 dynamic-profile "Command" string. Wraps `ssh` in
    /// `/usr/bin/env` so the askpass env vars are set for the ssh process
    /// without depending on a specific shell.
    func iTerm2Command(passwordFile: URL, sshArguments: [String]) -> String {
        var parts: [String] = [
            shellQuote("/usr/bin/env"),
            shellQuote("SSH_ASKPASS=\(scriptURL.path)"),
            shellQuote("SSH_ASKPASS_REQUIRE=force"),
            shellQuote("\(Self.askpassFileEnvVar)=\(passwordFile.path)"),
            shellQuote("/usr/bin/ssh"),
        ]
        parts.append(contentsOf: sshArguments.map(shellQuote))
        return parts.joined(separator: " ")
    }

    /// Returns the env-var entries to add when launching ssh from the embedded
    /// terminal. Caller merges them into the inherited environment.
    func embeddedEnvironment(passwordFile: URL) -> [String: String] {
        return [
            "SSH_ASKPASS": scriptURL.path,
            "SSH_ASKPASS_REQUIRE": "force",
            Self.askpassFileEnvVar: passwordFile.path,
        ]
    }

    private func shellQuote(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
