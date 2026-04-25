import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let remoteFileItem = UTType(exportedAs: "com.itermgui.remotefile")
}

struct RemoteFileDragItem: Codable, Transferable, Identifiable, Hashable {
    let id: UUID
    let path: String
    let name: String
    let isDirectory: Bool
    let originSide: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .remoteFileItem)
    }
}
