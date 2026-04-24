import Foundation
@testable import iTermGUI

final class InMemoryProfileFileStore: ProfileFileStore {
    struct FileNotFound: Error {}

    private var files: [String: Data] = [:]
    private var directories: Set<String> = []
    var writeError: Error?
    var moveError: Error?

    func seed(_ url: URL, with data: Data) {
        files[url.absoluteString] = data
    }

    func seed(_ url: URL, withString string: String) {
        files[url.absoluteString] = Data(string.utf8)
    }

    func read(_ url: URL) throws -> Data {
        guard let data = files[url.absoluteString] else { throw FileNotFound() }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        if let err = writeError { throw err }
        files[url.absoluteString] = data
    }

    func fileExists(at url: URL) -> Bool {
        files[url.absoluteString] != nil
    }

    func moveItem(at src: URL, to dst: URL) throws {
        if let err = moveError { throw err }
        guard let data = files[src.absoluteString] else { throw FileNotFound() }
        files[dst.absoluteString] = data
        files.removeValue(forKey: src.absoluteString)
    }

    func createDirectory(at url: URL) throws {
        directories.insert(url.absoluteString)
    }

    var allFiles: [URL: Data] {
        Dictionary(uniqueKeysWithValues: files.compactMap { (key, value) in
            URL(string: key).map { ($0, value) }
        })
    }

    func dataAt(_ url: URL) -> Data? {
        files[url.absoluteString]
    }

    func stringAt(_ url: URL) -> String? {
        files[url.absoluteString].flatMap { String(data: $0, encoding: .utf8) }
    }
}
