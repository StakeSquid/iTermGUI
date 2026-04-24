import Foundation
import Testing
@testable import iTermGUI

@Suite("SFTPService.parseSimpleOutput")
struct SFTPParseSimpleOutputTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test func parsesDirectoryLine() {
        let files = svc.parseSimpleOutput("d|bin|0|1700000000", basePath: "/")
        #expect(files.count == 1)
        #expect(files[0].name == "bin")
        #expect(files[0].isDirectory)
        #expect(files[0].path == "/bin")
        #expect(files[0].modifiedDate != nil)
    }

    @Test func parsesFileLine() {
        let files = svc.parseSimpleOutput("f|hello.txt|1234|1700000000", basePath: "/home/user")
        #expect(files.count == 1)
        #expect(files[0].name == "hello.txt")
        #expect(files[0].isDirectory == false)
        #expect(files[0].size == 1234)
        #expect(files[0].path == "/home/user/hello.txt")
    }

    @Test func skipsDotAndDotDot() {
        let output = """
        d|.|0|0
        d|..|0|0
        f|real.txt|10|0
        """
        let files = svc.parseSimpleOutput(output, basePath: "/tmp")
        #expect(files.map(\.name) == ["real.txt"])
    }

    @Test func skipsErrorLines() {
        let output = """
        Error: Not a directory
        f|real.txt|10|0
        """
        let files = svc.parseSimpleOutput(output, basePath: "/tmp")
        #expect(files.map(\.name) == ["real.txt"])
    }

    @Test func skipsLinesWithFewerThanFourComponents() {
        let output = """
        bad-line
        f|two|only
        f|good|10|0
        """
        let files = svc.parseSimpleOutput(output, basePath: "/tmp")
        #expect(files.map(\.name) == ["good"])
    }

    @Test func mtimeZeroProducesNilDate() {
        let files = svc.parseSimpleOutput("f|x|10|0", basePath: "/tmp")
        #expect(files[0].modifiedDate == nil)
    }

    @Test func invalidSizeFallsBackToZero() {
        let files = svc.parseSimpleOutput("f|x|notasize|0", basePath: "/tmp")
        #expect(files[0].size == 0)
    }

    @Test func invalidMtimeFallsBackToNilDate() {
        let files = svc.parseSimpleOutput("f|x|100|notatime", basePath: "/tmp")
        #expect(files[0].modifiedDate == nil)
    }

    @Test func trailingSlashInBasePathNotDoubled() {
        let files = svc.parseSimpleOutput("f|file|1|0", basePath: "/tmp/")
        #expect(files[0].path == "/tmp/file")
    }

    @Test func noTrailingSlashInsertsOne() {
        let files = svc.parseSimpleOutput("f|file|1|0", basePath: "/tmp")
        #expect(files[0].path == "/tmp/file")
    }

    @Test func directoriesComeBeforeFilesInSort() {
        let output = """
        f|zzz.txt|10|0
        d|aaa|0|0
        f|aaa.txt|10|0
        d|zzz|0|0
        """
        let files = svc.parseSimpleOutput(output, basePath: "/tmp")
        // Directories first (aaa, zzz), then files (aaa.txt, zzz.txt)
        #expect(files.map(\.name) == ["aaa", "zzz", "aaa.txt", "zzz.txt"])
    }

    @Test func directoryPermissionsAreDefaultStyle() {
        let files = svc.parseSimpleOutput("d|bin|0|0", basePath: "/")
        #expect(files[0].permissions == "drwxr-xr-x")
    }

    @Test func filePermissionsAreDefaultStyle() {
        let files = svc.parseSimpleOutput("f|note|10|0", basePath: "/")
        #expect(files[0].permissions == "-rw-r--r--")
    }
}

@Suite("SFTPService.sortedFiles")
struct SFTPSortedFilesTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test func directoriesPrecedeFiles() {
        let files = [
            RemoteFile(name: "b.txt", path: "/b.txt", isDirectory: false, size: 0, modifiedDate: nil, permissions: ""),
            RemoteFile(name: "adir", path: "/adir", isDirectory: true, size: 0, modifiedDate: nil, permissions: "")
        ]
        let sorted = svc.sortedFiles(files)
        #expect(sorted[0].isDirectory)
        #expect(sorted[0].name == "adir")
    }

    @Test func alphabeticalWithinSameKind() {
        let files = [
            RemoteFile(name: "z", path: "/z", isDirectory: true, size: 0, modifiedDate: nil, permissions: ""),
            RemoteFile(name: "a", path: "/a", isDirectory: true, size: 0, modifiedDate: nil, permissions: ""),
            RemoteFile(name: "m", path: "/m", isDirectory: true, size: 0, modifiedDate: nil, permissions: "")
        ]
        let sorted = svc.sortedFiles(files)
        #expect(sorted.map(\.name) == ["a", "m", "z"])
    }

    @Test func emptyInputReturnsEmpty() {
        #expect(svc.sortedFiles([]).isEmpty)
    }
}
