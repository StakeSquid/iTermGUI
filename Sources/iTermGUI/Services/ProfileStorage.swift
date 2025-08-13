import Foundation
import Security

class ProfileStorage {
    private let profilesKey = "com.iTermGUI.profiles"
    private let groupsKey = "com.iTermGUI.groups"
    private let keychainService = "com.iTermGUI.passwords"
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var profilesFile: URL {
        documentsDirectory.appendingPathComponent("profiles.json")
    }
    
    private var groupsFile: URL {
        documentsDirectory.appendingPathComponent("groups.json")
    }
    
    private var defaultsFile: URL {
        documentsDirectory.appendingPathComponent("defaults.json")
    }
    
    func loadProfiles() -> [SSHProfile] {
        guard let data = try? Data(contentsOf: profilesFile) else {
            return []
        }
        
        do {
            var profiles = try JSONDecoder().decode([SSHProfile].self, from: data)
            
            for i in profiles.indices {
                if let password = loadPasswordFromKeychain(for: profiles[i].id) {
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
                if let password = profilesToSave[i].password {
                    savePasswordToKeychain(password, for: profilesToSave[i].id)
                    profilesToSave[i].password = nil
                } else {
                    deletePasswordFromKeychain(for: profilesToSave[i].id)
                }
            }
            
            let data = try JSONEncoder().encode(profilesToSave)
            try data.write(to: profilesFile)
        } catch {
            print("Error saving profiles: \(error)")
        }
    }
    
    func loadGroups() -> [ProfileGroup] {
        guard let data = try? Data(contentsOf: groupsFile) else {
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
            try data.write(to: groupsFile)
        } catch {
            print("Error saving groups: \(error)")
        }
    }
    
    private func savePasswordToKeychain(_ password: String, for profileID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: profileID.uuidString,
            kSecValueData as String: password.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error saving password to keychain: \(status)")
        }
    }
    
    private func loadPasswordFromKeychain(for profileID: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: profileID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let password = String(data: data, encoding: .utf8) {
            return password
        }
        
        return nil
    }
    
    private func deletePasswordFromKeychain(for profileID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: profileID.uuidString
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    func exportProfiles(to url: URL, profiles: [SSHProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profiles)
        try data.write(to: url)
    }
    
    func importProfiles(from url: URL) throws -> [SSHProfile] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SSHProfile].self, from: data)
    }
    
    func loadGlobalDefaults() -> GlobalDefaults {
        guard let data = try? Data(contentsOf: defaultsFile) else {
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
            try data.write(to: defaultsFile)
        } catch {
            print("Error saving global defaults: \(error)")
        }
    }
}