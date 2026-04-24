import Foundation

struct ProcessLaunch {
    let launchPath: String
    let arguments: [String]
    let stdinData: Data?

    init(launchPath: String, arguments: [String], stdinData: Data? = nil) {
        self.launchPath = launchPath
        self.arguments = arguments
        self.stdinData = stdinData
    }
}

struct ProcessResult {
    let exitCode: Int32
    let stdout: Data
    let stderr: Data

    var stdoutString: String { String(data: stdout, encoding: .utf8) ?? "" }
    var stderrString: String { String(data: stderr, encoding: .utf8) ?? "" }
    var isSuccess: Bool { exitCode == 0 }
}

protocol ProcessRunner {
    func run(_ launch: ProcessLaunch, completion: @escaping (Result<ProcessResult, Error>) -> Void)
}

final class FoundationProcessRunner: ProcessRunner {
    func run(_ launch: ProcessLaunch, completion: @escaping (Result<ProcessResult, Error>) -> Void) {
        let task = Process()
        task.launchPath = launch.launchPath
        task.arguments = launch.arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        if let stdin = launch.stdinData {
            let stdinPipe = Pipe()
            task.standardInput = stdinPipe
            task.terminationHandler = { process in
                let out = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = ProcessResult(exitCode: process.terminationStatus, stdout: out, stderr: err)
                DispatchQueue.main.async { completion(.success(result)) }
            }
            do {
                try task.run()
                stdinPipe.fileHandleForWriting.write(stdin)
                try? stdinPipe.fileHandleForWriting.close()
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
            return
        }

        task.terminationHandler = { process in
            let out = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let result = ProcessResult(exitCode: process.terminationStatus, stdout: out, stderr: err)
            DispatchQueue.main.async { completion(.success(result)) }
        }

        do {
            try task.run()
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
        }
    }
}
