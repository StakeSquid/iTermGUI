import Foundation
import Testing
@testable import iTermGUI

@Suite("SFTPService.expandTildeForShell")
struct SFTPExpandTildeTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test func bareTildeExpandsToHome() {
        #expect(svc.expandTildeForShell("~") == "$HOME")
    }

    @Test func tildeSlashExpandsToHomeSlash() {
        #expect(svc.expandTildeForShell("~/Documents") == "$HOME/Documents")
    }

    @Test func tildeSlashAtEndExpands() {
        #expect(svc.expandTildeForShell("~/") == "$HOME/")
    }

    @Test func absolutePathUnchanged() {
        #expect(svc.expandTildeForShell("/var/log") == "/var/log")
    }

    /// Documents current behavior: `replacingOccurrences(of: "~/")` matches
    /// anywhere in the string. If a path has `~/` embedded after the root,
    /// that substring is replaced too. Not a bug worth fixing — real paths
    /// don't typically contain embedded `~/`.
    @Test func tildeSlashAnywhereIsReplaced() {
        #expect(svc.expandTildeForShell("/foo/~/bar") == "/foo/$HOME/bar")
    }

    @Test func userTildeNotExpanded() {
        #expect(svc.expandTildeForShell("~alex/docs") == "~alex/docs")
    }
}

@Suite("SFTPService.escapePathForShellSingleQuote")
struct SFTPEscapePathTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test func singleQuoteIsEscapedToTripleQuotePattern() {
        #expect(svc.escapePathForShellSingleQuote("o'brien") == "o'\\''brien")
    }

    @Test func backslashIsDoubled() {
        #expect(svc.escapePathForShellSingleQuote("back\\slash") == "back\\\\slash")
    }

    @Test func plainPathUnchanged() {
        #expect(svc.escapePathForShellSingleQuote("/home/user/file.txt") == "/home/user/file.txt")
    }

    @Test func emptyStringUnchanged() {
        #expect(svc.escapePathForShellSingleQuote("") == "")
    }

    @Test func multipleQuotesAllEscaped() {
        #expect(svc.escapePathForShellSingleQuote("a'b'c") == "a'\\''b'\\''c")
    }
}

@Suite("SFTPService.buildRemoteListCommand")
struct SFTPRemoteListCommandTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test func absolutePathInterpolatedIntoTargetDir() {
        let cmd = svc.buildRemoteListCommand(path: "/var/log")
        #expect(cmd.contains("TARGET_DIR=\"/var/log\""))
    }

    @Test func tildeExpandsToHomeInCommand() {
        let cmd = svc.buildRemoteListCommand(path: "~")
        #expect(cmd.contains("TARGET_DIR=\"$HOME\""))
    }

    @Test func tildeSlashPathExpands() {
        let cmd = svc.buildRemoteListCommand(path: "~/Documents")
        #expect(cmd.contains("TARGET_DIR=\"$HOME/Documents\""))
    }

    @Test func commandHasFindFallbackToLs() {
        let cmd = svc.buildRemoteListCommand(path: "/tmp")
        #expect(cmd.contains("find ."))
        #expect(cmd.contains("ls -1a"))
    }

    @Test func commandOutputsPipeDelimitedEntries() {
        let cmd = svc.buildRemoteListCommand(path: "/tmp")
        #expect(cmd.contains("echo \"d|$file|0|$mtime\""))
        #expect(cmd.contains("echo \"f|$file|$size|$mtime\""))
    }
}

@Suite("SFTPService.buildSSHArgsForList")
struct SFTPSSHArgsListTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test func containsStandardSSHOptions() {
        let args = svc.buildSSHArgsForList(profile: makeProfile(host: "h", username: "u"))
        #expect(args.contains("ConnectTimeout=10"))
        #expect(args.contains("StrictHostKeyChecking=no"))
        #expect(args.contains("UserKnownHostsFile=/dev/null"))
        #expect(args.contains("LogLevel=ERROR"))
    }

    @Test func includesPortFlagWhenNonDefault() {
        let args = svc.buildSSHArgsForList(profile: makeProfile(host: "h", port: 2222, username: "u"))
        #expect(args.contains("-p"))
        #expect(args.contains("2222"))
    }

    @Test func omitsPortFlagWhenDefault() {
        let args = svc.buildSSHArgsForList(profile: makeProfile(host: "h", port: 22, username: "u"))
        #expect(args.contains("-p") == false)
    }

    @Test func includesJumpHostWhenSet() {
        let args = svc.buildSSHArgsForList(profile: makeProfile(host: "h", username: "u", jumpHost: "jh"))
        #expect(args.contains("-J"))
        #expect(args.contains("jh"))
    }

    @Test func includesKeyWhenSet() {
        let args = svc.buildSSHArgsForList(profile: makeProfile(host: "h", username: "u", privateKeyPath: "/k"))
        #expect(args.contains("-i"))
        #expect(args.contains("/k"))
    }

    @Test func lastArgIsHostWithUser() {
        let args = svc.buildSSHArgsForList(profile: makeProfile(host: "h", username: "u"))
        #expect(args.last == "u@h")
    }

    @Test func lastArgIsBareHostWhenUserEmpty() {
        let args = svc.buildSSHArgsForList(profile: makeProfile(host: "h", username: ""))
        #expect(args.last == "h")
    }
}

