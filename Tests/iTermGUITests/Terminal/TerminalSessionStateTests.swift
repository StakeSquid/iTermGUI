import Foundation
import Testing
@testable import iTermGUI

@Suite("TerminalSessionState Equatable")
struct TerminalSessionStateEquatableTests {
    @Test func disconnectedEqualsDisconnected() {
        #expect(TerminalSessionState.disconnected == .disconnected)
    }

    @Test func connectingEqualsConnecting() {
        #expect(TerminalSessionState.connecting == .connecting)
    }

    @Test func connectedEqualsConnected() {
        #expect(TerminalSessionState.connected == .connected)
    }

    @Test func reconnectingEqualsReconnecting() {
        #expect(TerminalSessionState.reconnecting == .reconnecting)
    }

    @Test func errorEqualitySameMessage() {
        #expect(TerminalSessionState.error("x") == .error("x"))
    }

    @Test func errorInequalityDifferentMessage() {
        #expect(TerminalSessionState.error("a") != .error("b"))
    }

    @Test func distinctCasesNotEqual() {
        #expect(TerminalSessionState.connecting != .connected)
        #expect(TerminalSessionState.disconnected != .error("x"))
        #expect(TerminalSessionState.reconnecting != .connected)
    }
}

@Suite("TerminalSessionState CustomStringConvertible")
struct TerminalSessionStateDescriptionTests {
    @Test func disconnectedDescribesAsDisconnected() {
        #expect(TerminalSessionState.disconnected.description == "Disconnected")
    }

    @Test func connectingDescribesAsConnecting() {
        #expect(TerminalSessionState.connecting.description == "Connecting")
    }

    @Test func connectedDescribesAsConnected() {
        #expect(TerminalSessionState.connected.description == "Connected")
    }

    @Test func reconnectingDescribesAsReconnecting() {
        #expect(TerminalSessionState.reconnecting.description == "Reconnecting")
    }

    @Test func errorDescriptionIncludesMessage() {
        #expect(TerminalSessionState.error("timeout").description == "Error: timeout")
    }

    @Test func errorWithEmptyMessageStillValid() {
        #expect(TerminalSessionState.error("").description == "Error: ")
    }
}
