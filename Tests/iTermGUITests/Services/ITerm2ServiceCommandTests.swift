import Foundation
import Testing
@testable import iTermGUI

@Suite("ITerm2Service.buildSSHCommand")
struct ITerm2ServiceBuildSSHCommandTests {
    private func service() -> ITerm2Service { makeStubITerm2Service() }

    @Test func allFlagsInCorrectOrder() {
        let profile = makeProfile(
            host: "h", port: 2222, username: "u",
            privateKeyPath: "/k",
            jumpHost: "j",
            localForwards: [PortForward(localPort: 8080, remoteHost: "r", remotePort: 80)],
            remoteForwards: [PortForward(localPort: 9090, remoteHost: "api", remotePort: 9000)],
            strictHostKeyChecking: false,
            compression: true,
            connectionTimeout: 15,
            serverAliveInterval: 10
        )
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd == "ssh u@h -p 2222 -i /k -J j -L 8080:r:80 -R 9090:api:9000 -C -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o ServerAliveInterval=10")
    }

    @Test func minimalProfileProducesShortestCommand() {
        let profile = makeProfile(host: "h", username: "")
        #expect(service().buildSSHCommand(from: profile) ==
                "ssh h -o ConnectTimeout=30 -o ServerAliveInterval=60")
    }

    @Test func usernamePresentIncludesUserHost() {
        let profile = makeProfile(host: "h", username: "alex")
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains("ssh alex@h"))
    }

    @Test func portOmittedWhenDefault() {
        let profile = makeProfile(host: "h", port: 22, username: "u")
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -p ") == false)
    }

    @Test func portIncludedWhenNonDefault() {
        let profile = makeProfile(host: "h", port: 2022, username: "u")
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -p 2022"))
    }

    @Test func compressionFlagOmittedWhenFalse() {
        let profile = makeProfile(host: "h", username: "u", compression: false)
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -C") == false)
    }

    @Test func compressionFlagIncludedWhenTrue() {
        let profile = makeProfile(host: "h", username: "u", compression: true)
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -C"))
    }

    @Test func strictHostKeyCheckingFlagOmittedWhenTrue() {
        let profile = makeProfile(host: "h", username: "u", strictHostKeyChecking: true)
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains("StrictHostKeyChecking") == false)
    }

    @Test func strictHostKeyCheckingFlagIncludedWhenFalse() {
        let profile = makeProfile(host: "h", username: "u", strictHostKeyChecking: false)
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -o StrictHostKeyChecking=no"))
    }

    @Test func privateKeyPathTakesPrecedenceOverIdentityFile() {
        let profile = makeProfile(host: "h", username: "u",
                                   privateKeyPath: "/primary",
                                   identityFile: "/alt")
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -i /primary"))
        #expect(cmd.contains("/alt") == false)
    }

    @Test func identityFileUsedWhenPrivateKeyPathNil() {
        let profile = makeProfile(host: "h", username: "u",
                                   privateKeyPath: nil,
                                   identityFile: "/fallback")
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -i /fallback"))
    }

    @Test func connectionTimeoutAndServerAliveAlwaysPresent() {
        let profile = makeProfile(host: "h", username: "u",
                                   connectionTimeout: 5, serverAliveInterval: 120)
        let cmd = service().buildSSHCommand(from: profile)
        #expect(cmd.contains(" -o ConnectTimeout=5"))
        #expect(cmd.contains(" -o ServerAliveInterval=120"))
    }

    @Test func multipleLocalForwardsInOrder() {
        let forwards = [
            PortForward(localPort: 1, remoteHost: "a", remotePort: 10),
            PortForward(localPort: 2, remoteHost: "b", remotePort: 20),
            PortForward(localPort: 3, remoteHost: "c", remotePort: 30),
        ]
        let profile = makeProfile(host: "h", username: "u", localForwards: forwards)
        let cmd = service().buildSSHCommand(from: profile)
        let idx1 = cmd.range(of: "-L 1:a:10")!.lowerBound
        let idx2 = cmd.range(of: "-L 2:b:20")!.lowerBound
        let idx3 = cmd.range(of: "-L 3:c:30")!.lowerBound
        #expect(idx1 < idx2)
        #expect(idx2 < idx3)
    }
}

@Suite("ITerm2Service.buildTestConnectionLaunch")
struct ITerm2TestConnectionLaunchTests {
    @Test func includesBatchModeAndConnectTimeout5() {
        let svc = makeStubITerm2Service()
        let launch = svc.buildTestConnectionLaunch(for: makeProfile(host: "h", username: "u"))
        #expect(launch.launchPath == "/usr/bin/ssh")
        #expect(launch.arguments.contains("BatchMode=yes"))
        #expect(launch.arguments.contains("ConnectTimeout=5"))
    }

    @Test func includesEchoTestCommand() {
        let svc = makeStubITerm2Service()
        let launch = svc.buildTestConnectionLaunch(for: makeProfile(host: "h", username: "u"))
        #expect(launch.arguments.last == "echo 'Connection successful'")
    }

    @Test func includesNonDefaultPort() {
        let svc = makeStubITerm2Service()
        let launch = svc.buildTestConnectionLaunch(for: makeProfile(host: "h", port: 443, username: "u"))
        #expect(launch.arguments.contains("-p"))
        #expect(launch.arguments.contains("443"))
    }

    @Test func omitsPortFlagForDefault() {
        let svc = makeStubITerm2Service()
        let launch = svc.buildTestConnectionLaunch(for: makeProfile(host: "h", port: 22, username: "u"))
        #expect(launch.arguments.contains("-p") == false)
    }

    @Test func usesBareHostWhenUsernameEmpty() {
        let svc = makeStubITerm2Service()
        let launch = svc.buildTestConnectionLaunch(for: makeProfile(host: "h", username: ""))
        #expect(launch.arguments.contains("h"))
        #expect(launch.arguments.contains(where: { $0.contains("@") }) == false)
    }
}

@Suite("ITerm2Service.testConnection via FakeProcessRunner")
struct ITerm2TestConnectionRunnerTests {
    @Test func successCallsCompletionWithTrueNil() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(stdout: "Connection successful\n", exitCode: 0)
        let svc = makeStubITerm2Service(processRunner: runner)

        await withCheckedContinuation { cont in
            svc.testConnection(profile: makeProfile()) { success, error in
                #expect(success)
                #expect(error == nil)
                cont.resume()
            }
        }
    }

    @Test func nonZeroExitCodeReturnsFailure() async {
        let runner = FakeProcessRunner()
        runner.defaultResult = FakeProcessRunner.success(stderr: "connection refused", exitCode: 255)
        let svc = makeStubITerm2Service(processRunner: runner)

        await withCheckedContinuation { cont in
            svc.testConnection(profile: makeProfile()) { success, error in
                #expect(success == false)
                #expect(error != nil)
                cont.resume()
            }
        }
    }

    @Test func failureFromRunnerPropagatesAsFalseWithMessage() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "boom" }
        }
        let runner = FakeProcessRunner()
        runner.defaultResult = .failure(Boom())
        let svc = makeStubITerm2Service(processRunner: runner)

        await withCheckedContinuation { cont in
            svc.testConnection(profile: makeProfile()) { success, error in
                #expect(success == false)
                #expect(error == "boom")
                cont.resume()
            }
        }
    }
}
