import Foundation
import Testing
@testable import iTermGUI

@Suite("SSHProfile.connectionString")
struct SSHProfileConnectionStringTests {
    @Test("omits user when empty and omits port 22",
          arguments: [
            (host: "example.com", port: 22, user: "", expected: "example.com"),
            (host: "example.com", port: 2222, user: "", expected: "example.com:2222"),
            (host: "example.com", port: 22, user: "alex", expected: "alex@example.com"),
            (host: "example.com", port: 2222, user: "alex", expected: "alex@example.com:2222"),
            (host: "10.0.0.1", port: 22, user: "root", expected: "root@10.0.0.1"),
            (host: "fe80::1", port: 22, user: "", expected: "fe80::1"),
          ])
    func builds(host: String, port: Int, user: String, expected: String) {
        let profile = makeProfile(host: host, port: port, username: user)
        #expect(profile.connectionString == expected)
    }
}

@Suite("SSHProfile.init defaults")
struct SSHProfileInitTests {
    @Test func portDefaultsTo22() {
        #expect(makeProfile().port == 22)
    }

    @Test func authMethodDefaultsToPublicKey() {
        let profile = SSHProfile(name: "x", host: "h")
        #expect(profile.authMethod == .publicKey)
    }

    @Test func embeddedTerminalSettingsDefaultsToInstance() {
        let profile = SSHProfile(name: "x", host: "h", embeddedTerminalSettings: nil)
        #expect(profile.embeddedTerminalSettings != nil)
    }

    @Test func strictHostKeyCheckingDefaultsToTrue() {
        #expect(SSHProfile(name: "x", host: "h").strictHostKeyChecking == true)
    }

    @Test func compressionDefaultsToFalse() {
        #expect(SSHProfile(name: "x", host: "h").compression == false)
    }

    @Test func connectionTimeoutDefaultsTo30() {
        #expect(SSHProfile(name: "x", host: "h").connectionTimeout == 30)
    }

    @Test func serverAliveIntervalDefaultsTo60() {
        #expect(SSHProfile(name: "x", host: "h").serverAliveInterval == 60)
    }

    @Test func tagsDefaultsToEmpty() {
        #expect(SSHProfile(name: "x", host: "h").tags.isEmpty)
    }
}

@Suite("SSHProfile.effectiveEmbeddedTerminalSettings")
struct SSHProfileEffectiveTerminalSettingsTests {
    @Test func returnsSetValueWhenPresent() {
        var settings = EmbeddedTerminalSettings()
        settings.fontSize = 99
        let profile = makeProfile(embeddedTerminalSettings: settings)
        #expect(profile.effectiveEmbeddedTerminalSettings.fontSize == 99)
    }

    @Test func returnsDefaultSettingsWhenInitPassedNil() {
        // Init replaces nil with a default-constructed EmbeddedTerminalSettings,
        // so effective settings always reflect the default.
        let profile = makeProfile(embeddedTerminalSettings: nil)
        let defaults = EmbeddedTerminalSettings()
        #expect(profile.effectiveEmbeddedTerminalSettings.fontSize == defaults.fontSize)
    }
}

@Suite("SSHProfile Codable round-trip")
struct SSHProfileCodableTests {
    @Test func roundTripPreservesAllFields() throws {
        let original = makeProfile(
            name: "prod-1",
            host: "prod.example.com",
            port: 2222,
            username: "deploy",
            authMethod: .certificate,
            privateKeyPath: "/keys/id_rsa",
            tags: ["prod", "critical"],
            jumpHost: "bastion.example.com",
            localForwards: [PortForward(localPort: 8080, remoteHost: "internal", remotePort: 80)],
            remoteForwards: [PortForward(localPort: 9000, remoteHost: "localhost", remotePort: 9000)],
            proxyCommand: "nc %h %p",
            identityFile: "/keys/alt",
            strictHostKeyChecking: false,
            compression: true,
            connectionTimeout: 15,
            serverAliveInterval: 30,
            isFavorite: true,
            customCommands: ["uptime", "hostname"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SSHProfile.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.host == original.host)
        #expect(decoded.port == original.port)
        #expect(decoded.username == original.username)
        #expect(decoded.authMethod == original.authMethod)
        #expect(decoded.privateKeyPath == original.privateKeyPath)
        #expect(decoded.tags == original.tags)
        #expect(decoded.jumpHost == original.jumpHost)
        #expect(decoded.localForwards == original.localForwards)
        #expect(decoded.remoteForwards == original.remoteForwards)
        #expect(decoded.proxyCommand == original.proxyCommand)
        #expect(decoded.identityFile == original.identityFile)
        #expect(decoded.strictHostKeyChecking == original.strictHostKeyChecking)
        #expect(decoded.compression == original.compression)
        #expect(decoded.connectionTimeout == original.connectionTimeout)
        #expect(decoded.serverAliveInterval == original.serverAliveInterval)
        #expect(decoded.isFavorite == original.isFavorite)
        #expect(decoded.customCommands == original.customCommands)
    }
}

@Suite("SSHProfile.Hashable")
struct SSHProfileHashableTests {
    @Test func differentIdsProduceNotEqual() {
        let a = makeProfile(id: UUID(), name: "x", host: "h")
        let b = makeProfile(id: UUID(), name: "x", host: "h")
        #expect(a != b)
    }

    @Test func sameIdAndFieldsAreEqual() {
        let id = UUID()
        let fixedDate = Date(timeIntervalSince1970: 100)
        let a = makeProfile(id: id, name: "x", host: "h",
                            createdAt: fixedDate, modifiedAt: fixedDate)
        let b = makeProfile(id: id, name: "x", host: "h",
                            createdAt: fixedDate, modifiedAt: fixedDate)
        #expect(a == b)
    }
}

@Suite("AuthMethod enum")
struct AuthMethodTests {
    @Test func caseIterableHasAllFourCases() {
        #expect(AuthMethod.allCases.count == 4)
        #expect(Set(AuthMethod.allCases) == [.publicKey, .password, .keyboardInteractive, .certificate])
    }

    @Test func rawValuesAreDisplayStrings() {
        #expect(AuthMethod.publicKey.rawValue == "Public Key")
        #expect(AuthMethod.password.rawValue == "Password")
        #expect(AuthMethod.keyboardInteractive.rawValue == "Keyboard Interactive")
        #expect(AuthMethod.certificate.rawValue == "Certificate")
    }
}

@Suite("CursorStyle enum")
struct CursorStyleTests {
    @Test func caseIterableHasAllThreeCases() {
        #expect(CursorStyle.allCases.count == 3)
        #expect(Set(CursorStyle.allCases) == [.block, .underline, .bar])
    }
}

@Suite("PortForward")
struct PortForwardTests {
    @Test func equalityAndHash() {
        let a = PortForward(localPort: 8080, remoteHost: "host", remotePort: 80)
        let b = PortForward(localPort: 8080, remoteHost: "host", remotePort: 80)
        let c = PortForward(localPort: 8081, remoteHost: "host", remotePort: 80)
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func codableRoundTrip() throws {
        let original = PortForward(localPort: 443, remoteHost: "api.example.com", remotePort: 8443)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PortForward.self, from: data)
        #expect(decoded == original)
    }
}
