import Foundation
@testable import iTermGUI

final class FakeProcessRunner: ProcessRunner {
    struct Invocation {
        let launch: ProcessLaunch
    }

    private(set) var invocations: [Invocation] = []
    var scripted: [Result<ProcessResult, Error>] = []
    var defaultResult: Result<ProcessResult, Error> = .success(
        ProcessResult(exitCode: 0, stdout: Data(), stderr: Data())
    )

    func run(_ launch: ProcessLaunch, completion: @escaping (Result<ProcessResult, Error>) -> Void) {
        invocations.append(Invocation(launch: launch))
        let result = scripted.isEmpty ? defaultResult : scripted.removeFirst()
        completion(result)
    }

    static func success(stdout: String = "", stderr: String = "", exitCode: Int32 = 0) -> Result<ProcessResult, Error> {
        .success(ProcessResult(
            exitCode: exitCode,
            stdout: Data(stdout.utf8),
            stderr: Data(stderr.utf8)
        ))
    }
}
