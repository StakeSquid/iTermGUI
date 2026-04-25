import Foundation
import Testing
@testable import iTermGUI

@Suite("SSHPasswordHelper.ensureInstalled")
struct SSHPasswordHelperEnsureInstalledTests {
    @Test func installsScriptAndDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        #expect(helper.ensureInstalled() == true)

        #expect(FileManager.default.fileExists(atPath: helper.scriptURL.path))
        #expect(FileManager.default.fileExists(atPath: helper.passwordsDirectory.path))
    }

    @Test func scriptIsExecutableForOwnerOnly() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        helper.ensureInstalled()

        let attrs = try FileManager.default.attributesOfItem(atPath: helper.scriptURL.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        #expect(perms == 0o700)
    }

    @Test func passwordsDirectoryHasOwnerOnlyPermissions() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        helper.ensureInstalled()

        let attrs = try FileManager.default.attributesOfItem(atPath: helper.passwordsDirectory.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        #expect(perms == 0o700)
    }

    @Test func rewritesScriptIfContentChanged() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        helper.ensureInstalled()
        try "stale content".write(to: helper.scriptURL, atomically: true, encoding: .utf8)

        helper.ensureInstalled()

        let content = try String(contentsOf: helper.scriptURL, encoding: .utf8)
        #expect(content == SSHPasswordHelper.scriptContent)
    }

    @Test func scriptStartsWithShebang() {
        #expect(SSHPasswordHelper.scriptContent.hasPrefix("#!/bin/sh"))
    }

    @Test func scriptReadsFromEnvVar() {
        #expect(SSHPasswordHelper.scriptContent.contains(SSHPasswordHelper.askpassFileEnvVar))
    }

    @Test func scriptDeletesFileAfterReading() {
        // The helper must remove the file after cat'ing it so the password
        // can't be reused if ssh re-prompts.
        #expect(SSHPasswordHelper.scriptContent.contains("rm -f"))
        #expect(SSHPasswordHelper.scriptContent.contains("cat --"))
    }
}

@Suite("SSHPasswordHelper.stagePassword")
struct SSHPasswordHelperStageTests {
    @Test func writesPasswordContents() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        let url = try #require(helper.stagePassword("hunter2"))
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == "hunter2")
    }

    @Test func fileIsOwnerOnlyReadable() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        let url = try #require(helper.stagePassword("hunter2"))
        defer { try? FileManager.default.removeItem(at: url) }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        #expect(perms == 0o600)
    }

    @Test func eachInvocationReturnsADistinctPath() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        let a = try #require(helper.stagePassword("a"))
        let b = try #require(helper.stagePassword("b"))
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }

        #expect(a != b)
    }

    @Test func stagedFileLivesInsidePasswordsDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        let url = try #require(helper.stagePassword("x"))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.deletingLastPathComponent().standardizedFileURL == helper.passwordsDirectory.standardizedFileURL)
    }
}

@Suite("SSHPasswordHelper.cleanupStalePasswordFiles")
struct SSHPasswordHelperCleanupTests {
    @Test func removesFilesOlderThanThreshold() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        helper.ensureInstalled()

        let oldFile = helper.passwordsDirectory.appendingPathComponent("pw-old")
        try "x".data(using: .utf8)!.write(to: oldFile)
        let oldDate = Date().addingTimeInterval(-3600)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFile.path)

        helper.cleanupStalePasswordFiles(olderThan: 60)

        #expect(FileManager.default.fileExists(atPath: oldFile.path) == false)
    }

    @Test func keepsFreshFiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        let fresh = try #require(helper.stagePassword("fresh"))

        helper.cleanupStalePasswordFiles(olderThan: 60)

        #expect(FileManager.default.fileExists(atPath: fresh.path))
        try? FileManager.default.removeItem(at: fresh)
    }
}

@Suite("SSHPasswordHelper.iTerm2Command")
struct SSHPasswordHelperITermCommandTests {
    private func makeHelper() -> (SSHPasswordHelper, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        return (SSHPasswordHelper(rootDirectory: root), root)
    }