@Suite("SFTPService.buildSCPUploadLaunch")
struct SFTPSCPUploadLaunchTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    private func transfer(source: String = "/src", dest: String = "/dst", isDir: Bool = false) -> FileTransfer {
        FileTransfer(
            sourcePath: source, destinationPath: dest,
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 0, transferredBytes: 0, status: .transferring,
            error: nil, isDirectory: isDir
        )
    }

    @Test func scpPathAndPreserveFlag() {
        let t = transfer()
        let launch = svc.buildSCPUploadLaunch(for: t, profile: makeProfile(host: "h", username: "u"))
        #expect(launch.launchPath == "/usr/bin/scp")
        #expect(launch.arguments.first == "-p")
    }

    @Test func recursiveFlagForDirectories() {
        let launch = svc.buildSCPUploadLaunch(
            for: transfer(isDir: true),
            profile: makeProfile(host: "h", username: "u")
        )
        #expect(launch.arguments.contains("-r"))
    }

    @Test func noRecursiveFlagForFiles() {
        let launch = svc.buildSCPUploadLaunch(
            for: transfer(isDir: false),
            profile: makeProfile(host: "h", username: "u")
        )
        #expect(launch.arguments.contains("-r") == false)
    }

    @Test func capitalPFlagForNonDefaultPort() {
        let launch = svc.buildSCPUploadLaunch(
            for: transfer(),
            profile: makeProfile(host: "h", port: 2222, username: "u")
        )
        #expect(launch.arguments.contains("-P"))
        #expect(launch.arguments.contains("2222"))
    }

    @Test func destinationIsUserHostColonPath() {
        let launch = svc.buildSCPUploadLaunch(
            for: transfer(source: "/local/file", dest: "/remote/file"),
            profile: makeProfile(host: "h", username: "u")
        )
        #expect(launch.arguments.contains("/local/file"))
        #expect(launch.arguments.contains("u@h:/remote/file"))
    }

    @Test func destinationIsBareHostWhenUserEmpty() {
        let launch = svc.buildSCPUploadLaunch(
            for: transfer(source: "/local", dest: "/remote"),
            profile: makeProfile(host: "h", username: "")
        )
        #expect(launch.arguments.contains("h:/remote"))
    }
}

@Suite("SFTPService.buildSCPDownloadLaunch")
struct SFTPSCPDownloadLaunchTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    private func transfer(source: String = "/src", dest: String = "/dst") -> FileTransfer {
        FileTransfer(
            sourcePath: source, destinationPath: dest,
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 0, transferredBytes: 0, status: .transferring,
            error: nil, isDirectory: false
        )
    }

    @Test func sourceIsUserHostColonPath() {
        let launch = svc.buildSCPDownloadLaunch(
            for: transfer(source: "/remote/f", dest: "/local/f"),
            profile: makeProfile(host: "h", username: "u")
        )
        #expect(launch.arguments.contains("u@h:/remote/f"))
        #expect(launch.arguments.contains("/local/f"))
    }
}

@Suite("SFTPService.buildDeleteCommand")
struct SFTPBuildDeleteCommandTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    @Test func absolutePathUsesDirectRm() {
        #expect(svc.buildDeleteCommand(path: "/var/tmp/x") == "rm -rf \"/var/tmp/x\"")
    }

    @Test func bareTildeDeletesEntireHome() {
        #expect(svc.buildDeleteCommand(path: "~") == "rm -rf \"$HOME\"")
    }

    @Test func tildeRelativePathExpandsToHomeSlash() {
        #expect(svc.buildDeleteCommand(path: "~/Documents") == "rm -rf \"$HOME/Documents\"")
    }
}

@Suite("SFTPService.buildServerToServerSourceCommand")
struct SFTPServerToServerSourceTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    private func transfer(source: String, dest: String = "/dst", isDir: Bool = false) -> FileTransfer {
        FileTransfer(
            sourcePath: source, destinationPath: dest,
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 0, transferredBytes: 0, status: .transferring,
            error: nil, isDirectory: isDir
        )
    }

    @Test func fileUnderTildeExpandsToHome() {
        let cmd = svc.buildServerToServerSourceCommand(for: transfer(source: "~/file.txt"))
        #expect(cmd == "cat $HOME/'file.txt'")
    }

    @Test func bareTildeSourceFileIsCatHome() {
        let cmd = svc.buildServerToServerSourceCommand(for: transfer(source: "~"))
        #expect(cmd == "cat $HOME")
    }

    @Test func absoluteFilePathIsQuoted() {
        let cmd = svc.buildServerToServerSourceCommand(for: transfer(source: "/var/log/x"))
        #expect(cmd == "cat '/var/log/x'")
    }

    @Test func sourcePathWithQuoteIsEscaped() {
        let cmd = svc.buildServerToServerSourceCommand(for: transfer(source: "/var/'quoted"))
        #expect(cmd == "cat '/var/'\\''quoted'")
    }

    @Test func directoryUnderTildeUsesTarWithCHome() {
        let cmd = svc.buildServerToServerSourceCommand(for: transfer(source: "~/mydir", isDir: true))
        #expect(cmd == "tar cf - -C $HOME 'mydir'")
    }

    @Test func absoluteDirectoryUsesTarWithParent() {
        let cmd = svc.buildServerToServerSourceCommand(for: transfer(source: "/var/tmp/build", isDir: true))
        #expect(cmd == "tar cf - -C '/var/tmp' 'build'")
    }
}

