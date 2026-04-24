import Foundation

struct AppleScriptError: Error, Equatable {
    let message: String
}

protocol AppleScriptRunner {
    func run(source: String) -> Result<String, AppleScriptError>
}

final class NSAppleScriptRunner: AppleScriptRunner {
    func run(source: String) -> Result<String, AppleScriptError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(AppleScriptError(message: "Failed to compile AppleScript"))
        }
        var errorDict: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error"
            return .failure(AppleScriptError(message: message))
        }
        return .success(descriptor.stringValue ?? "")
    }
}
