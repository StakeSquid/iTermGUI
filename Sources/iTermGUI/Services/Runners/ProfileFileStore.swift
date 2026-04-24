import Foundation

protocol ProfileFileStore {
    func read(_ url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func fileExists(at url: URL) -> Bool
    func moveItem(at src: URL, to dst: URL) throws
    func createDirectory(at url: URL) throws
}

final class FileManagerStore: ProfileFileStore {
    private let fm: FileManager
    init(fileManager: FileManager = .default) { self.fm = fileManager }

    func read(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    func fileExists(at url: URL) -> Bool {
        fm.fileExists(atPath: url.path)
    }

    func moveItem(at src: URL, to dst: URL) throws {
        try fm.moveItem(at: src, to: dst)
    }

    func createDirectory(at url: URL) throws {
        try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
}
