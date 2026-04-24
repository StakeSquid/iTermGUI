import Foundation
import Testing
@testable import iTermGUI

@Suite("ITerm2Service.createITerm2Profile dictionary keys")
struct ITerm2ProfileDictKeysTests {
    private func service() -> ITerm2Service { makeStubITerm2Service() }

    @Test func containsCoreKeys() {
        let profile = makeProfile(name: "my-host", host: "my.example.com",
                                   username: "u", tags: ["prod"])
        let dict = service().createITerm2Profile(from: profile)
        #expect(dict["Name"] as? String == "my-host")
        #expect(dict["Guid"] as? String == profile.id.uuidString)
        #expect(dict["Custom Command"] as? String == "Yes")
        #expect(dict["Terminal Type"] as? String == "xterm-256color")
        #expect(dict["Close Sessions On End"] as? Bool == true)
        #expect(dict["Columns"] as? Int == 200)
        #expect(dict["Rows"] as? Int == 50)
    }

    @Test func badgeTextMatchesHost() {
        let profile = makeProfile(host: "displayed.example.com")
        let dict = service().createITerm2Profile(from: profile)
        #expect(dict["Badge Text"] as? String == "displayed.example.com")
    }

    @Test func tagsArrayIncludesAllTags() {
        let profile = makeProfile(tags: ["prod", "critical"])
        let dict = service().createITerm2Profile(from: profile)
        let tags = dict["Tags"] as? [String]
        #expect(Set(tags ?? []) == ["prod", "critical"])
    }

    @Test func commandMatchesBuildSSHCommand() {
        let svc = service()
        let profile = makeProfile(host: "h", username: "u")
        let dict = svc.createITerm2Profile(from: profile)
        #expect(dict["Command"] as? String == svc.buildSSHCommand(from: profile))
    }

    @Test func initialTextEmptyWhenNoCustomCommands() {
        let dict = service().createITerm2Profile(from: makeProfile(customCommands: []))
        #expect(dict["Initial Text"] as? String == "")
    }

    @Test func initialTextJoinsCustomCommandsWithSemicolonAndTrailingNewline() {
        let dict = service().createITerm2Profile(from: makeProfile(customCommands: ["uptime", "hostname"]))
        #expect(dict["Initial Text"] as? String == "uptime; hostname\n")
    }

    @Test func normalFontCombinesFamilyAndSize() {
        var terminal = TerminalSettings()
        terminal.fontFamily = "Menlo"
        terminal.fontSize = 14
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Normal Font"] as? String == "Menlo 14")
    }

    @Test func scrollbackLinesMatchesTerminalSettings() {
        var terminal = TerminalSettings()
        terminal.scrollbackLines = 5000
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Scrollback Lines"] as? Int == 5000)
    }
}

@Suite("ITerm2Service cursor type mapping")
struct ITerm2ProfileCursorTypeTests {
    private func service() -> ITerm2Service { makeStubITerm2Service() }

    @Test func blockMapsToTwo() {
        var terminal = TerminalSettings()
        terminal.cursorStyle = .block
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Cursor Type"] as? Int == 2)
    }

    @Test func barMapsToOne() {
        var terminal = TerminalSettings()
        terminal.cursorStyle = .bar
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Cursor Type"] as? Int == 1)
    }

    @Test func underlineMapsToZero() {
        var terminal = TerminalSettings()
        terminal.cursorStyle = .underline
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Cursor Type"] as? Int == 0)
    }
}

@Suite("ITerm2Service color scheme merge")
struct ITerm2ColorSchemeTests {
    private func service() -> ITerm2Service { makeStubITerm2Service() }

    @Test func knownSchemeSolarizedDarkAddsColorKeys() {
        var terminal = TerminalSettings()
        terminal.colorScheme = "Solarized Dark"
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Background Color"] != nil)
        #expect(dict["Foreground Color"] != nil)
    }

    @Test func unknownSchemeDoesNotAddColorKeysAndDoesNotCrash() {
        var terminal = TerminalSettings()
        terminal.colorScheme = "Made-Up Theme 9000"
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Background Color"] == nil)
        #expect(dict["Foreground Color"] == nil)
    }

    @Test func defaultSchemeAddsNoColorKeysButLookupSucceeds() {
        // "Default" returns an empty [String: Any] which merges to nothing.
        var terminal = TerminalSettings()
        terminal.colorScheme = "Default"
        let dict = service().createITerm2Profile(from: makeProfile(terminalSettings: terminal))
        #expect(dict["Background Color"] == nil)
    }
}

@Suite("ITerm2Service.getColorScheme")
struct ITerm2GetColorSchemeTests {
    @Test func knownSchemesReturnValues() {
        let svc = makeStubITerm2Service()
        #expect(svc.getColorScheme(named: "Solarized Dark") != nil)
        #expect(svc.getColorScheme(named: "Solarized Light") != nil)
        #expect(svc.getColorScheme(named: "Dracula") != nil)
        #expect(svc.getColorScheme(named: "Default") != nil)
    }

    @Test func unknownSchemeReturnsNil() {
        let svc = makeStubITerm2Service()
        #expect(svc.getColorScheme(named: "Not a real scheme") == nil)
    }

    @Test func lookupIsCaseSensitive() {
        let svc = makeStubITerm2Service()
        #expect(svc.getColorScheme(named: "solarized dark") == nil)
    }
}