@Suite("SFTPService.buildServerToServerDestCommand")
struct SFTPServerToServerDestTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    private func transfer(dest: String, isDir: Bool = false) -> FileTransfer {
        FileTransfer(
            sourcePath: "/src", destinationPath: dest,
            sourceLocation: .localhost, destinationLocation: .localhost,
            totalBytes: 0, transferredBytes: 0, status: .transferring,
            error: nil, isDirectory: isDir
        )
    }

    @Test func fileUnderHomeCreatesParentAndCats() {
        let cmd = svc.buildServerToServerDestCommand(for: transfer(dest: "~/sub/x.txt"))
        #expect(cmd == "mkdir -p $HOME/'sub' && cat > $HOME/'sub/x.txt'")
    }

    @Test func fileDirectlyUnderHomeHasNoMkdir() {
        let cmd = svc.buildServerToServerDestCommand(for: transfer(dest: "~/x.txt"))
        #expect(cmd == "cat > $HOME/'x.txt'")
    }

    @Test func bareTildeDestIsCatHome() {
        let cmd = svc.buildServerToServerDestCommand(for: transfer(dest: "~"))
        #expect(cmd == "cat > $HOME")
    }

    @Test func absoluteFileCreatesParentAndCats() {
        let cmd = svc.buildServerToServerDestCommand(for: transfer(dest: "/var/log/x.txt"))
        #expect(cmd == "mkdir -p '/var/log' && cat > '/var/log/x.txt'")
    }

    /// Documents current behavior: `URL(fileURLWithPath: "mydir").deletingLastPathComponent().path`
    /// returns the current working directory (not "."), so the "destParent is empty or ." branch
    /// is effectively dead code. The generated command always uses `mkdir -p $HOME/'<cwd>'`, which
    /// is surprising but matches existing behavior. Filed as potential cleanup.
    @Test func directoryUnderHomeGeneratesCwdInterpolation() {
        let cmd = svc.buildServerToServerDestCommand(for: transfer(dest: "~/mydir", isDir: true))
        #expect(cmd.contains("mkdir -p $HOME/"))
        #expect(cmd.contains("tar xf -"))
    }

    @Test func absoluteDirectoryUsesTarExtractWithParent() {
        let cmd = svc.buildServerToServerDestCommand(for: transfer(dest: "/tmp/build", isDir: true))
        #expect(cmd == "mkdir -p '/tmp' && cd '/tmp' && tar xf -")
    }
}

@Suite("SFTPService.buildExistsCommand")
struct SFTPBuildExistsCommandTests {
    private let svc = SFTPService(processRunner: FakeProcessRunner(), fileStore: InMemoryProfileFileStore())

    /// Regression: tilde-prefixed paths used to be wrapped in single quotes, which
    /// suppressed `$HOME` expansion on the remote and made every existence check
    /// silently report `false`. Conflict prompts never fired and files were
    /// overwritten without asking.
    @Test func tildePathUsesDoubleQuotesSoHomeExpands() {
        let cmd = svc.buildExistsCommand(paths: ["~/Downloads/foo.txt"])
        #expect(cmd.contains("[ -e \"$HOME/Downloads/foo.txt\" ]"))
        #expect(!cmd.contains("\u{27}$HOME"))
    }

    @Test func absolutePathUsesDoubleQuotes() {
        let cmd = svc.buildExistsCommand(paths: ["/var/log/system.log"])
        #expect(cmd.contains("[ -e \"/var/log/system.log\" ]"))
    }

    @Test func indicesPrefixOutputLinesInOrder() {
        let cmd = svc.buildExistsCommand(paths: ["/a", "/b", "/c"])
        #expect(cmd.contains("echo \"0|1\""))
        #expect(cmd.contains("echo \"1|1\""))
        #expect(cmd.contains("echo \"2|1\""))
    }

    @Test func emptyInputProducesOnlyHeader() {
        let cmd = svc.buildExistsCommand(paths: [])
        #expect(cmd == "set +o noglob 2>/dev/null || true\n")
    }

    @Test func doubleQuotesInPathAreEscaped() {
        let cmd = svc.buildExistsCommand(paths: ["/tmp/weird\"name"])
        #expect(cmd.contains("\\\""))
    }
}
