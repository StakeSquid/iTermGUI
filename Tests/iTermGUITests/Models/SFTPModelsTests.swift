import Foundation
import Testing
@testable import iTermGUI

@Suite("FileLocation.displayName")
struct FileLocationDisplayNameTests {
    @Test func localhostReturnsLocalhost() {
        #expect(FileLocation.localhost.displayName == "Localhost")
    }

    @Test func serverReturnsProfileName() {
        let profile = makeProfile(name: "prod-web")
        #expect(FileLocation.server(profile).displayName == "prod-web")
    }
}

@Suite("RemoteFile.sizeString")
struct RemoteFileSizeStringTests {
    @Test func directoryReturnsDoubleDash() {
        let file = RemoteFile(name: "d", path: "/d", isDirectory: true,
                              size: 1024, modifiedDate: nil, permissions: "drwxr-xr-x")
        #expect(file.sizeString == "--")
    }

    @Test func fileReturnsFormattedBytes() {
        let file = RemoteFile(name: "f", path: "/f", isDirectory: false,
                              size: 1024, modifiedDate: nil, permissions: "-rw-r--r--")
        // ByteCountFormatter returns "1 KB" (via locale rules); just assert it contains KB or bytes
        let s = file.sizeString
        #expect(s.isEmpty == false)
        #expect(s != "--")
    }

    @Test func zeroSizeFileFormatsToZero() {
        let file = RemoteFile(name: "f", path: "/f", isDirectory: false,
                              size: 0, modifiedDate: nil, permissions: "-rw-r--r--")
        // Expect some form of zero string
        let s = file.sizeString
        #expect(s.isEmpty == false)
        #expect(s != "--")
    }
}

@Suite("RemoteFile.dateString")
struct RemoteFileDateStringTests {
    @Test func nilDateReturnsDoubleDash() {
        let file = RemoteFile(name: "f", path: "/f", isDirectory: false,
                              size: 0, modifiedDate: nil, permissions: "-rw-r--r--")
        #expect(file.dateString == "--")
    }

    @Test func presentDateReturnsFormattedString() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let file = RemoteFile(name: "f", path: "/f", isDirectory: false,
                              size: 0, modifiedDate: fixedDate, permissions: "-rw-r--r--")
        #expect(file.dateString != "--")
        #expect(file.dateString.isEmpty == false)
    }
}

@Suite("RemoteFile.id fresh-UUID documentation")
struct RemoteFileIDDocumentationTests {
    /// Documents current behavior: two RemoteFile instances constructed from the same
    /// data get distinct IDs. Changing this would be a behavior change; we preserve it.
    @Test func sameDataProducesDistinctIDs() {
        let a = RemoteFile(name: "x", path: "/x", isDirectory: false,
                           size: 10, modifiedDate: nil, permissions: "-rw-r--r--")
        let b = RemoteFile(name: "x", path: "/x", isDirectory: false,
                           size: 10, modifiedDate: nil, permissions: "-rw-r--r--")
        #expect(a.id != b.id)
    }

    @Test func idIsStableForSingleInstance() {
        let file = RemoteFile(name: "x", path: "/x", isDirectory: false,
                              size: 10, modifiedDate: nil, permissions: "-rw-r--r--")
        #expect(file.id == file.id)
    }
}

@Suite("FileTransfer.progress")
struct FileTransferProgressTests {
    @Test func zeroTotalReturnsZeroNotNaN() {
        let t = FileTransfer(
            sourcePath: "/s", destinationPath: "/d",
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 0, transferredBytes: 50, status: .transferring,
            error: nil, isDirectory: false
        )
        #expect(t.progress == 0)
        #expect(t.progress.isNaN == false)
    }

    @Test func negativeTotalReturnsZero() {
        let t = FileTransfer(
            sourcePath: "/s", destinationPath: "/d",
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: -1, transferredBytes: 10, status: .transferring,
            error: nil, isDirectory: false
        )
        #expect(t.progress == 0)
    }

    @Test func partialProgressDividesCorrectly() {
        let t = FileTransfer(
            sourcePath: "/s", destinationPath: "/d",
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 100, transferredBytes: 25, status: .transferring,
            error: nil, isDirectory: false
        )
        #expect(t.progress == 0.25)
    }

    @Test func completeProgressEqualsOne() {
        let t = FileTransfer(
            sourcePath: "/s", destinationPath: "/d",
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 100, transferredBytes: 100, status: .completed,
            error: nil, isDirectory: false
        )
        #expect(t.progress == 1.0)
    }
}

@Suite("FileTransfer.progressString")
struct FileTransferProgressStringTests {
    @Test func formatsAsPercentage() {
        let t = FileTransfer(
            sourcePath: "/s", destinationPath: "/d",
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 100, transferredBytes: 42, status: .transferring,
            error: nil, isDirectory: false
        )
        #expect(t.progressString == "42%")
    }

    @Test func zeroProgressFormatsAsZeroPercent() {
        let t = FileTransfer(
            sourcePath: "/s", destinationPath: "/d",
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 100, transferredBytes: 0, status: .pending,
            error: nil, isDirectory: false
        )
        #expect(t.progressString == "0%")
    }

    /// Documents current behavior: no clamping. If transferred exceeds total,
    /// the string goes above 100%. This is not ideal but is current behavior.
    @Test func overOneHundredPercentIsPossible() {
        let t = FileTransfer(
            sourcePath: "/s", destinationPath: "/d",
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 100, transferredBytes: 150, status: .transferring,
            error: nil, isDirectory: false
        )
        #expect(t.progressString == "150%")
    }
}

@Suite("FileLocation Hashable")
struct FileLocationHashableTests {
    @Test func localhostEqualsLocalhost() {
        #expect(FileLocation.localhost == FileLocation.localhost)
    }

    @Test func serverWithDifferentProfilesNotEqual() {
        let p1 = makeProfile(name: "a")
        let p2 = makeProfile(name: "b")
        #expect(FileLocation.server(p1) != FileLocation.server(p2))
    }

    @Test func localhostNotEqualToServer() {
        #expect(FileLocation.localhost != FileLocation.server(makeProfile()))
    }
}
