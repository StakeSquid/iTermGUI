import Foundation
import Testing
@testable import iTermGUI

@Suite("ProfileStorage loadProfiles")
struct ProfileStorageLoadTests {
    @Test func returnsEmptyWhenFileAbsent() {
        let storage = makeStubStorage()
        #expect(storage.loadProfiles().isEmpty)
    }

    @Test func returnsEmptyOnMalformedJSON() {
        let store = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")
        store.seed(root.appendingPathComponent("profiles.json"),
                   withString: "{ not valid json }")
        let storage = makeStubStorage(fileStore: store, rootDirectory: root)
        #expect(storage.loadProfiles().isEmpty)
    }

    @Test func injectsPasswordFromKeychainOnLoad() throws {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")

        let profile = makeProfile(id: UUID(), name: "p", host: "h")
        let data = try JSONEncoder().encode([profile])
        store.seed(root.appendingPathComponent("profiles.json"), with: data)

        try keychain.setPassword("secret",
                                 forAccount: profile.id.uuidString,
                                 service: "com.iTermGUI.tests")

        let storage = makeStubStorage(fileStore: store, keychain: keychain, rootDirectory: root)
        let loaded = storage.loadProfiles()
        #expect(loaded.count == 1)
        #expect(loaded[0].password == "secret")
    }

    @Test func leavesPasswordNilWhenKeychainEmpty() throws {
        let store = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")

        let profile = makeProfile(id: UUID())
        let data = try JSONEncoder().encode([profile])
        store.seed(root.appendingPathComponent("profiles.json"), with: data)

        let storage = makeStubStorage(fileStore: store, rootDirectory: root)
        let loaded = storage.loadProfiles()
        #expect(loaded[0].password == nil)
    }
}

@Suite("ProfileStorage saveProfiles")
struct ProfileStorageSaveTests {
    @Test func stripsPasswordFromJSON() throws {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")
        let storage = makeStubStorage(fileStore: store, keychain: keychain, rootDirectory: root)

        let profile = makeProfile(password: "secret")
        storage.saveProfiles([profile])

        let saved = try #require(store.dataAt(root.appendingPathComponent("profiles.json")))
        let decoded = try JSONDecoder().decode([SSHProfile].self, from: saved)
        #expect(decoded.count == 1)
        #expect(decoded[0].password == nil)
        #expect(keychain.getPassword(forAccount: profile.id.uuidString,
                                     service: "com.iTermGUI.tests") == "secret")
    }

    @Test func deletesKeychainEntryWhenPasswordNil() throws {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")
        let storage = makeStubStorage(fileStore: store, keychain: keychain, rootDirectory: root)

        let profile = makeProfile(password: nil)
        try keychain.setPassword("old",
                                 forAccount: profile.id.uuidString,
                                 service: "com.iTermGUI.tests")

        storage.saveProfiles([profile])

        #expect(keychain.getPassword(forAccount: profile.id.uuidString,
                                     service: "com.iTermGUI.tests") == nil)
    }

    @Test func catchesKeychainThrow() {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        keychain.throwOnSet = KeychainError.osStatus(-25300)
        let storage = makeStubStorage(fileStore: store, keychain: keychain)

        // Should not crash despite keychain throwing
        storage.saveProfiles([makeProfile(password: "x")])

        // The profile json is still written
        #expect(store.dataAt(storage.profilesFile) != nil)
    }
}

@Suite("ProfileStorage groups and defaults")
struct ProfileStorageGroupsAndDefaultsTests {
    @Test func loadGroupsReturnsDefaultsWhenFileAbsent() {
        let storage = makeStubStorage()
        let groups = storage.loadGroups()
        #expect(groups == ProfileGroup.defaultGroups)
    }

    @Test func loadGroupsReturnsDefaultsOnDecodeError() {
        let store = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")
        store.seed(root.appendingPathComponent("groups.json"),
                   withString: "not json")
        let storage = makeStubStorage(fileStore: store, rootDirectory: root)
        #expect(storage.loadGroups() == ProfileGroup.defaultGroups)
    }

    @Test func saveGroupsRoundTrips() throws {
        let store = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")
        let storage = makeStubStorage(fileStore: store, rootDirectory: root)
        let groups = [makeGroup(name: "Alpha"), makeGroup(name: "Beta")]
        storage.saveGroups(groups)
        let loaded = storage.loadGroups()
        #expect(loaded.count == 2)
        #expect(loaded.map(\.name) == ["Alpha", "Beta"])
    }

    @Test func loadGlobalDefaultsReturnsStandardWhenAbsent() {
        let storage = makeStubStorage()
        let defaults = storage.loadGlobalDefaults()
        #expect(defaults.connectionTimeout == GlobalDefaults.standard.connectionTimeout)
    }

