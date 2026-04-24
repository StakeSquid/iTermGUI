import Foundation
import Security

class ProfileStorage {
    private let profilesKey = "com.iTermGUI.profiles"
    private let groupsKey = "com.iTermGUI.groups"
    let keychainService: String

    private let rootDirectory: URL
    private let fileStore: ProfileFileStore
    private let keychain: KeychainStore

    var appDirectory: URL { rootDirectory }
    var profilesFile: URL { rootDirectory.appendingPathComponent("profiles.json") }
    var groupsFile: URL { rootDirectory.appendingPathComponent("groups.json") }
    var defaultsFile: URL { rootDirectory.appendingPathComponent("defaults.json") }

    convenience init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.init(rootDirectory: docs.appendingPathComponent("iTermGUI"))
    }

    init(
        rootDirectory: URL,
        fileStore: ProfileFileStore = FileManagerStore(),
        keychain: KeychainStore = SecKeychainStore(),
        keychainService: String = "com.iTermGUI.passwords",
        migrateFromDocuments: Bool = true
    ) {
        self.rootDirectory = rootDirectory
        self.fileStore = fileStore
        self.keychain = keychain
        self.keychainService = keychainService

        createAppDirectoryIfNeeded()
        if migrateFromDocuments {
            migrateOldFilesIfNeeded()
        }
    }

    private func createAppDirectoryIfNeeded() {
        do {
            try fileStore.createDirectory(at: rootDirectory)
        } catch {
            print("Error creating app directory: \(error)")
        }
    }

    private func migrateOldFilesIfNeeded() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        migrate(src: docs.appendingPathComponent("profiles.json"), dst: profilesFile, label: "profiles.json")
        migrate(src: docs.appendingPathComponent("groups.json"), dst: groupsFile, label: "groups.json")
        migrate(src: docs.appendingPathComponent("defaults.json"), dst: defaultsFile, label: "defaults.json")
    }

    private func migrate(src: URL, dst: URL, label: String) {
        guard fileStore.fileExists(at: src), !fileStore.fileExists(at: dst) else { return }
        do {
            try fileStore.moveItem(at: src, to: dst)
            print("Migrated \(label) to iTermGUI folder")
        } catch {
            print("Error migrating \(label): \(error)")
        }
    }

    func loadProfiles() -> [SSHProfile] {
        guard let data = try? fileStore.read(profilesFile) else {
            return []
        }

        do {
            var profiles = try JSONDecoder().decode([SSHProfile].self, from: data)
            for i in profiles.indices {
                if let password = keychain.getPassword(forAccount: profiles[i].id.uuidString, service: keychainService) {
                    profiles[i].password = password
                }
            }
            return profiles
        } catch {
            print("Error loading profiles: \(error)")
            return []
        }
    }

    func saveProfiles(_ profiles: [SSHProfile]) {
        do {
            var profilesToSave = profiles

            for i in profilesToSave.indices {
                let account = profilesToSave[i].id.uuidString
                if let password = profilesToSave[i].password {
                    do {
                        try keychain.setPassword(password, forAccount: account, service: keychainService)
                    } catch {
                        print("Error saving password to keychain: \(error)")
                    }
                    profilesToSave[i].password = nil
                } else {
                    keychain.deletePassword(forAccount: account, service: keychainService)
                }
            }

            let data = try JSONEncoder().encode(profilesToSave)
            try fileStore.write(data, to: profilesFile)
        } catch {
            print("Error saving profiles: \(error)")
        }
    }

    func loadGroups() -> [ProfileGroup] {
        guard let data = try? fileStore.read(groupsFile) else {
            return ProfileGroup.defaultGroups
        }
        do {
            return try JSONDecoder().decode([ProfileGroup].self, from: data)
        } catch {
            print("Error loading groups: \(error)")
            return ProfileGroup.defaultGroups
        }
    }

    func saveGroups(_ groups: [ProfileGroup]) {
        do {
            let data = try JSONEncoder().encode(groups)
            try fileStore.write(data, to: groupsFile)
        } catch {
            print("Error saving groups: \(error)")
        }
    }

    func exportProfiles(to url: URL, profiles: [SSHProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profiles)
        try fileStore.write(data, to: url)
    }

    func importProfiles(from url: URL) throws -> [SSHProfile] {
        let data = try fileStore.read(url)
        return try JSONDecoder().decode([SSHProfile].self, from: data)
    }

    func loadGlobalDefaults() -> GlobalDefaults {
        guard let data = try? fileStore.read(defaultsFile) else {
            return GlobalDefaults.standard
        }
        do {
            return try JSONDecoder().decode(GlobalDefaults.self, from: data)
        } catch {
            print("Error loading global defaults: \(error)")
            return GlobalDefaults.standard
        }
    }

    func saveGlobalDefaults(_ defaults: GlobalDefaults) {
        do {
            let data = try JSONEncoder().encode(defaults)
            try fileStore.write(data, to: defaultsFile)
        } catch {
            print("Error saving global defaults: \(error)")
        }
    }
}
