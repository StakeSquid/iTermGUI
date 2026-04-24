import Foundation
import Testing
@testable import iTermGUI

@MainActor
private func makeManager(
    profiles: [SSHProfile] = [],
    storage: ProfileStorage? = nil
) -> ProfileManager {
    let m = ProfileManager(
        storage: storage ?? makeStubStorage(),
        sshConfigParser: SSHConfigParser(),
        iTerm2Service: makeStubITerm2Service(),
        autoLoad: false,
        autoSave: false
    )
    m.profiles = profiles
    m.groups = ProfileGroup.defaultGroups
    return m
}

@Suite("ProfileManager.applyDefaultsToAllProfiles") @MainActor
struct ProfileManagerApplyDefaultsTests {
    @Test func overwritesAllProfilesTargetFields() {
        let m = makeManager(profiles: [
            makeProfile(name: "a", compression: false, connectionTimeout: 99),
            makeProfile(name: "b", compression: false, connectionTimeout: 99)
        ])
        var newDefaults = GlobalDefaults.standard
        newDefaults.connectionTimeout = 5
        newDefaults.compression = true
        m.globalDefaults = newDefaults

        m.applyDefaultsToAllProfiles()

        for p in m.profiles {
            #expect(p.connectionTimeout == 5)
            #expect(p.compression == true)
        }
    }

    @Test func doesNotTouchProfileIdentityFields() {
        let originalId = UUID()
        let m = makeManager(profiles: [
            makeProfile(id: originalId, name: "keep-name", host: "keep-host")
        ])

        m.applyDefaultsToAllProfiles()

        #expect(m.profiles[0].id == originalId)
        #expect(m.profiles[0].name == "keep-name")
        #expect(m.profiles[0].host == "keep-host")
    }
}

@Suite("ProfileManager.saveCurrentProfileAsDefaults") @MainActor
struct ProfileManagerSaveAsDefaultsTests {
    @Test func copiesSevenFieldsFromProfileIntoDefaults() {
        var embedded = EmbeddedTerminalSettings()
        embedded.fontSize = 19
        let profile = makeProfile(
            strictHostKeyChecking: false,
            compression: true,
            connectionTimeout: 44,
            serverAliveInterval: 77,
            customCommands: ["hi"],
            terminalSettings: TerminalSettings(fontSize: 18),
            embeddedTerminalSettings: embedded
        )
        let m = makeManager(profiles: [profile])

        m.saveCurrentProfileAsDefaults(profile)

        #expect(m.globalDefaults.connectionTimeout == 44)
        #expect(m.globalDefaults.serverAliveInterval == 77)
        #expect(m.globalDefaults.strictHostKeyChecking == false)
        #expect(m.globalDefaults.compression == true)
        #expect(m.globalDefaults.customCommands == ["hi"])
        #expect(m.globalDefaults.terminalSettings.fontSize == 18)
        #expect(m.globalDefaults.embeddedTerminalSettings.fontSize == 19)
    }

    @Test func embeddedNilFallsBackToDefault() {
        let profile = makeProfile()
        let m = makeManager(profiles: [profile])

        // Force embedded back to nil to verify the ?? EmbeddedTerminalSettings() branch
        m.profiles[0].embeddedTerminalSettings = nil

        m.saveCurrentProfileAsDefaults(m.profiles[0])

        let defaults = EmbeddedTerminalSettings()
        #expect(m.globalDefaults.embeddedTerminalSettings.fontSize == defaults.fontSize)
    }

    @Test func persistsToStorage() {
        let store = InMemoryProfileFileStore()
        let storage = makeStubStorage(fileStore: store)
        let profile = makeProfile(compression: true)
        let m = makeManager(profiles: [profile], storage: storage)

        m.saveCurrentProfileAsDefaults(profile)

        // storage was called: defaults.json now exists with compression=true
        let url = storage.defaultsFile
        #expect(store.dataAt(url) != nil)
    }
}
