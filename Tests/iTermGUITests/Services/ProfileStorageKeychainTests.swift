import Foundation
import Testing
@testable import iTermGUI

@Suite("ProfileStorage keychain integration")
struct ProfileStorageKeychainIntegrationTests {
    @Test func saveThenLoadRestoresPassword() throws {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        let storage = makeStubStorage(fileStore: store, keychain: keychain)

        let profile = makeProfile(password: "secret-value")
        storage.saveProfiles([profile])

        let loaded = storage.loadProfiles()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == profile.id)
        #expect(loaded[0].password == "secret-value")
    }

    @Test func multipleProfilesStoreDistinctPasswords() throws {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        let storage = makeStubStorage(fileStore: store, keychain: keychain)

        let a = makeProfile(id: UUID(), name: "a", password: "pw-a")
        let b = makeProfile(id: UUID(), name: "b", password: "pw-b")
        storage.saveProfiles([a, b])

        let loaded = storage.loadProfiles().sorted { $0.name < $1.name }
        #expect(loaded[0].password == "pw-a")
        #expect(loaded[1].password == "pw-b")
    }

    @Test func saveProfileThenSaveAgainWithoutPasswordDeletesKeychainEntry() throws {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        let storage = makeStubStorage(fileStore: store, keychain: keychain)

        let id = UUID()
        let withPassword = makeProfile(id: id, password: "x")
        storage.saveProfiles([withPassword])
        #expect(keychain.count == 1)

        let withoutPassword = makeProfile(id: id, password: nil)
        storage.saveProfiles([withoutPassword])
        #expect(keychain.count == 0)
    }

    @Test func keychainThrowOnSetIsCaughtNotPropagated() {
        let store = InMemoryProfileFileStore()
        let keychain = InMemoryKeychainStore()
        keychain.throwOnSet = KeychainError.encoding
        let storage = makeStubStorage(fileStore: store, keychain: keychain)

        // Must not crash/throw even though keychain refuses
        storage.saveProfiles([makeProfile(password: "whatever")])

        // Profile JSON is still persisted
        #expect(store.dataAt(storage.profilesFile) != nil)
    }
}

@Suite("KeychainError equality")
struct KeychainErrorTests {
    @Test func encodingEqualsEncoding() {
        #expect(KeychainError.encoding == KeychainError.encoding)
    }

    @Test func osStatusEqualityBasedOnCode() {
        #expect(KeychainError.osStatus(-1) == KeychainError.osStatus(-1))
        #expect(KeychainError.osStatus(-1) != KeychainError.osStatus(-2))
    }

    @Test func differentCasesNotEqual() {
        #expect(KeychainError.encoding != KeychainError.osStatus(0))
    }
}
