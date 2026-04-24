import Foundation
import Testing
@testable import iTermGUI

@Suite("SSHProfile.toSSHConfigEntry")
struct SSHProfileConfigEntryTests {
    @Test func includesNameAndHostnameAlways() {
        let profile = makeProfile(name: "myhost", host: "example.com", username: "")
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("Host myhost\n"))
        #expect(entry.contains("    HostName example.com\n"))
    }

    @Test func skipsPortLineWhen22() {
        let profile = makeProfile(port: 22)
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("Port") == false)
    }

    @Test func includesPortLineWhenNon22() {
        let profile = makeProfile(port: 2222)
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    Port 2222\n"))
    }

    @Test func skipsUserLineWhenEmpty() {
        let profile = makeProfile(username: "")
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    User ") == false)
    }

    @Test func includesUserLineWhenNonEmpty() {
        let profile = makeProfile(username: "alex")
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    User alex\n"))
    }

    @Test func prefersPrivateKeyPathOverIdentityFile() {
        let profile = makeProfile(
            privateKeyPath: "/primary/key",
            identityFile: "/alternate/key"
        )
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    IdentityFile /primary/key\n"))
        #expect(entry.contains("/alternate/key") == false)
    }

    @Test func fallsBackToIdentityFileWhenPrivateKeyPathNil() {
        let profile = makeProfile(
            privateKeyPath: nil,
            identityFile: "/fallback/key"
        )
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    IdentityFile /fallback/key\n"))
    }

    @Test func omitsIdentityFileWhenBothNil() {
        let profile = makeProfile(privateKeyPath: nil, identityFile: nil)
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("IdentityFile") == false)
    }

    @Test func includesProxyJumpWhenSet() {
        let profile = makeProfile(jumpHost: "bastion.example.com")
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    ProxyJump bastion.example.com\n"))
    }

    @Test func includesProxyCommandWhenSet() {
        let profile = makeProfile(proxyCommand: "nc -X connect -x proxy:3128 %h %p")
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    ProxyCommand nc -X connect -x proxy:3128 %h %p\n"))
    }

    @Test func writesLocalForwardLines() {
        let profile = makeProfile(
            localForwards: [
                PortForward(localPort: 8080, remoteHost: "web", remotePort: 80),
                PortForward(localPort: 9090, remoteHost: "api", remotePort: 9000)
            ]
        )
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    LocalForward 8080 web:80\n"))
        #expect(entry.contains("    LocalForward 9090 api:9000\n"))
    }

    @Test func writesRemoteForwardLines() {
        let profile = makeProfile(
            remoteForwards: [
                PortForward(localPort: 7000, remoteHost: "target", remotePort: 7001)
            ]
        )
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    RemoteForward 7000 target:7001\n"))
    }

    @Test func includesCompressionYesOnlyWhenTrue() {
        let withCompression = makeProfile(compression: true)
        #expect(withCompression.toSSHConfigEntry().contains("    Compression yes\n"))

        let withoutCompression = makeProfile(compression: false)
        #expect(withoutCompression.toSSHConfigEntry().contains("Compression") == false)
    }

    @Test func alwaysWritesConnectTimeoutAndServerAliveInterval() {
        let profile = makeProfile(connectionTimeout: 45, serverAliveInterval: 15)
        let entry = profile.toSSHConfigEntry()
        #expect(entry.contains("    ConnectTimeout 45\n"))
        #expect(entry.contains("    ServerAliveInterval 15\n"))
    }

    @Test func strictHostKeyCheckingMapsToYesNo() {
        let yesProfile = makeProfile(strictHostKeyChecking: true)
        #expect(yesProfile.toSSHConfigEntry().contains("    StrictHostKeyChecking yes\n"))

        let noProfile = makeProfile(strictHostKeyChecking: false)
        #expect(noProfile.toSSHConfigEntry().contains("    StrictHostKeyChecking no\n"))
    }

    @Test func minimalProfileProducesShortConfig() {
        // empty user, port 22, no forwards, defaults
        let profile = makeProfile(
            name: "simple",
            host: "simple.example.com",
            port: 22,
            username: "",
            privateKeyPath: nil,
            jumpHost: nil,
            proxyCommand: nil,
            identityFile: nil,
            strictHostKeyChecking: true,
            compression: false,
            connectionTimeout: 30,
            serverAliveInterval: 60
        )
        let entry = profile.toSSHConfigEntry()
        #expect(entry == """
        Host simple
            HostName simple.example.com
            ConnectTimeout 30
            ServerAliveInterval 60
            StrictHostKeyChecking yes

        """)
    }
}
