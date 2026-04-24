import Foundation
@testable import iTermGUI

final class FakeAppleScriptRunner: AppleScriptRunner {
    private(set) var invocations: [String] = []
    var nextResult: Result<String, AppleScriptError> = .success("")

    func run(source: String) -> Result<String, AppleScriptError> {
        invocations.append(source)
        return nextResult
    }
}
