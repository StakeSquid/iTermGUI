import Foundation

enum FileLocation: Hashable {
    case localhost
    case server(SSHProfile)
    
    var displayName: String {
        switch self {
        case .localhost:
            return "Localhost"
        case .server(let profile):
            return profile.name
        }
    }
}

struct RemoteFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date?
    let permissions: String
    
    var sizeString: String {
        if isDirectory {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var dateString: String {
        guard let date = modifiedDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct FileTransfer: Identifiable {
    let id = UUID()
    let sourcePath: String
    let destinationPath: String
    let sourceLocation: FileLocation
    let destinationLocation: FileLocation
    let totalBytes: Int64
    var transferredBytes: Int64 = 0
    var status: TransferStatus = .pending
    var error: String?
    let isDirectory: Bool
    
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }
    
    var progressString: String {
        "\(Int(progress * 100))%"
    }
}

enum TransferStatus {
    case pending
    case transferring
    case completed
    case failed
}