    @Test func wrapsCommandInEnv() {
        let (helper, root) = makeHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let pwFile = helper.passwordsDirectory.appendingPathComponent("pw-fake")
        let cmd = helper.iTerm2Command(passwordFile: pwFile, sshArguments: ["user@host"])

        #expect(cmd.hasPrefix("'/usr/bin/env'"))
        #expect(cmd.contains("'SSH_ASKPASS_REQUIRE=force'"))
        #expect(cmd.contains("'/usr/bin/ssh'"))
        #expect(cmd.contains("'user@host'"))
    }

    @Test func referencesScriptAndPasswordFile() {
        let (helper, root) = makeHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let pwFile = helper.passwordsDirectory.appendingPathComponent("pw-fake")
        let cmd = helper.iTerm2Command(passwordFile: pwFile, sshArguments: ["host"])

        #expect(cmd.contains(helper.scriptURL.path))
        #expect(cmd.contains(pwFile.path))
        #expect(cmd.contains("SSH_ASKPASS=\(helper.scriptURL.path)"))
        #expect(cmd.contains("\(SSHPasswordHelper.askpassFileEnvVar)=\(pwFile.path)"))
    }

    @Test func quotesArgumentsContainingSingleQuotes() {
        let (helper, root) = makeHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let pwFile = helper.passwordsDirectory.appendingPathComponent("pw-fake")
        let cmd = helper.iTerm2Command(passwordFile: pwFile, sshArguments: ["it's-fine@host"])
        // Single quotes in the arg must be escaped as '\''
        #expect(cmd.contains("'it'\\''s-fine@host'"))
    }

    @Test func appendsSSHArgsInOrder() {
        let (helper, root) = makeHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let pwFile = helper.passwordsDirectory.appendingPathComponent("pw-fake")
        let cmd = helper.iTerm2Command(passwordFile: pwFile, sshArguments: ["u@h", "-p", "2222", "-i", "/k"])
        let userIdx = cmd.range(of: "'u@h'")!.lowerBound
        let portIdx = cmd.range(of: "'2222'")!.lowerBound
        let keyIdx = cmd.range(of: "'/k'")!.lowerBound
        #expect(userIdx < portIdx)
        #expect(portIdx < keyIdx)
    }
}

@Suite("SSHPasswordHelper.embeddedEnvironment")
struct SSHPasswordHelperEmbeddedEnvTests {
    @Test func includesAllThreeEnvVars() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let helper = SSHPasswordHelper(rootDirectory: root)

        let pwFile = helper.passwordsDirectory.appendingPathComponent("pw-fake")
        let env = helper.embeddedEnvironment(passwordFile: pwFile)

        #expect(env["SSH_ASKPASS"] == helper.scriptURL.path)
        #expect(env["SSH_ASKPASS_REQUIRE"] == "force")
        #expect(env[SSHPasswordHelper.askpassFileEnvVar] == pwFile.path)
    }
}

@Suite("SSHPasswordHelper end-to-end script behavior")
struct SSHPasswordHelperScriptBehaviorTests {
    /// Runs the materialized askpass script in a real shell and checks that
    /// it prints the password and removes the file. This validates the script
    /// content rather than just its substrings.
    @Test func scriptPrintsPasswordAndDeletesFile() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        let pwFile = try #require(helper.stagePassword("topsecret"))

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = [helper.scriptURL.path, "ignored prompt"]
        var env = ProcessInfo.processInfo.environment
        env[SSHPasswordHelper.askpassFileEnvVar] = pwFile.path
        task.environment = env
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()

        let stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        #expect(stdout == "topsecret")
        #expect(FileManager.default.fileExists(atPath: pwFile.path) == false)
    }

    @Test func scriptIsSilentWhenEnvVarMissing() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let helper = SSHPasswordHelper(rootDirectory: root)
        helper.ensureInstalled()

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = [helper.scriptURL.path, "prompt"]
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: SSHPasswordHelper.askpassFileEnvVar)
        task.environment = env
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(stdout.isEmpty)
        #expect(task.terminationStatus == 0)
    }
}
