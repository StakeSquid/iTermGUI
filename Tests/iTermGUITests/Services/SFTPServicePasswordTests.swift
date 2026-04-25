import Foundation
import Testing
@testable import iTermGUI

private func makeServiceWithIsolatedHelper(
    runner: FakeProcessRunner = FakeProcessRunner()
) -> (SFTPService, SSHPasswordHelper, URL) {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("itermgui-tests-\(UUID().uuidString)")
    let helper = SSHPasswordHelper(rootDirectory: root)
    let svc = SFTPService(
        processRunner: runner,
        fileStore: InMemoryProfileFileStore(),
        passwordHelper: helper
    )
    return (svc, helper, root)
}

@Suite("SFTPService.sshAuth")
struct SFTPSSHAuthTests {
    @Test func pubkeyProfileGetsBatchModeAndNoEnv() {
        let (svc, _, root) = makeServiceWithIsolatedHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .publicKey, password: nil)
        let auth = svc.sshAuth(for: profile)
        #expect(auth.extraOptions == ["-o", "BatchMode=yes"])
        #expect(auth.environment == nil)
    }

    @Test func passwordProfileWithoutStoredPasswordFallsBackToBatchMode() {
        let (svc, _, root) = makeServiceWithIsolatedHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .password, password: nil)
        let auth = svc.sshAuth(for: profile)
        #expect(auth.extraOptions == ["-o", "BatchMode=yes"])
        #expect(auth.environment == nil)
    }

    @Test func passwordProfileWithPasswordGetsAskpassEnvAndNoBatchMode() {
        let (svc, helper, root) = makeServiceWithIsolatedHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .password, password: "secret")
        let auth = svc.sshAuth(for: profile)

        #expect(auth.extraOptions.isEmpty)
        let env = try! #require(auth.environment)
        #expect(env["SSH_ASKPASS"] == helper.scriptURL.path)
        #expect(env["SSH_ASKPASS_REQUIRE"] == "force")
        let pwFilePath = try! #require(env[SSHPasswordHelper.askpassFileEnvVar])
        // The staged file lives inside the helper's password_inbox.
        #expect(URL(fileURLWithPath: pwFilePath).deletingLastPathComponent().standardizedFileURL
                == helper.passwordsDirectory.standardizedFileURL)
    }

    @Test func twoCallsStageDistinctPasswordFiles() {
        let (svc, _, root) = makeServiceWithIsolatedHelper()
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .password, password: "secret")
        let a = svc.sshAuth(for: profile).environment?[SSHPasswordHelper.askpassFileEnvVar]
        let b = svc.sshAuth(for: profile).environment?[SSHPasswordHelper.askpassFileEnvVar]
        #expect(a != nil)
        #expect(b != nil)
        #expect(a != b)
    }
}

@Suite("SFTPService launches use askpass env for password profiles")
struct SFTPLaunchEnvironmentTests {
    @Test func listFilesUsesAskpassEnvForPasswordProfile() async {
        let runner = FakeProcessRunner()
        let (svc, _, root) = makeServiceWithIsolatedHelper(runner: runner)
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .password, password: "pw")
        await withCheckedContinuation { cont in
            svc.listFiles(at: "/tmp", location: .server(profile)) { _ in cont.resume() }
        }
        #expect(runner.invocations.count == 1)
        let env = try! #require(runner.invocations.first?.launch.environment)
        #expect(env["SSH_ASKPASS_REQUIRE"] == "force")
    }

    @Test func listFilesUsesBatchModeForPubkeyProfile() async {
        let runner = FakeProcessRunner()
        let (svc, _, root) = makeServiceWithIsolatedHelper(runner: runner)
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .publicKey, privateKeyPath: "/k")
        await withCheckedContinuation { cont in
            svc.listFiles(at: "/tmp", location: .server(profile)) { _ in cont.resume() }
        }
        let invocation = try! #require(runner.invocations.first)
        #expect(invocation.launch.environment == nil)
        #expect(invocation.launch.arguments.contains("BatchMode=yes"))
    }

    @Test func deleteFileSetsAskpassEnvForPasswordProfile() async {
        let runner = FakeProcessRunner()
        let (svc, _, root) = makeServiceWithIsolatedHelper(runner: runner)
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .password, password: "pw")
        await withCheckedContinuation { cont in
            svc.deleteFile(at: "/tmp/f", location: .server(profile)) { _ in cont.resume() }
        }
        let env = try! #require(runner.invocations.first?.launch.environment)
        #expect(env["SSH_ASKPASS_REQUIRE"] == "force")
        // No BatchMode=yes when askpass is in play.
        #expect(runner.invocations.first?.launch.arguments.contains("BatchMode=yes") == false)
    }

    @Test func createDirectoryUsesAskpassForPasswordProfile() async {
        let runner = FakeProcessRunner()
        let (svc, _, root) = makeServiceWithIsolatedHelper(runner: runner)
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .password, password: "pw")
        await withCheckedContinuation { cont in
            svc.createDirectory(at: "/tmp/new", location: .server(profile)) { _ in cont.resume() }
        }
        let env = try! #require(runner.invocations.first?.launch.environment)
        #expect(env["SSH_ASKPASS_REQUIRE"] == "force")
    }

    @Test func fileExistsBatchUsesAskpassForPasswordProfile() async {
        let runner = FakeProcessRunner()
        let (svc, _, root) = makeServiceWithIsolatedHelper(runner: runner)
        defer { try? FileManager.default.removeItem(at: root) }

        let profile = makeProfile(authMethod: .password, password: "pw")
        await withCheckedContinuation { cont in
            svc.fileExistsBatch(paths: ["/tmp/a"], location: .server(profile)) { _ in cont.resume() }
        }
        let env = try! #require(runner.invocations.first?.launch.environment)
        #expect(env["SSH_ASKPASS_REQUIRE"] == "force")
    }
}
