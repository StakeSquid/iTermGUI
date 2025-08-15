import Foundation
import Combine

class SFTPService: ObservableObject {
    @Published var transfers: [FileTransfer] = []
    private var cancellables = Set<AnyCancellable>()
    
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
    
    private func getLocalFilePermissions(at url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let permissions = attributes[.posixPermissions] as? NSNumber else {
            return "---"
        }
        
        let perms = permissions.uint16Value
        var result = ""
        
        // Owner permissions
        result += (perms & 0o400 != 0) ? "r" : "-"
        result += (perms & 0o200 != 0) ? "w" : "-"
        result += (perms & 0o100 != 0) ? "x" : "-"
        
        // Group permissions
        result += (perms & 0o040 != 0) ? "r" : "-"
        result += (perms & 0o020 != 0) ? "w" : "-"
        result += (perms & 0o010 != 0) ? "x" : "-"
        
        // Other permissions
        result += (perms & 0o004 != 0) ? "r" : "-"
        result += (perms & 0o002 != 0) ? "w" : "-"
        result += (perms & 0o001 != 0) ? "x" : "-"
        
        return result
    }
    
    private func listRemoteFiles(at path: String, profile: SSHProfile, completion: @escaping (Result<[RemoteFile], Error>) -> Void) {
        let task = Process()
        task.launchPath = "/usr/bin/ssh"
        
        var arguments: [String] = []
        
        // Add connection timeout and disable strict host checking for better reliability
        arguments.append(contentsOf: ["-o", "ConnectTimeout=10"])
        arguments.append(contentsOf: ["-o", "StrictHostKeyChecking=no"])
        arguments.append(contentsOf: ["-o", "UserKnownHostsFile=/dev/null"])
        arguments.append(contentsOf: ["-o", "LogLevel=ERROR"]) // Suppress warnings
        
        if profile.port != 22 {
            arguments.append(contentsOf: ["-p", "\(profile.port)"])
        }
        
        if let keyPath = profile.privateKeyPath ?? profile.identityFile {
            arguments.append(contentsOf: ["-i", keyPath])
        }
        
        // Add jump host if configured
        if let jumpHost = profile.jumpHost {
            arguments.append(contentsOf: ["-J", jumpHost])
        }
        
        // Build the SSH target
        if !profile.username.isEmpty {
            arguments.append("\(profile.username)@\(profile.host)")
        } else {
            arguments.append(profile.host)
        }
        
        // Use a simpler ls command that works on both Linux and macOS
        // The stat command is more reliable for getting file info
        // Handle tilde expansion
        let expandedPath = path == "~" ? "$HOME" : path.replacingOccurrences(of: "~/", with: "$HOME/")
        let command = """
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
        
        arguments.append(command)
        
        task.arguments = arguments
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        task.terminationHandler = { process in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    let files = self.parseSimpleOutput(output, basePath: path)
                    completion(.success(files))
                } else {
                    let errorMessage = errorOutput.isEmpty ? "Failed to list remote files (exit code: \(process.terminationStatus))" : errorOutput
                    completion(.failure(NSError(domain: "SFTPService", code: Int(process.terminationStatus), userInfo: [
                        NSLocalizedDescriptionKey: errorMessage
                    ])))
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            completion(.failure(error))
        }
    }
    
    private func parseSimpleOutput(_ output: String, basePath: String) -> [RemoteFile] {
        let lines = output.components(separatedBy: .newlines)
        var files: [RemoteFile] = []
        
        for line in lines {
            let components = line.split(separator: "|", omittingEmptySubsequences: false)
            guard components.count >= 4 else { continue }
            
            let type = String(components[0])
            let name = String(components[1])
            let size = Int64(components[2]) ?? 0
            let mtimeSeconds = TimeInterval(components[3]) ?? 0
            
            // Skip . and .. directories and error messages
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
        
        // Sort directories first, then files, alphabetically
        return files.sorted { 
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
            // For directories, we can't easily calculate size, so use 0
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
            // Get file size first for regular files
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
            // Use SSH to get file size
            let task = Process()
            task.launchPath = "/usr/bin/ssh"
            
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
            
            task.arguments = arguments
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            task.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "0"
                let size = Int64(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                completion(size)
            }
            
            try? task.run()
        }
    }
    
    private func performTransfer(_ transfer: FileTransfer) {
        switch (transfer.sourceLocation, transfer.destinationLocation) {
        case (.localhost, .localhost):
            // Local to local copy
            copyLocalToLocal(transfer)
            
        case (.localhost, .server(let profile)):
            // Upload to server
            uploadToServer(transfer, profile: profile)
            
        case (.server(let profile), .localhost):
            // Download from server
            downloadFromServer(transfer, profile: profile)
            
        case (.server(let sourceProfile), .server(let destProfile)):
            // Server to server via local tunneling
            transferServerToServer(transfer, sourceProfile: sourceProfile, destProfile: destProfile)
        }
    }
    
    private func copyLocalToLocal(_ transfer: FileTransfer) {
        do {
            // FileManager.copyItem handles both files and directories
            try FileManager.default.copyItem(atPath: transfer.sourcePath, toPath: transfer.destinationPath)
            updateTransferStatus(transfer.id, status: .completed)
        } catch {
            updateTransferStatus(transfer.id, status: .failed, error: error.localizedDescription)
        }
    }
    
    private func uploadToServer(_ transfer: FileTransfer, profile: SSHProfile) {
        let task = Process()
        task.launchPath = "/usr/bin/scp"
        
        var arguments = ["-p"] // Preserve modification times
        
        // Add recursive flag for directories
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
        
        task.arguments = arguments
        
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    self?.updateTransferStatus(transfer.id, status: .completed)
                } else {
                    self?.updateTransferStatus(transfer.id, status: .failed, error: "Transfer failed")
                }
            }
        }
        
        try? task.run()
    }
    
    private func downloadFromServer(_ transfer: FileTransfer, profile: SSHProfile) {
        let task = Process()
        task.launchPath = "/usr/bin/scp"
        
        var arguments = ["-p"] // Preserve modification times
        
        // Add recursive flag for directories
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
        
        task.arguments = arguments
        
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    self?.updateTransferStatus(transfer.id, status: .completed)
                } else {
                    self?.updateTransferStatus(transfer.id, status: .failed, error: "Transfer failed")
                }
            }
        }
        
        try? task.run()
    }
    
    private func transferServerToServer(_ transfer: FileTransfer, sourceProfile: SSHProfile, destProfile: SSHProfile) {
        // Create SSH tunnel to pipe data directly from source to destination through localhost
        // This uses SSH to cat the file from source and pipe it through SSH to the destination
        
        // Update status to show we're transferring
        updateTransferStatus(transfer.id, status: .transferring)
        
        // Build SSH command to connect to source server
        var sourceArgs: [String] = []
        
        // Handle tilde expansion and escape file paths for shell execution
        let sourceCommand: String
        if transfer.isDirectory {
            // Use tar for directories
            if transfer.sourcePath.hasPrefix("~/") {
                let pathWithoutTilde = String(transfer.sourcePath.dropFirst(2))
                let escapedPath = pathWithoutTilde
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "'\\''")
                sourceCommand = "tar cf - -C $HOME '\(escapedPath)'"
            } else {
                let dirName = URL(fileURLWithPath: transfer.sourcePath).lastPathComponent
                let parentDir = URL(fileURLWithPath: transfer.sourcePath).deletingLastPathComponent().path
                let escapedDirName = dirName
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "'\\''")
                let escapedParentDir = parentDir
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "'\\''")
                sourceCommand = "tar cf - -C '\(escapedParentDir)' '\(escapedDirName)'"
            }
        } else {
            // Use cat for files
            if transfer.sourcePath.hasPrefix("~/") {
                let pathWithoutTilde = String(transfer.sourcePath.dropFirst(2))
                let escapedPath = pathWithoutTilde
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "'\\''")
                sourceCommand = "cat $HOME/'\(escapedPath)'"
            } else if transfer.sourcePath == "~" {
                sourceCommand = "cat $HOME"
            } else {
                let escapedPath = transfer.sourcePath
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "'\\''")
                sourceCommand = "cat '\(escapedPath)'"
            }
        }
        
        // Add SSH options for better reliability
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
        
        // Add jump host support if configured
        if let jumpHost = sourceProfile.jumpHost {
            sourceArgs.append(contentsOf: ["-J", jumpHost])
        }
        
        // Add source host
        if !sourceProfile.username.isEmpty {
            sourceArgs.append("\(sourceProfile.username)@\(sourceProfile.host)")
        } else {
            sourceArgs.append(sourceProfile.host)
        }
        
        sourceArgs.append(sourceCommand)
        
        // Create process to read from source
        let sourceTask = Process()
        sourceTask.launchPath = "/usr/bin/ssh"
        sourceTask.arguments = sourceArgs
        
        // Build SSH command to connect to destination server and write the file
        var destArgs: [String] = []
        
        // Add SSH options
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
        
        // Add jump host support if configured
        if let jumpHost = destProfile.jumpHost {
            destArgs.append(contentsOf: ["-J", jumpHost])
        }
        
        // Add destination host
        if !destProfile.username.isEmpty {
            destArgs.append("\(destProfile.username)@\(destProfile.host)")
        } else {
            destArgs.append(destProfile.host)
        }
        
        // Handle destination path with tilde expansion
        let destCommand: String
        if transfer.isDirectory {
            // Use tar extraction for directories
            if transfer.destinationPath.hasPrefix("~/") {
                let pathWithoutTilde = String(transfer.destinationPath.dropFirst(2))
                // Extract to the destination directory's parent
                let destParent = URL(fileURLWithPath: pathWithoutTilde).deletingLastPathComponent().path
                if destParent.isEmpty || destParent == "." {
                    destCommand = "cd $HOME && tar xf -"
                } else {
                    let escapedParent = destParent
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "'\\''")
                    destCommand = "mkdir -p $HOME/'\(escapedParent)' && cd $HOME/'\(escapedParent)' && tar xf -"
                }
            } else {
                // Extract to the destination directory's parent
                let destParent = URL(fileURLWithPath: transfer.destinationPath).deletingLastPathComponent().path
                let escapedParent = destParent
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "'\\''")
                destCommand = "mkdir -p '\(escapedParent)' && cd '\(escapedParent)' && tar xf -"
            }
        } else if transfer.destinationPath.hasPrefix("~/") {
            // For paths starting with ~/, use $HOME expansion
            let pathWithoutTilde = String(transfer.destinationPath.dropFirst(2))
            let escapedPath = pathWithoutTilde
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "'\\''")
            
            // Get parent directory for mkdir
            let pathComponents = pathWithoutTilde.split(separator: "/")
            if pathComponents.count > 1 {
                let dirPath = pathComponents.dropLast().joined(separator: "/")
                let escapedDirPath = dirPath
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "'\\''")
                destCommand = "mkdir -p $HOME/'\(escapedDirPath)' && cat > $HOME/'\(escapedPath)'"
            } else {
                // File directly in home directory
                destCommand = "cat > $HOME/'\(escapedPath)'"
            }
        } else if transfer.destinationPath == "~" {
            // Writing directly to home (unusual but handle it)
            destCommand = "cat > $HOME"
        } else {
            // For absolute paths, escape and quote normally
            let escapedPath = transfer.destinationPath
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "'\\''")
            
            // Get parent directory
            let destDir = URL(fileURLWithPath: transfer.destinationPath).deletingLastPathComponent().path
            let escapedDestDir = destDir
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "'\\''")
            
            destCommand = "mkdir -p '\(escapedDestDir)' && cat > '\(escapedPath)'"
        }
        destArgs.append(destCommand)
        
        // Create process to write to destination
        let destTask = Process()
        destTask.launchPath = "/usr/bin/ssh"
        destTask.arguments = destArgs
        
        // Create pipe to connect source output to destination input
        let pipe = Pipe()
        sourceTask.standardOutput = pipe
        destTask.standardInput = pipe
        
        // Create error pipes to capture any errors
        let sourceErrorPipe = Pipe()
        let destErrorPipe = Pipe()
        sourceTask.standardError = sourceErrorPipe
        destTask.standardError = destErrorPipe
        
        print("DEBUG: Server-to-server transfer using SSH tunnel")
        print("DEBUG: Transfer from: \(transfer.sourcePath)")
        print("DEBUG: Transfer to: \(transfer.destinationPath)")
        print("DEBUG: Source command: ssh \(sourceArgs.joined(separator: " "))")
        print("DEBUG: Dest command: ssh \(destArgs.joined(separator: " "))")
        
        // Set up completion handlers
        var sourceCompleted = false
        var transferFailed = false
        
        sourceTask.terminationHandler = { [weak self] process in
            sourceCompleted = true
            
            if process.terminationStatus != 0 {
                let errorData = sourceErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("DEBUG: Source SSH failed with exit code: \(process.terminationStatus)")
                print("DEBUG: Source error: \(errorOutput)")
                print("DEBUG: Failed path: \(transfer.sourcePath)")
                
                if !transferFailed {
                    transferFailed = true
                    DispatchQueue.main.async {
                        let errorMsg = errorOutput.isEmpty ? "SSH connection failed (exit code: \(process.terminationStatus))" : errorOutput
                        self?.updateTransferStatus(transfer.id, status: .failed, error: "Source read failed: \(errorMsg)")
                    }
                }
                
                // Kill destination process if still running
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
                print("DEBUG: Destination error: \(errorOutput)")
                print("DEBUG: Failed path: \(transfer.destinationPath)")
                
                if !transferFailed {
                    transferFailed = true
                    DispatchQueue.main.async {
                        let errorMsg = errorOutput.isEmpty ? "SSH connection failed (exit code: \(process.terminationStatus))" : errorOutput
                        self?.updateTransferStatus(transfer.id, status: .failed, error: "Destination write failed: \(errorMsg)")
                    }
                }
            } else if sourceCompleted && !transferFailed {
                // Both completed successfully
                print("DEBUG: Server-to-server transfer completed successfully")
                DispatchQueue.main.async {
                    self?.updateTransferStatus(transfer.id, status: .completed)
                }
            }
        }
        
        // Start both processes
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
            let task = Process()
            task.launchPath = "/usr/bin/ssh"
            
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
            
            task.arguments = arguments
            
            task.terminationHandler = { process in
                DispatchQueue.main.async {
                    completion(process.terminationStatus == 0)
                }
            }
            
            try? task.run()
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
            let task = Process()
            task.launchPath = "/usr/bin/ssh"
            
            var arguments: [String] = []
            
            // Add connection timeout and disable strict host checking for better reliability
            arguments.append(contentsOf: ["-o", "ConnectTimeout=10"])
            arguments.append(contentsOf: ["-o", "StrictHostKeyChecking=no"])
            arguments.append(contentsOf: ["-o", "UserKnownHostsFile=/dev/null"])
            arguments.append(contentsOf: ["-o", "LogLevel=ERROR"]) // Suppress warnings
            
            if profile.port != 22 {
                arguments.append(contentsOf: ["-p", "\(profile.port)"])
            }
            
            if let keyPath = profile.privateKeyPath ?? profile.identityFile {
                arguments.append(contentsOf: ["-i", keyPath])
            }
            
            // Add jump host if configured
            if let jumpHost = profile.jumpHost {
                arguments.append(contentsOf: ["-J", jumpHost])
            }
            
            // Build the SSH target
            if !profile.username.isEmpty {
                arguments.append("\(profile.username)@\(profile.host)")
            } else {
                arguments.append(profile.host)
            }
            
            // Handle tilde expansion and build the command
            // Need to handle both ~ and full paths
            let command: String
            if path == "~" || path.hasPrefix("~/") {
                // For home directory paths, use $HOME expansion
                let relativePath = path == "~" ? "" : String(path.dropFirst(2))
                command = relativePath.isEmpty ? "rm -rf \"$HOME\"" : "rm -rf \"$HOME/\(relativePath)\""
            } else {
                // For absolute paths, use as-is
                command = "rm -rf \"\(path)\""
            }
            
            arguments.append(command)
            
            print("DEBUG: Delete command: ssh \(arguments.joined(separator: " "))")
            print("DEBUG: Path to delete: \(path)")
            
            task.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            
            task.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        print("DEBUG: Delete successful for path: \(path)")
                        if !output.isEmpty {
                            print("DEBUG: Output: \(output)")
                        }
                        completion(true)
                    } else {
                        print("DEBUG: Delete failed for path: \(path)")
                        print("DEBUG: Exit code: \(process.terminationStatus)")
                        print("DEBUG: Error output: \(errorOutput)")
                        print("DEBUG: Standard output: \(output)")
                        completion(false)
                    }
                }
            }
            
            do {
                try task.run()
            } catch {
                print("Failed to launch SSH process: \(error)")
                completion(false)
            }
        }
    }
}