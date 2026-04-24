import Foundation
import Testing
@testable import iTermGUI

@Suite("GlobalDefaults.standard")
struct GlobalDefaultsStandardTests {
    @Test func customCommandsIsEmpty() {
        #expect(GlobalDefaults.standard.customCommands.isEmpty)
    }

    @Test func connectionTimeoutIs30() {
        #expect(GlobalDefaults.standard.connectionTimeout == 30)
    }

    @Test func serverAliveIntervalIs60() {
        #expect(GlobalDefaults.standard.serverAliveInterval == 60)
    }

    @Test func strictHostKeyCheckingIsTrue() {
        #expect(GlobalDefaults.standard.strictHostKeyChecking == true)
    }

    @Test func compressionIsFalse() {
        #expect(GlobalDefaults.standard.compression == false)
    }
}

@Suite("GlobalDefaults.applyToProfile")
struct GlobalDefaultsApplyTests {
    @Test func overwritesTargetedFields() {
        let defaults = makeGlobalDefaults(
            customCommands: ["tmux attach"],
            connectionTimeout: 10,
            serverAliveInterval: 5,
            strictHostKeyChecking: false,
            compression: true
        )
        var profile = makeProfile(
            strictHostKeyChecking: true,
            compression: false,
            connectionTimeout: 99,
            serverAliveInterval: 99,
            customCommands: ["old"]
        )

        defaults.applyToProfile(&profile)

        #expect(profile.customCommands == ["tmux attach"])
        #expect(profile.connectionTimeout == 10)
        #expect(profile.serverAliveInterval == 5)
        #expect(profile.strictHostKeyChecking == false)
        #expect(profile.compression == true)
    }

    @Test func overwritesTerminalAndEmbeddedSettings() {
        var newTerm = TerminalSettings()
        newTerm.fontSize = 99
        var newEmbedded = EmbeddedTerminalSettings()
        newEmbedded.fontSize = 42

        let defaults = makeGlobalDefaults(
            terminalSettings: newTerm,
            embeddedTerminalSettings: newEmbedded
        )
        var profile = makeProfile()

        defaults.applyToProfile(&profile)

        #expect(profile.terminalSettings.fontSize == 99)
        #expect(profile.embeddedTerminalSettings?.fontSize == 42)
    }

    @Test func doesNotChangeProfileIdentityFields() {
        let defaults = makeGlobalDefaults(
            customCommands: ["anything"],
            connectionTimeout: 1,
            serverAliveInterval: 1,
            strictHostKeyChecking: false,
            compression: true
        )

        let originalId = UUID()
        var profile = makeProfile(
            id: originalId,
            name: "stable",
            host: "stable.example.com",
            port: 2222,
            username: "stable-user",
            tags: ["prod"],
            isFavorite: true
        )
        let createdAt = profile.createdAt

        defaults.applyToProfile(&profile)

        #expect(profile.id == originalId)
        #expect(profile.name == "stable")
        #expect(profile.host == "stable.example.com")
        #expect(profile.port == 2222)
        #expect(profile.username == "stable-user")
        #expect(profile.tags == ["prod"])
        #expect(profile.isFavorite == true)
        #expect(profile.createdAt == createdAt)
    }

    @Test func updatesModifiedAt() {
        let defaults = GlobalDefaults.standard
        var profile = makeProfile(modifiedAt: Date(timeIntervalSince1970: 0))

        let before = Date()
        defaults.applyToProfile(&profile)

        #expect(profile.modifiedAt >= before)
    }
}

@Suite("GlobalDefaults Codable")
struct GlobalDefaultsCodableTests {
    @Test func roundTripPreservesAllFields() throws {
        let original = makeGlobalDefaults(
            customCommands: ["hostname", "uptime"],
            connectionTimeout: 22,
            serverAliveInterval: 33,
            strictHostKeyChecking: false,
            compression: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GlobalDefaults.self, from: data)
        #expect(decoded.customCommands == original.customCommands)
        #expect(decoded.connectionTimeout == original.connectionTimeout)
        #expect(decoded.serverAliveInterval == original.serverAliveInterval)
        #expect(decoded.strictHostKeyChecking == original.strictHostKeyChecking)
        #expect(decoded.compression == original.compression)
    }
}
