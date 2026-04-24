import Foundation
import Security

enum KeychainError: Error, Equatable {
    case encoding
    case osStatus(OSStatus)
}

protocol KeychainStore {
    func setPassword(_ password: String, forAccount account: String, service: String) throws
    func getPassword(forAccount account: String, service: String) -> String?
    func deletePassword(forAccount account: String, service: String)
}

final class SecKeychainStore: KeychainStore {
    func setPassword(_ password: String, forAccount account: String, service: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encoding
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.osStatus(status)
        }
    }

    func getPassword(forAccount account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deletePassword(forAccount account: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
