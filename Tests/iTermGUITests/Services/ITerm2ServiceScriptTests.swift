import Foundation
import Testing
@testable import iTermGUI

@Suite("ITerm2Service.launchScriptForProfile")
struct ITerm2LaunchScriptForProfileTests {
    private func service() -> ITerm2Service { makeStubITerm2Service() }

    @Test func includesProfileNameInCreateWindow() {
        let script = service().launchScriptForProfile("my-prod", newWindow: true)
        #expect(script.contains("create window with profile \"my-prod\""))
    }

    @Test func includesProfileNameAsSessionName() {
        let script = service().launchScriptForProfile("my-prod", newWindow: true)
        #expect(script.contains("set name to \"my-prod\""))
    }

    @Test func newWindowTrueProducesTrueBranch() {
        let script = service().launchScriptForProfile("p", newWindow: true)
        #expect(script.contains("if true or"))
    }

    @Test func newWindowFalseProducesFalseBranch() {
        let script = service().launchScriptForProfile("p", newWindow: false)
        #expect(script.contains("if false or"))
    }

    @Test func containsColumnsAndRowsSetup() {
        let script = service().launchScriptForProfile("p", newWindow: true)
        #expect(script.contains("set columns to 200"))
        #expect(script.contains("set rows to 50"))
    }
}

@Suite("ITerm2Service.launchScriptForTabs")
struct ITerm2LaunchScriptForTabsTests {
    private func service() -> ITerm2Service { makeStubITerm2Service() }

    @Test func firstProfileOpensAsWindow() {
        let script = service().launchScriptForTabs(["a", "b", "c"])
        #expect(script.contains("create window with profile \"a\""))
    }

    @Test func remainingProfilesAreOpenedAsTabs() {
        let script = service().launchScriptForTabs(["a", "b", "c"])
        #expect(script.contains("create tab with profile \"b\""))
        #expect(script.contains("create tab with profile \"c\""))
    }

    @Test func singleProfileHasNoTabSection() {
        let script = service().launchScriptForTabs(["only"])
        #expect(script.contains("create window with profile \"only\""))
        #expect(script.contains("create tab with profile") == false)
    }
}

@Suite("ITerm2Service.launchScriptForLocalhost")
struct ITerm2LaunchScriptForLocalhostTests {
    @Test func scriptTargetsLocalhostNameAndDefaultProfile() {
        let script = makeStubITerm2Service().launchScriptForLocalhost()
        #expect(script.contains("default profile"))
        #expect(script.contains("\"Localhost\""))
    }
}

@Suite("ITerm2Service runs AppleScript via injected runner")
struct ITerm2ScriptRunnerInvocationTests {
    @Test func openLocalhostInvokesScriptRunnerWithLocalhostScript() {
        let fake = FakeAppleScriptRunner()
        let svc = makeStubITerm2Service(scriptRunner: fake)
        svc.openLocalhost()
        #expect(fake.invocations.count == 1)
        #expect(fake.invocations[0].contains("Localhost"))
    }

    @Test func failureIsCaughtAndNotPropagated() {
        let fake = FakeAppleScriptRunner()
        fake.nextResult = .failure(AppleScriptError(message: "no permission"))
        let svc = makeStubITerm2Service(scriptRunner: fake)
        // Should not throw/crash
        svc.openLocalhost()
        #expect(fake.invocations.count == 1)
    }
}

/// Documents the AppleScript-injection vulnerability: profile names are interpolated
/// into the script source without escaping. A follow-up security PR should escape
/// `"` and `\`. These tests lock in current behavior so the fix PR has a harness.
@Suite("ITerm2Service AppleScript injection (current behavior)")
struct ITerm2AppleScriptInjectionTests {
    @Test func profileNameWithDoubleQuoteIsLiterallyInterpolated() {
        let script = makeStubITerm2Service()
            .launchScriptForProfile("normal\"; close windows; tell \"x", newWindow: true)
        // The raw string (including the embedded `"`) is present verbatim — confirming
        // there's no escaping today. A fix PR should make this assertion fail by
        // escaping the injected name before interpolation.
        #expect(script.contains("normal\"; close windows; tell \"x"))
    }

    @Test func profileNameWithBackslashIsLiterallyInterpolated() {
        let script = makeStubITerm2Service()
            .launchScriptForProfile("back\\slash", newWindow: true)
        #expect(script.contains("back\\slash"))
    }
}