    @Test func loadGlobalDefaultsReturnsStandardOnDecodeError() {
        let store = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")
        store.seed(root.appendingPathComponent("defaults.json"), withString: "nope")
        let storage = makeStubStorage(fileStore: store, rootDirectory: root)
        let defaults = storage.loadGlobalDefaults()
        #expect(defaults.connectionTimeout == GlobalDefaults.standard.connectionTimeout)
    }

    @Test func saveGlobalDefaultsRoundTrips() {
        let store = InMemoryProfileFileStore()
        let root = URL(fileURLWithPath: "/tmp/test-root")
        let storage = makeStubStorage(fileStore: store, rootDirectory: root)
        let custom = makeGlobalDefaults(connectionTimeout: 77, compression: true)
        storage.saveGlobalDefaults(custom)
        let loaded = storage.loadGlobalDefaults()
        #expect(loaded.connectionTimeout == 77)
        #expect(loaded.compression == true)
    }
}

@Suite("ProfileStorage export/import")
struct ProfileStorageExportImportTests {
    @Test func exportWritesPrettyPrintedJSON() throws {
        let store = InMemoryProfileFileStore()
        let storage = makeStubStorage(fileStore: store)
        let url = URL(fileURLWithPath: "/tmp/export.json")
        try storage.exportProfiles(to: url, profiles: [makeProfile(name: "exp")])
        let written = try #require(store.dataAt(url))
        let text = try #require(String(data: written, encoding: .utf8))
        #expect(text.contains("\"name\""))
        #expect(text.contains("exp"))
    }

    @Test func importRoundTrips() throws {
        let store = InMemoryProfileFileStore()
        let storage = makeStubStorage(fileStore: store)
        let exportUrl = URL(fileURLWithPath: "/tmp/export.json")
        let originals = [makeProfile(name: "a"), makeProfile(name: "b")]
        try storage.exportProfiles(to: exportUrl, profiles: originals)
        let imported = try storage.importProfiles(from: exportUrl)
        #expect(imported.count == 2)
        #expect(imported.map(\.name).sorted() == ["a", "b"])
    }
}

@Suite("ProfileStorage migration from Documents")
struct ProfileStorageMigrationTests {
    @Test func migratesFileWhenSourceExistsAndDestAbsent() throws {
        let store = InMemoryProfileFileStore()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldProfilesURL = docs.appendingPathComponent("profiles.json")
        let root = URL(fileURLWithPath: "/tmp/test-migration-root")

        store.seed(oldProfilesURL, withString: "[]")

        _ = ProfileStorage(
            rootDirectory: root,
            fileStore: store,
            keychain: InMemoryKeychainStore(),
            keychainService: "com.iTermGUI.tests",
            migrateFromDocuments: true
        )

        // file moved to new location
        #expect(store.dataAt(root.appendingPathComponent("profiles.json")) != nil)
        // file removed from old location
        #expect(store.dataAt(oldProfilesURL) == nil)
    }

    @Test func skipsMigrationWhenDestAlreadyExists() throws {
        let store = InMemoryProfileFileStore()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldProfilesURL = docs.appendingPathComponent("profiles.json")
        let root = URL(fileURLWithPath: "/tmp/test-migration-root")

        store.seed(oldProfilesURL, withString: "[]")
        store.seed(root.appendingPathComponent("profiles.json"), withString: "[\"existing\"]")

        _ = ProfileStorage(
            rootDirectory: root,
            fileStore: store,
            keychain: InMemoryKeychainStore(),
            keychainService: "com.iTermGUI.tests",
            migrateFromDocuments: true
        )

        // destination unchanged
        #expect(store.stringAt(root.appendingPathComponent("profiles.json")) == "[\"existing\"]")
        // source preserved (not moved)
        #expect(store.stringAt(oldProfilesURL) == "[]")
    }

    @Test func skipsMigrationWhenFlagIsFalse() {
        let store = InMemoryProfileFileStore()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let oldProfilesURL = docs.appendingPathComponent("profiles.json")
        let root = URL(fileURLWithPath: "/tmp/test-no-migration-root")
        store.seed(oldProfilesURL, withString: "[]")

        _ = ProfileStorage(
            rootDirectory: root,
            fileStore: store,
            keychain: InMemoryKeychainStore(),
            keychainService: "com.iTermGUI.tests",
            migrateFromDocuments: false
        )

        #expect(store.dataAt(oldProfilesURL) != nil)
        #expect(store.dataAt(root.appendingPathComponent("profiles.json")) == nil)
    }
}
