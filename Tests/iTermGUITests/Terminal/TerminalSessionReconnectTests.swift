import Foundation
import Testing
@testable import iTermGUI

@Suite("TerminalSession.reconnect state machine")
struct TerminalSessionReconnectTests {
    private func session(autoReconnect: Bool = true, reconnectDelay: Int = 5) -> TerminalSession {
        var settings = EmbeddedTerminalSettings()
        settings.autoReconnect = autoReconnect
        settings.reconnectDelay = reconnectDelay
        return TerminalSession(profile: makeProfile(), settings: settings)
    }

    @Test func autoReconnectFalseSetsDisconnected() {
        let s = session(autoReconnect: false)
        s.state = .connected
        s.reconnect()
        #expect(s.state == .disconnected)
    }

    @Test func firstReconnectAttemptSetsReconnecting() {
        let s = session(autoReconnect: true)
        s.state = .disconnected
        s.reconnect()
        #expect(s.state == .reconnecting)
    }

    @Test func reconnectCapsAtFiveAttempts() {
        let s = session(autoReconnect: true, reconnectDelay: 0)
        // First 5 attempts all set state to .reconnecting (they schedule a timer we don't assert)
        for _ in 0..<5 {
            s.reconnect()
            #expect(s.state == .reconnecting)
        }
        // 6th attempt should fail with error state (maxReconnectAttempts reached)
        s.reconnect()
        if case .error(let msg) = s.state {
            #expect(msg == "Maximum reconnection attempts reached")
        } else {
            Issue.record("Expected .error state after 6 attempts, got \(s.state)")
        }
    }
}

@Suite("TerminalSession.handleDisconnection")
struct TerminalSessionHandleDisconnectionTests {
    @Test func autoReconnectFalseDisconnects() {
        var settings = EmbeddedTerminalSettings()
        settings.autoReconnect = false
        let s = TerminalSession(profile: makeProfile(), settings: settings)

        s.handleDisconnection()
        #expect(s.state == .disconnected)
    }

    @Test func autoReconnectTrueTriggersReconnecting() {
        var settings = EmbeddedTerminalSettings()
        settings.autoReconnect = true
        let s = TerminalSession(profile: makeProfile(), settings: settings)

        s.handleDisconnection()
        #expect(s.state == .reconnecting)
    }
}

@Suite("TerminalSession.updateProfile")
struct TerminalSessionUpdateProfileTests {
    @Test func replacesStoredProfile() {
        let s = TerminalSession(profile: makeProfile(name: "original"), settings: EmbeddedTerminalSettings())
        #expect(s.sshProfile.name == "original")

        s.updateProfile(makeProfile(name: "updated"))
        #expect(s.sshProfile.name == "updated")
    }
}

@Suite("TerminalSession init")
struct TerminalSessionInitTests {
    @Test func capturesProfileIdentityFields() {
        let profile = makeProfile(name: "pn", host: "h")
        let s = TerminalSession(profile: profile, settings: EmbeddedTerminalSettings())
        #expect(s.profileId == profile.id)
        #expect(s.profileName == "pn")
        #expect(s.title == "pn")
    }

    @Test func initialStateIsDisconnected() {
        let s = TerminalSession(profile: makeProfile(), settings: EmbeddedTerminalSettings())
        #expect(s.state == .disconnected)
    }

    @Test func eachInstanceHasUniqueID() {
        let a = TerminalSession(profile: makeProfile(), settings: EmbeddedTerminalSettings())
        let b = TerminalSession(profile: makeProfile(), settings: EmbeddedTerminalSettings())
        #expect(a.id != b.id)
    }
}
