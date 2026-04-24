import Foundation
@testable import iTermGUI

final class InMemoryKeychainStore: KeychainStore {
    private var store: [String: String] = [:]
    var throwOnSet: Error?

    private func key(service: String, account: String) -> String {
        "\(service)|\(account)"
    }

    func setPassword(_ password: String, forAccount account: String, service: String) throws {
        if let err = throwOnSet { throw err }
        store[key(service: service, account: account)] = password
    }

    func getPassword(forAccount account: String, service: String) -> String? {
        store[key(service: service, account: account)]
    }

    func deletePassword(forAccount account: String, service: String) {
        store.removeValue(forKey: key(service: service, account: account))
    }

    var isEmpty: Bool { store.isEmpty }
    var count: Int { store.count }
}
