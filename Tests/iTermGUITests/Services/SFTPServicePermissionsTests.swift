import Foundation
import Testing
@testable import iTermGUI

@Suite("SFTPService.permissionsString")
struct SFTPPermissionsStringTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test(arguments: [
        (0o755, "rwxr-xr-x"),
        (0o644, "rw-r--r--"),
        (0o000, "---------"),
        (0o777, "rwxrwxrwx"),
        (0o400, "r--------"),
        (0o007, "------rwx"),
        (0o700, "rwx------"),
        (0o070, "---rwx---"),
        (0o666, "rw-rw-rw-"),
        (0o111, "--x--x--x"),
    ])
    func formatsOctalToRWXString(octal: Int, expected: String) {
        let result = svc.permissionsString(forPOSIX: NSNumber(value: octal))
        #expect(result == expected, "octal \(String(octal, radix: 8)) should be \(expected), got \(result)")
    }

    @Test func ownerReadBitProducesRAtPositionZero() {
        let s = svc.permissionsString(forPOSIX: NSNumber(value: 0o400))
        #expect(s.first == "r")
    }

    @Test func ignoresSetuidBits() {
        // 0o4755 = setuid + rwxr-xr-x. Function only reads low 9 bits.
        let s = svc.permissionsString(forPOSIX: NSNumber(value: 0o4755))
        #expect(s == "rwxr-xr-x")
    }
}
