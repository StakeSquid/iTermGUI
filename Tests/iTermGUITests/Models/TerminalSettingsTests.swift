import Foundation
import Testing
@testable import iTermGUI

@Suite("EmbeddedTerminalSettings defaults")
struct EmbeddedTerminalSettingsDefaultsTests {
    @Test func themeDefaultsToDark() {
        #expect(EmbeddedTerminalSettings().theme == .dark)
    }

    @Test func fontFamilyAndSizeDefaults() {
        let s = EmbeddedTerminalSettings()
        #expect(s.fontFamily == "SF Mono")
        #expect(s.fontSize == 13)
    }

    @Test func lineSpacingDefaultsToOne() {
        #expect(EmbeddedTerminalSettings().lineSpacing == 1.0)
    }

    @Test func cursorDefaultsToBlockAndBlinking() {
        let s = EmbeddedTerminalSettings()
        #expect(s.cursorStyle == .block)
        #expect(s.cursorBlink)
    }

    @Test func boldAndBrightColorsDefaultOn() {
        let s = EmbeddedTerminalSettings()
        #expect(s.useBoldFonts)
        #expect(s.useBrightColors)
    }

    @Test func scrollbackLinesDefaultTo10000() {
        #expect(EmbeddedTerminalSettings().scrollbackLines == 10_000)
    }

    @Test func mouseBehaviorDefaults() {
        let s = EmbeddedTerminalSettings()
        #expect(s.mouseReporting)
        #expect(s.altScreenMouseScroll)
        #expect(s.copyOnSelect == false)
        #expect(s.pasteOnMiddleClick)
        #expect(s.pasteOnRightClick)
    }

    @Test func bellDefaultsToVisual() {
        #expect(EmbeddedTerminalSettings().bellStyle == .visual)
    }

    @Test func connectionDefaults() {
        let s = EmbeddedTerminalSettings()
        #expect(s.onConnectCommands.isEmpty)
        #expect(s.keepAliveInterval == 60)
        #expect(s.autoReconnect)
        #expect(s.reconnectDelay == 5)
    }

    @Test func advancedDefaults() {
        let s = EmbeddedTerminalSettings()
        #expect(s.terminalType == "xterm-256color")
        #expect(s.locale == "en_US.UTF-8")
        #expect(s.enableSixel == false)
        #expect(s.enableOSC52)
    }
}

@Suite("EmbeddedTerminalSettings Codable")
struct EmbeddedTerminalSettingsCodableTests {
    @Test func roundTripPreservesAllFields() throws {
        var original = EmbeddedTerminalSettings()
        original.theme = .dracula
        original.fontSize = 18
        original.bellStyle = .both
        original.onConnectCommands = ["tmux"]
        original.locale = "de_DE.UTF-8"
        original.enableSixel = true

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EmbeddedTerminalSettings.self, from: data)

        #expect(decoded.theme == .dracula)
        #expect(decoded.fontSize == 18)
        #expect(decoded.bellStyle == .both)
        #expect(decoded.onConnectCommands == ["tmux"])
        #expect(decoded.locale == "de_DE.UTF-8")
        #expect(decoded.enableSixel)
    }
}

@Suite("Terminal enum CaseIterable")
struct TerminalEnumCaseIterableTests {
    @Test func terminalCursorStyleHasAllThreeCases() {
        #expect(TerminalCursorStyle.allCases.count == 3)
        #expect(Set(TerminalCursorStyle.allCases) == [.block, .underline, .bar])
    }

    @Test func bellStyleHasAllFourCases() {
        #expect(BellStyle.allCases.count == 4)
        #expect(Set(BellStyle.allCases) == [.none, .visual, .sound, .both])
    }

    @Test func terminalThemeHasAllSevenCases() {
        #expect(TerminalTheme.allCases.count == 7)
        #expect(Set(TerminalTheme.allCases) == [
            .dark, .light, .solarizedDark, .solarizedLight, .dracula, .nord, .oneDark
        ])
    }
}

@Suite("TerminalSettings (profile-scoped) defaults")
struct TerminalSettingsDefaultsTests {
    @Test func allDefaults() {
        let s = TerminalSettings()
        #expect(s.colorScheme == "Default")
        #expect(s.fontSize == 12)
        #expect(s.fontFamily == "Monaco")
        #expect(s.cursorStyle == .block)
        #expect(s.scrollbackLines == 10_000)
    }

    @Test func codableRoundTrip() throws {
        let original = TerminalSettings(colorScheme: "Dracula", fontSize: 14, fontFamily: "Menlo",
                                        cursorStyle: .bar, scrollbackLines: 5000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TerminalSettings.self, from: data)
        #expect(decoded == original)
    }
}
