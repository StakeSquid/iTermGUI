import Foundation
import Testing
@testable import iTermGUI

@Suite("SFTPService.listFiles via mocked ProcessRunner")
struct SFTPListRemoteFilesViaRunnerTests {
    @Test func successfulOutputParsesFiles() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(stdout: """
        d|bin|0|0
        f|hello.txt|100|1700000000
        """, exitCode: 0)
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        let files: [RemoteFile] = await withCheckedContinuation { cont in
            svc.listFiles(at: "/tmp", location: .server(makeProfile())) { result in
                switch result {
                case .success(let files): cont.resume(returning: files)
                case .failure: cont.resume(returning: [])
                }
            }
        }

        #expect(files.count == 2)
        // dirs first
        #expect(files[0].isDirectory)
        #expect(files[0].name == "bin")
        #expect(files[1].name == "hello.txt")
    }

    @Test func nonZeroExitPropagatesAsFailureWithStderr() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(stderr: "Connection refused", exitCode: 255)
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        let err: Error? = await withCheckedContinuation { cont in
            svc.listFiles(at: "/tmp", location: .server(makeProfile())) { result in
                switch result {
                case .success: cont.resume(returning: nil)
                case .failure(let e): cont.resume(returning: e)
                }
            }
        }

        #expect(err != nil)
        #expect((err as NSError?)?.localizedDescription.contains("Connection refused") == true)
    }

    @Test func runnerFailurePropagates() async {
        struct Boom: Error {}
        let runner = FakeProcessRunner()
        runner.defaultResult = .failure(Boom())
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        let failed: Bool = await withCheckedContinuation { cont in
            svc.listFiles(at: "/tmp", location: .server(makeProfile())) { result in
                switch result {
                case .success: cont.resume(returning: false)
                case .failure: cont.resume(returning: true)
                }
            }
        }

        #expect(failed)
    }

    @Test func invocationIncludesExpectedSSHArgs() async throws {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success()
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        _ = await withCheckedContinuation { cont in
            svc.listFiles(at: "/tmp", location: .server(makeProfile(host: "h", username: "u"))) { _ in
                cont.resume()
            }
        }

        let inv = try #require(runner.invocations.first)
        #expect(inv.launch.launchPath == "/usr/bin/ssh")
        #expect(inv.launch.arguments.contains("u@h"))
        // command is last argument
        let lastArg = try #require(inv.launch.arguments.last)
        #expect(lastArg.contains("TARGET_DIR"))
    }
}

@Suite("SFTPService.createDirectory via mocked ProcessRunner")
struct SFTPCreateDirectoryRemoteTests {
    @Test func remoteSuccessReportsTrue() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(exitCode: 0)
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        let ok: Bool = await withCheckedContinuation { cont in
            svc.createDirectory(at: "/tmp/new", location: .server(makeProfile())) { success in
                cont.resume(returning: success)
            }
        }
        #expect(ok)
    }

    @Test func remoteFailureReportsFalse() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(exitCode: 1)
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        let ok: Bool = await withCheckedContinuation { cont in
            svc.createDirectory(at: "/tmp/new", location: .server(makeProfile())) { success in
                cont.resume(returning: success)
            }
        }
        #expect(ok == false)
    }

    @Test func remoteRunnerFailureReportsFalse() async {
        struct Boom: Error {}
        let runner = FakeProcessRunner()
        runner.defaultResult = .failure(Boom())
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        let ok: Bool = await withCheckedContinuation { cont in
            svc.createDirectory(at: "/tmp/new", location: .server(makeProfile())) { success in
                cont.resume(returning: success)
            }
        }
        #expect(ok == false)
    }
}

@Suite("SFTPService.transferFile updates @Published transfers")
struct SFTPTransferFilePublishingTests {
    @MainActor
    @Test func directoryTransferAppendsToTransfersList() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(exitCode: 0)
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        svc.transferFile(
            from: "/src",
            sourceLocation: .localhost,
            to: "/dst",
            destinationLocation: .server(makeProfile()),
            isDirectory: true
        )

        // Sync dispatched append - wait a tick
        try? await Task.sleep(for: .milliseconds(50))

        #expect(svc.transfers.count == 1)
        #expect(svc.transfers[0].isDirectory)
        #expect(svc.transfers[0].sourcePath == "/src")
        #expect(svc.transfers[0].destinationPath == "/dst")
    }
}

@Suite("SFTPService.deleteFile via mocked ProcessRunner")
struct SFTPDeleteRemoteTests {
    @Test func remoteSuccessReportsTrue() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(exitCode: 0)
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        let ok: Bool = await withCheckedContinuation { cont in
            svc.deleteFile(at: "/tmp/x", location: .server(makeProfile())) { success in
                cont.resume(returning: success)
            }
        }
        #expect(ok)
    }

    @Test func invocationArgumentsIncludeBuildDeleteCommand() async throws {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success()
        let svc = SFTPService(processRunner: runner, fileStore: InMemoryProfileFileStore())

        _ = await withCheckedContinuation { cont in
            svc.deleteFile(at: "~/target", location: .server(makeProfile(host: "h", username: "u"))) { _ in
                cont.resume()
            }
        }

        let firstInv = try #require(runner.invocations.first)
        let lastArg = try #require(firstInv.launch.arguments.last)
        #expect(lastArg == "rm -rf \"$HOME/target\"")
    }
}
