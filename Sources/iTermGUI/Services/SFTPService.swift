import Foundation
import Combine

class SFTPService: ObservableObject {
    @Published var transfers: [FileTransfer] = []
    private var cancellables = Set<AnyCancellable>()

    private let processRunner: ProcessRunner
    private let fileStore: ProfileFileStore

    init(
        processRunner: ProcessRunner = FoundationProcessRunner(),
        fileStore: ProfileFileStore = FileManagerStore()
    ) {
        self.processRunner = processRunner
        self.fileStore = fileStore
    }

    func listFiles(at path: String, location: FileLocation, completion: @escaping (Result<[RemoteFile], Error>) -> Void) {
        switch location {
        case .localhost:
            listLocalFiles(at: path, completion: completion)
        case .server(let profile):
            listRemoteFiles(at: path, profile: profile, completion: completion)
        }
    }

    private func listLocalFiles(at path: String, completion: @escaping (Result<[RemoteFile], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = URL(fileURLWithPath: path)
                let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .fileResourceTypeKey
                ])

                let files = contents.map { url -> RemoteFile in
                    let resourceValues = try? url.resourceValues(forKeys: [
                        .isDirectoryKey,
                        .fileSizeKey,
                        .contentModificationDateKey
                    ])

                    return RemoteFile(
                        name: url.lastPathComponent,
                        path: url.path,
                        isDirectory: resourceValues?.isDirectory ?? false,
                        size: Int64(resourceValues?.fileSize ?? 0),
                        modifiedDate: resourceValues?.contentModificationDate,
                        permissions: self.getLocalFilePermissions(at: url)
                    )
                }.sorted { $0.name < $1.name }

                DispatchQueue.main.async {
                    completion(.success(files))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func permissionsString(forPOSIX posix: NSNumber) -> String {
        let perms = posix.uint16Value
        var result = ""

        result += (perms & 0o400 != 0) ? "r" : "-"
        result += (perms & 0o200 != 0) ? "w" : "-"
        result += (perms & 0o100 != 0) ? "x" : "-"

        result += (perms & 0o040 != 0) ? "r" : "-"
        result += (perms & 0o020 != 0) ? "w" : "-"
        result += (perms & 0o010 != 0) ? "x" : "-"

        result += (perms & 0o004 != 0) ? "r" : "-"
        result += (perms & 0o002 != 0) ? "w" : "-"
        result += (perms & 0o001 != 0) ? "x" : "-"

        return result
    }

    private func getLocalFilePermissions(at url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let permissions = attributes[.posixPermissions] as? NSNumber else {
            return "---"
        }
        return permissionsString(forPOSIX: permissions)
    }

    func expandTildeForShell(_ path: String) -> String {
        if path == "~" { return "$HOME" }
        return path.replacingOccurrences(of: "~/", with: "$HOME/")
    }

    func escapePathForShellSingleQuote(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "'\\''")
    }

    func buildRemoteListCommand(path: String) -> String {
        let expandedPath = expandTildeForShell(path)
        return """
            set +o noglob 2>/dev/null || true
            TARGET_DIR="\(expandedPath)"
            if [ -d "$TARGET_DIR" ]; then
                cd "$TARGET_DIR" 2>/dev/null || exit 1
                # Use find instead of shell globbing to avoid shell-specific issues
                find . -maxdepth 1 -mindepth 1 2>/dev/null | while read -r filepath; do
                    file=$(basename "$filepath")
                    if [ -d "$filepath" ]; then
                        mtime=$(stat -c %Y "$filepath" 2>/dev/null || stat -f %m "$filepath" 2>/dev/null || echo 0)
                        echo "d|$file|0|$mtime"
                    else
                        size=$(stat -c %s "$filepath" 2>/dev/null || stat -f %z "$filepath" 2>/dev/null || echo 0)
                        mtime=$(stat -c %Y "$filepath" 2>/dev/null || stat -f %m "$filepath" 2>/dev/null || echo 0)
                        echo "f|$file|$size|$mtime"
                    fi
                done
                # If find doesn't work, fall back to ls
                if [ $? -ne 0 ]; then
                    ls -1a | while read -r file; do
                        if [ "$file" != "." ] && [ "$file" != ".." ]; then
                            if [ -d "$file" ]; then
                                echo "d|$file|0|0"
                            else
                                echo "f|$file|0|0"
                            fi
                        fi
                    done
                fi
            else
                echo "Error: Not a directory: $TARGET_DIR"
                exit 1
            fi
            """
    }

