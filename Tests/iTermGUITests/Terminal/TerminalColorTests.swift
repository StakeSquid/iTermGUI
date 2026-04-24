import Foundation
import AppKit
import Testing
@testable import iTermGUI

@Suite("TerminalColor component init")
struct TerminalColorComponentInitTests {
    @Test func storesComponents() {
        let c = TerminalColor(red: 0.5, green: 0.25, blue: 0.125, alpha: 0.9)
        #expect(c.red == 0.5)
        #expect(c.green == 0.25)
        #expect(c.blue == 0.125)
        #expect(c.alpha == 0.9)
    }

    @Test func alphaDefaultsToOne() {
        let c = TerminalColor(red: 0, green: 0, blue: 0)
        #expect(c.alpha == 1.0)
    }

    @Test func clearConstantIsAllZeroAlpha() {
        let c = TerminalColor.clear
        #expect(c.red == 0)
        #expect(c.green == 0)
        #expect(c.blue == 0)
        #expect(c.alpha == 0)
    }
}

@Suite("TerminalColor init(nsColor:)")
struct TerminalColorNSColorInitTests {
    @Test func preservesComponentsFromDeviceRGB() {
        // Use deviceRGB directly to avoid colorspace-conversion failures in headless CI
        let nsc = NSColor(deviceRed: 0.5, green: 0.25, blue: 0.75, alpha: 0.9)
        let c = TerminalColor(nsColor: nsc)
        #expect(abs(c.red - 0.5) < 0.001)
        #expect(abs(c.green - 0.25) < 0.001)
        #expect(abs(c.blue - 0.75) < 0.001)
        #expect(abs(c.alpha - 0.9) < 0.001)
    }

    @Test func roundTripNSColorTerminalColorMatches() {
        let original = NSColor(deviceRed: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
        let terminal = TerminalColor(nsColor: original)
        let back = terminal.nsColor
        #expect(abs(back.redComponent - 0.1) < 0.001)
        #expect(abs(back.greenComponent - 0.2) < 0.001)
        #expect(abs(back.blueComponent - 0.3) < 0.001)
    }
}

@Suite("TerminalColor Codable and Hashable")
struct TerminalColorCodableTests {
    @Test func roundTripPreservesComponents() throws {
        let original = TerminalColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 0.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TerminalColor.self, from: data)
        #expect(decoded == original)
    }

    @Test func hashableEqualityOnComponents() {
        let a = TerminalColor(red: 0.1, green: 0.2, blue: 0.3)
        let b = TerminalColor(red: 0.1, green: 0.2, blue: 0.3)
        let c = TerminalColor(red: 0.1, green: 0.2, blue: 0.4)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
    }
}
