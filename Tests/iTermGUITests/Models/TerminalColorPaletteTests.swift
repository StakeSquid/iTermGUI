import Foundation
import Testing
@testable import iTermGUI

@Suite("TerminalTheme.colors dispatch")
struct TerminalThemeColorsTests {
    @Test func darkReturnsDarkPalette() {
        #expect(TerminalTheme.dark.colors == TerminalColorPalette.dark)
    }

    @Test func lightReturnsLightPalette() {
        #expect(TerminalTheme.light.colors == TerminalColorPalette.light)
    }

    @Test func solarizedDarkReturnsSolarizedDarkPalette() {
        #expect(TerminalTheme.solarizedDark.colors == TerminalColorPalette.solarizedDark)
    }

    @Test func solarizedLightReturnsSolarizedLightPalette() {
        #expect(TerminalTheme.solarizedLight.colors == TerminalColorPalette.solarizedLight)
    }

    @Test func draculaReturnsDraculaPalette() {
        #expect(TerminalTheme.dracula.colors == TerminalColorPalette.dracula)
    }

    @Test func nordReturnsNordPalette() {
        #expect(TerminalTheme.nord.colors == TerminalColorPalette.nord)
    }

    @Test func oneDarkReturnsOneDarkPalette() {
        #expect(TerminalTheme.oneDark.colors == TerminalColorPalette.oneDark)
    }

    @Test func eachThemeReturnsDistinctBackground() {
        let allBackgrounds = TerminalTheme.allCases.map { $0.colors.background }
        #expect(Set(allBackgrounds).count == TerminalTheme.allCases.count)
    }
}

@Suite("TerminalColorPalette.dark constant")
struct TerminalColorPaletteDarkTests {
    @Test func backgroundIsNearBlack() {
        let bg = TerminalColorPalette.dark.background
        #expect(bg.red == 0.1)
        #expect(bg.green == 0.1)
        #expect(bg.blue == 0.1)
    }

    @Test func brightWhiteIsFullWhite() {
        let w = TerminalColorPalette.dark.brightWhite
        #expect(w.red == 1 && w.green == 1 && w.blue == 1)
    }

    @Test func blackIsTrueBlack() {
        let b = TerminalColorPalette.dark.black
        #expect(b.red == 0 && b.green == 0 && b.blue == 0)
    }
}

@Suite("TerminalColorPalette.solarizedDark constant")
struct TerminalColorPaletteSolarizedDarkTests {
    @Test func backgroundMatchesSolarizedBase03() {
        let bg = TerminalColorPalette.solarizedDark.background
        #expect(abs(bg.red - 0.0) < 0.0001)
        #expect(abs(bg.green - 0.168627) < 0.0001)
        #expect(abs(bg.blue - 0.211765) < 0.0001)
    }
}

@Suite("TerminalColorPalette components are in [0, 1]")
struct TerminalColorPaletteRangeTests {
    @Test(arguments: TerminalTheme.allCases)
    func allPaletteColorsInRange(theme: TerminalTheme) {
        let palette = theme.colors
        let colors: [TerminalColor] = [
            palette.background, palette.foreground, palette.cursor, palette.selection,
            palette.black, palette.red, palette.green, palette.yellow,
            palette.blue, palette.magenta, palette.cyan, palette.white,
            palette.brightBlack, palette.brightRed, palette.brightGreen, palette.brightYellow,
            palette.brightBlue, palette.brightMagenta, palette.brightCyan, palette.brightWhite
        ]
        for c in colors {
            #expect((0...1).contains(c.red))
            #expect((0...1).contains(c.green))
            #expect((0...1).contains(c.blue))
            #expect((0...1).contains(c.alpha))
        }
    }
}

@Suite("TerminalColorPalette Codable")
struct TerminalColorPaletteCodableTests {
    @Test func roundTripPreservesAllColors() throws {
        let original = TerminalColorPalette.dracula
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TerminalColorPalette.self, from: data)
        #expect(decoded == original)
    }
}