    func buildSSHArgsForList(profile: SSHProfile) -> [String] {
        var arguments: [String] = []

        arguments.append(contentsOf: ["-o", "ConnectTimeout=10"])
        arguments.append(contentsOf: ["-o", "StrictHostKeyChecking=no"])
        arguments.append(contentsOf: ["-o", "UserKnownHostsFile=/dev/null"])
        arguments.append(contentsOf: ["-o", "LogLevel=ERROR"])

        if profile.port != 22 {
            arguments.append(contentsOf: ["-p", "\(profile.port)"])
        }

        if let keyPath = profile.privateKeyPath ?? profile.identityFile {
            arguments.append(contentsOf: ["-i", keyPath])
        }

        if let jumpHost = profile.jumpHost {
            arguments.append(contentsOf: ["-J", jumpHost])
        }

        if !profile.username.isEmpty {
            arguments.append("\(profile.username)@\(profile.host)")
        } else {
            arguments.append(profile.host)
        }

        return arguments
    }

    private func listRemoteFiles(at path: String, profile: SSHProfile, completion: @escaping (Result<[RemoteFile], Error>) -> Void) {
        var arguments = buildSSHArgsForList(profile: profile)
        arguments.append(buildRemoteListCommand(path: path))

        let launch = ProcessLaunch(launchPath: "/usr/bin/ssh", arguments: arguments)

        processRunner.run(launch) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let procResult):
                if procResult.isSuccess {
                    let files = self.parseSimpleOutput(procResult.stdoutString, basePath: path)
                    completion(.success(files))
                } else {
                    let errorOutput = procResult.stderrString
                    let errorMessage = errorOutput.isEmpty ? "Failed to list remote files (exit code: \(procResult.exitCode))" : errorOutput
                    completion(.failure(NSError(domain: "SFTPService", code: Int(procResult.exitCode), userInfo: [
                        NSLocalizedDescriptionKey: errorMessage
                    ])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func parseSimpleOutput(_ output: String, basePath: String) -> [RemoteFile] {
        let lines = output.components(separatedBy: .newlines)
        var files: [RemoteFile] = []

        for line in lines {
            let components = line.split(separator: "|", omittingEmptySubsequences: false)
            guard components.count >= 4 else { continue }

            let type = String(components[0])
            let name = String(components[1])
            let size = Int64(components[2]) ?? 0
            let mtimeSeconds = TimeInterval(components[3]) ?? 0

            if name == "." || name == ".." || name.starts(with: "Error:") {
                continue
            }

            let isDirectory = (type == "d")
            let date = mtimeSeconds > 0 ? Date(timeIntervalSince1970: mtimeSeconds) : nil

            let fullPath = basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"

            files.append(RemoteFile(
                name: name,
                path: fullPath,
                isDirectory: isDirectory,
                size: size,
                modifiedDate: date,
                permissions: isDirectory ? "drwxr-xr-x" : "-rw-r--r--"
            ))
        }

        return sortedFiles(files)
    }

    func sortedFiles(_ files: [RemoteFile]) -> [RemoteFile] {
        files.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory
            }
            return $0.name < $1.name
        }
    }

    func transferFile(from sourcePath: String, sourceLocation: FileLocation,
                     to destinationPath: String, destinationLocation: FileLocation,
                     isDirectory: Bool = false) {

        if isDirectory {
            let transfer = FileTransfer(
                sourcePath: sourcePath,
                destinationPath: destinationPath,
                sourceLocation: sourceLocation,
                destinationLocation: destinationLocation,
                totalBytes: 0,
                status: .transferring,
                error: nil,
                isDirectory: true
            )

            DispatchQueue.main.async {
                self.transfers.append(transfer)
            }

            self.performTransfer(transfer)
        } else {
            getFileSize(at: sourcePath, location: sourceLocation) { [weak self] size in
                guard let self = self else { return }

                let transfer = FileTransfer(
                    sourcePath: sourcePath,
                    destinationPath: destinationPath,
                    sourceLocation: sourceLocation,
                    destinationLocation: destinationLocation,
                    totalBytes: size,
                    status: .transferring,
                    error: nil,
                    isDirectory: false
                )

                DispatchQueue.main.async {
                    self.transfers.append(transfer)
                }

                self.performTransfer(transfer)
            }
        }
    }

    private func getFileSize(at path: String, location: FileLocation, completion: @escaping (Int64) -> Void) {
        switch location {
        case .localhost:
            let url = URL(fileURLWithPath: path)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? NSNumber {
                completion(size.int64Value)
            } else {
                completion(0)
            }

        case .server(let profile):
            var arguments = ["-o", "BatchMode=yes"]

            if !profile.username.isEmpty {
                arguments.append("\(profile.username)@\(profile.host)")
            } else {
                arguments.append(profile.host)
            }

            if profile.port != 22 {
                arguments.append(contentsOf: ["-p", "\(profile.port)"])
            }

            if let keyPath = profile.privateKeyPath ?? profile.identityFile {
                arguments.append(contentsOf: ["-i", keyPath])
            }

            arguments.append("stat -c%s '\(path)' 2>/dev/null || stat -f%z '\(path)'")

            let launch = ProcessLaunch(launchPath: "/usr/bin/ssh", arguments: arguments)

            processRunner.run(launch) { result in
                switch result {
                case .success(let procResult):
                    let size = Int64(procResult.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                    completion(size)
                case .failure:
                    completion(0)
                }
            }
        }
    }

    private func performTransfer(_ transfer: FileTransfer) {
        switch (transfer.sourceLocation, transfer.destinationLocation) {
        case (.localhost, .localhost):
            copyLocalToLocal(transfer)

        case (.localhost, .server(let profile)):
            uploadToServer(transfer, profile: profile)

        case (.server(let profile), .localhost):
            downloadFromServer(transfer, profile: profile)

        case (.server(let sourceProfile), .server(let destProfile)):
            transferServerToServer(transfer, sourceProfile: sourceProfile, destProfile: destProfile)
        }
    }

    private func copyLocalToLocal(_ transfer: FileTransfer) {
        do {
            try FileManager.default.copyItem(atPath: transfer.sourcePath, toPath: transfer.destinationPath)
            updateTransferStatus(transfer.id, status: .completed)
        } catch {
            updateTransferStatus(transfer.id, status: .failed, error: error.localizedDescription)
        }
    }

    func buildSCPUploadLaunch(for transfer: FileTransfer, profile: SSHProfile) -> ProcessLaunch {
        var arguments = ["-p"]

        if transfer.isDirectory {
            arguments.append("-r")
        }

        if profile.port != 22 {
            arguments.append(contentsOf: ["-P", "\(profile.port)"])
        }

        if let keyPath = profile.privateKeyPath ?? profile.identityFile {
            arguments.append(contentsOf: ["-i", keyPath])
        }

        arguments.append(transfer.sourcePath)

        if !profile.username.isEmpty {
            arguments.append("\(profile.username)@\(profile.host):\(transfer.destinationPath)")
        } else {
            arguments.append("\(profile.host):\(transfer.destinationPath)")
        }

        return ProcessLaunch(launchPath: "/usr/bin/scp", arguments: arguments)
    }

    func buildSCPDownloadLaunch(for transfer: FileTransfer, profile: SSHProfile) -> ProcessLaunch {
        var arguments = ["-p"]

        if transfer.isDirectory {
            arguments.append("-r")
        }

        if profile.port != 22 {
            arguments.append(contentsOf: ["-P", "\(profile.port)"])
        }

        if let keyPath = profile.privateKeyPath ?? profile.identityFile {
            arguments.append(contentsOf: ["-i", keyPath])
        }

        if !profile.username.isEmpty {
            arguments.append("\(profile.username)@\(profile.host):\(transfer.sourcePath)")
        } else {
            arguments.append("\(profile.host):\(transfer.sourcePath)")
        }

        arguments.append(transfer.destinationPath)

        return ProcessLaunch(launchPath: "/usr/bin/scp", arguments: arguments)
    }

    private func uploadToServer(_ transfer: FileTransfer, profile: SSHProfile) {
        let launch = buildSCPUploadLaunch(for: transfer, profile: profile)
        processRunner.run(launch) { [weak self] result in
            switch result {
            case .success(let procResult):
                if procResult.isSuccess {
                    self?.updateTransferStatus(transfer.id, status: .completed)
                } else {
                    self?.updateTransferStatus(transfer.id, status: .failed, error: "Transfer failed")
                }
            case .failure(let error):
                self?.updateTransferStatus(transfer.id, status: .failed, error: error.localizedDescription)
            }
        }
    }

    private func downloadFromServer(_ transfer: FileTransfer, profile: SSHProfile) {
        let launch = buildSCPDownloadLaunch(for: transfer, profile: profile)
        processRunner.run(launch) { [weak self] result in
            switch result {
            case .success(let procResult):
                if procResult.isSuccess {
                    self?.updateTransferStatus(transfer.id, status: .completed)
                } else {
                    self?.updateTransferStatus(transfer.id, status: .failed, error: "Transfer failed")
                }
            case .failure(let error):
                self?.updateTransferStatus(transfer.id, status: .failed, error: error.localizedDescription)
            }
        }
    }

    func buildServerToServerSourceCommand(for transfer: FileTransfer) -> String {
        if transfer.isDirectory {
            if transfer.sourcePath.hasPrefix("~/") {
                let pathWithoutTilde = String(transfer.sourcePath.dropFirst(2))
                let escapedPath = escapePathForShellSingleQuote(pathWithoutTilde)
                return "tar cf - -C $HOME '\(escapedPath)'"
            } else {
                let dirName = URL(fileURLWithPath: transfer.sourcePath).lastPathComponent
                let parentDir = URL(fileURLWithPath: transfer.sourcePath).deletingLastPathComponent().path
                let escapedDirName = escapePathForShellSingleQuote(dirName)
                let escapedParentDir = escapePathForShellSingleQuote(parentDir)
                return "tar cf - -C '\(escapedParentDir)' '\(escapedDirName)'"
            }
        } else {
            if transfer.sourcePath.hasPrefix("~/") {
                let pathWithoutTilde = String(transfer.sourcePath.dropFirst(2))
                let escapedPath = escapePathForShellSingleQuote(pathWithoutTilde)
                return "cat $HOME/'\(escapedPath)'"
            } else if transfer.sourcePath == "~" {
                return "cat $HOME"
            } else {
                let escapedPath = escapePathForShellSingleQuote(transfer.sourcePath)
                return "cat '\(escapedPath)'"
            }
        }
    }

    func buildServerToServerDestCommand(for transfer: FileTransfer) -> String {
        if transfer.isDirectory {
            if transfer.destinationPath.hasPrefix("~/") {
                let pathWithoutTilde = String(transfer.destinationPath.dropFirst(2))
                let destParent = URL(fileURLWithPath: pathWithoutTilde).deletingLastPathComponent().path
                if destParent.isEmpty || destParent == "." {
                    return "cd $HOME && tar xf -"
                } else {
                    let escapedParent = escapePathForShellSingleQuote(destParent)
                    return "mkdir -p $HOME/'\(escapedParent)' && cd $HOME/'\(escapedParent)' && tar xf -"
                }
            } else {
                let destParent = URL(fileURLWithPath: transfer.destinationPath).deletingLastPathComponent().path
                let escapedParent = escapePathForShellSingleQuote(destParent)
                return "mkdir -p '\(escapedParent)' && cd '\(escapedParent)' && tar xf -"
            }
        } else if transfer.destinationPath.hasPrefix("~/") {
            let pathWithoutTilde = String(transfer.destinationPath.dropFirst(2))
            let escapedPath = escapePathForShellSingleQuote(pathWithoutTilde)

            let pathComponents = pathWithoutTilde.split(separator: "/")
            if pathComponents.count > 1 {
                let dirPath = pathComponents.dropLast().joined(separator: "/")
                let escapedDirPath = escapePathForShellSingleQuote(dirPath)
                return "mkdir -p $HOME/'\(escapedDirPath)' && cat > $HOME/'\(escapedPath)'"
            } else {
                return "cat > $HOME/'\(escapedPath)'"
            }
        } else if transfer.destinationPath == "~" {
            return "cat > $HOME"
        } else {
            let escapedPath = escapePathForShellSingleQuote(transfer.destinationPath)
            let destDir = URL(fileURLWithPath: transfer.destinationPath).deletingLastPathComponent().path
            let escapedDestDir = escapePathForShellSingleQuote(destDir)
            return "mkdir -p '\(escapedDestDir)' && cat > '\(escapedPath)'"
        }
    }

    private func transferServerToServer(_ transfer: FileTransfer, sourceProfile: SSHProfile, destProfile: SSHProfile) {
        updateTransferStatus(transfer.id, status: .transferring)

        let sourceCommand = buildServerToServerSourceCommand(for: transfer)

        var sourceArgs: [String] = []
        sourceArgs.append(contentsOf: ["-o", "ConnectTimeout=10"])
        sourceArgs.append(contentsOf: ["-o", "StrictHostKeyChecking=no"])
        sourceArgs.append(contentsOf: ["-o", "UserKnownHostsFile=/dev/null"])
        sourceArgs.append(contentsOf: ["-o", "LogLevel=ERROR"])

        if sourceProfile.port != 22 {
            sourceArgs.append(contentsOf: ["-p", "\(sourceProfile.port)"])
        }

        if let keyPath = sourceProfile.privateKeyPath ?? sourceProfile.identityFile {
            sourceArgs.append(contentsOf: ["-i", keyPath])
        }

        if let jumpHost = sourceProfile.jumpHost {
            sourceArgs.append(contentsOf: ["-J", jumpHost])
        }

        if !sourceProfile.username.isEmpty {
            sourceArgs.append("\(sourceProfile.username)@\(sourceProfile.host)")
        } else {
            sourceArgs.append(sourceProfile.host)
        }

        sourceArgs.append(sourceCommand)

        let sourceTask = Process()
        sourceTask.launchPath = "/usr/bin/ssh"
        sourceTask.arguments = sourceArgs

        var destArgs: [String] = []
        destArgs.append(contentsOf: ["-o", "ConnectTimeout=10"])
        destArgs.append(contentsOf: ["-o", "StrictHostKeyChecking=no"])
        destArgs.append(contentsOf: ["-o", "UserKnownHostsFile=/dev/null"])
        destArgs.append(contentsOf: ["-o", "LogLevel=ERROR"])

        if destProfile.port != 22 {
            destArgs.append(contentsOf: ["-p", "\(destProfile.port)"])
        }

        if let keyPath = destProfile.privateKeyPath ?? destProfile.identityFile {
            destArgs.append(contentsOf: ["-i", keyPath])
        }

        if let jumpHost = destProfile.jumpHost {
            destArgs.append(contentsOf: ["-J", jumpHost])
        }

        if !destProfile.username.isEmpty {
            destArgs.append("\(destProfile.username)@\(destProfile.host)")
        } else {
            destArgs.append(destProfile.host)
        }

        let destCommand = buildServerToServerDestCommand(for: transfer)
        destArgs.append(destCommand)

        let destTask = Process()
        destTask.launchPath = "/usr/bin/ssh"
        destTask.arguments = destArgs

        let pipe = Pipe()
        sourceTask.standardOutput = pipe
        destTask.standardInput = pipe

        let sourceErrorPipe = Pipe()
        let destErrorPipe = Pipe()
        sourceTask.standardError = sourceErrorPipe
        destTask.standardError = destErrorPipe

        print("DEBUG: Server-to-server transfer using SSH tunnel")
        print("DEBUG: Transfer from: \(transfer.sourcePath)")
        print("DEBUG: Transfer to: \(transfer.destinationPath)")
        print("DEBUG: Source command: ssh \(sourceArgs.joined(separator: " "))")
        print("DEBUG: Dest command: ssh \(destArgs.joined(separator: " "))")

        var sourceCompleted = false
        var transferFailed = false

        sourceTask.terminationHandler = { [weak self] process in
            sourceCompleted = true

            if process.terminationStatus != 0 {
                let errorData = sourceErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("DEBUG: Source SSH failed with exit code: \(process.terminationStatus)")

                if !transferFailed {
                    transferFailed = true
                    DispatchQueue.main.async {
                        let errorMsg = errorOutput.isEmpty ? "SSH connection failed (exit code: \(process.terminationStatus))" : errorOutput
                        self?.updateTransferStatus(transfer.id, status: .failed, error: "Source read failed: \(errorMsg)")
                    }
                }

                if destTask.isRunning {
                    destTask.terminate()
                }
            }
        }

        destTask.terminationHandler = { [weak self] process in
            if process.terminationStatus != 0 {
                let errorData = destErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("DEBUG: Destination SSH failed with exit code: \(process.terminationStatus)")

                if !transferFailed {
                    transferFailed = true
                    DispatchQueue.main.async {
                        let errorMsg = errorOutput.isEmpty ? "SSH connection failed (exit code: \(process.terminationStatus))" : errorOutput
                        self?.updateTransferStatus(transfer.id, status: .failed, error: "Destination write failed: \(errorMsg)")
                    }
                }
            } else if sourceCompleted && !transferFailed {
                print("DEBUG: Server-to-server transfer completed successfully")
                DispatchQueue.main.async {
                    self?.updateTransferStatus(transfer.id, status: .completed)
                }
            }
        }

        do {
            try sourceTask.run()
            try destTask.run()
        } catch {
            print("DEBUG: Failed to start SSH tunnel: \(error)")
            updateTransferStatus(transfer.id, status: .failed, error: "Failed to start transfer: \(error.localizedDescription)")
        }
    }

    private func updateTransferStatus(_ id: UUID, status: TransferStatus, error: String? = nil) {
        if let index = transfers.firstIndex(where: { $0.id == id }) {
            transfers[index].status = status
            transfers[index].error = error
        }
    }

    func buildDeleteCommand(path: String) -> String {
        if path == "~" || path.hasPrefix("~/") {
            let relativePath = path == "~" ? "" : String(path.dropFirst(2))
            return relativePath.isEmpty ? "rm -rf \"$HOME\"" : "rm -rf \"$HOME/\(relativePath)\""
        } else {
            return "rm -rf \"\(path)\""
        }
    }

    func createDirectory(at path: String, location: FileLocation, completion: @escaping (Bool) -> Void) {
        switch location {
        case .localhost:
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                completion(true)
            } catch {
                completion(false)
            }

        case .server(let profile):
            var arguments = ["-o", "BatchMode=yes"]

            if !profile.username.isEmpty {
                arguments.append("\(profile.username)@\(profile.host)")
            } else {
                arguments.append(profile.host)
            }

            if profile.port != 22 {
                arguments.append(contentsOf: ["-p", "\(profile.port)"])
            }

            if let keyPath = profile.privateKeyPath ?? profile.identityFile {
                arguments.append(contentsOf: ["-i", keyPath])
            }

            arguments.append("mkdir -p '\(path)'")

            let launch = ProcessLaunch(launchPath: "/usr/bin/ssh", arguments: arguments)

            processRunner.run(launch) { result in
                switch result {
                case .success(let procResult):
                    completion(procResult.isSuccess)
                case .failure:
                    completion(false)
                }
            }
        }
    }

    func deleteFile(at path: String, location: FileLocation, completion: @escaping (Bool) -> Void) {
        switch location {
        case .localhost:
            do {
                try FileManager.default.removeItem(atPath: path)
                completion(true)
            } catch {
                completion(false)
            }

        case .server(let profile):
            var arguments: [String] = []

            arguments.append(contentsOf: ["-o", "ConnectTimeout=10"])
            arguments.append(contentsOf: ["-o", "StrictHostKeyChecking=no"])
            arguments.append(contentsOf: ["-o", "UserKnownHostsFile=/dev/null"])
            arguments.append(contentsOf: ["-o", "LogLevel=ERROR"])

            if profile.port != 22 {
                arguments.append(contentsOf: ["-p", "\(profile.port)"])
            }

            if let keyPath = profile.privateKeyPath ?? profile.identityFile {
                arguments.append(contentsOf: ["-i", keyPath])
            }

            if let jumpHost = profile.jumpHost {
                arguments.append(contentsOf: ["-J", jumpHost])
            }

            if !profile.username.isEmpty {
                arguments.append("\(profile.username)@\(profile.host)")
            } else {
                arguments.append(profile.host)
            }

            arguments.append(buildDeleteCommand(path: path))

            let launch = ProcessLaunch(launchPath: "/usr/bin/ssh", arguments: arguments)

            processRunner.run(launch) { result in
                switch result {
                case .success(let procResult):
                    completion(procResult.isSuccess)
                case .failure:
                    completion(false)
                }
            }
        }
    }
}
