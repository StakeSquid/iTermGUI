import Foundation
import Testing
@testable import iTermGUI

@Suite("ProfileManager load/save via injected storage") @MainActor
struct ProfileManagerPersistenceTests {
    @Test func loadProfilesPullsFromStorage() throws {
        let fileStore = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/pm-load")
        let profile = makeProfile(name: "persisted")
        let data = try JSONEncoder().encode([profile])
        fileStore.seed(root.appendingPathComponent("profiles.json"), with: data)

        let storage = ProfileStorage(
            rootDirectory: root,
            fileStore: fileStore,
            keychain: InMemoryKeychainStore(),
            keychainService: "test",
            migrateFromDocuments: false
        )

        let m = ProfileManager(
            storage: storage,
            sshConfigParser: SSHConfigParser(),
            iTerm2Service: makeStubITerm2Service(),
            autoLoad: true,
            autoSave: false
        )

        #expect(m.profiles.count == 1)
        #expect(m.profiles[0].name == "persisted")
    }

    @Test func saveProfilesPersistsJSONToFileStore() {
        let fileStore = InMemoryProfileFileStore()
        let storage = makeStubStorage(fileStore: fileStore)
        let m = ProfileManager(
            storage: storage,
            sshConfigParser: SSHConfigParser(),
            iTerm2Service: makeStubITerm2Service(),
            autoLoad: false,
            autoSave: false
        )
        m.profiles = [makeProfile(name: "to-save")]

        m.saveProfiles()

        #expect(fileStore.dataAt(storage.profilesFile) != nil)
    }

    @Test func loadProfilesReplacesEmptyGroupsWithDefaults() {
        let fileStore = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/pm-empty-groups")
        // Seed an empty groups.json
        fileStore.seed(root.appendingPathComponent("groups.json"), withString: "[]")

        let storage = ProfileStorage(
            rootDirectory: root,
            fileStore: fileStore,
            keychain: InMemoryKeychainStore(),
            keychainService: "test",
            migrateFromDocuments: false
        )

        let m = ProfileManager(
            storage: storage,
            sshConfigParser: SSHConfigParser(),
            iTerm2Service: makeStubITerm2Service(),
            autoLoad: true,
            autoSave: false
        )

        #expect(m.groups.count == ProfileGroup.defaultGroups.count)
    }
}

@Suite("ProfileManager import from file") @MainActor
struct ProfileManagerImportTests {
    @Test func importFromFileAddsNewProfilesSkippingDuplicatesByName() async {
        let fileStore = InMemoryProfileFileStore()
        let configURL = URL(fileURLWithPath: "/tmp/imported-config")
        fileStore.seed(configURL, withString: SSHConfigFixtures.multiHostConfig)

        let parser = SSHConfigParser(
            userNameProvider: { "u" },
            fileStore: fileStore
        )

        let m = ProfileManager(
            storage: makeStubStorage(),
            sshConfigParser: parser,
            iTerm2Service: makeStubITerm2Service(),
            autoLoad: false,
            autoSave: false
        )
        m.profiles = [makeProfile(name: "a")] // duplicate of one in the fixture

        m.importFromFile(url: configURL)

        // Wait for async Task to complete
        try? await Task.sleep(for: .milliseconds(200))

        let names = Set(m.profiles.map(\.name))
        // "a" was pre-existing (so not duplicated), "b" and "c" imported fresh
        #expect(names.contains("a"))
        #expect(names.contains("b"))
        #expect(names.contains("c"))
        #expect(m.profiles.filter { $0.name == "a" }.count == 1)
    }
}
