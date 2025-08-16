import Foundation
import SwiftUI

struct EmbeddedTerminalSettings: Codable, Hashable {
    // Visual Settings
    var theme: TerminalTheme = .dark
    var fontFamily: String = "SF Mono"
    var fontSize: CGFloat = 13
    var lineSpacing: CGFloat = 1.0
    var cursorStyle: TerminalCursorStyle = .block
    var cursorBlink: Bool = true
    var useBoldFonts: Bool = true
    var useBrightColors: Bool = true
    
    // Behavior Settings
    var scrollbackLines: Int = 10000
    var mouseReporting: Bool = true
    var altScreenMouseScroll: Bool = true
    var copyOnSelect: Bool = false
    var pasteOnMiddleClick: Bool = true
    var bellStyle: BellStyle = .visual
    
    // Connection Settings
    var onConnectCommands: [String] = []
    var keepAliveInterval: Int = 60
    var autoReconnect: Bool = true
    var reconnectDelay: Int = 5
    
    // Advanced Settings
    var terminalType: String = "xterm-256color"
    var locale: String = "en_US.UTF-8"
    var enableSixel: Bool = false
    var enableOSC52: Bool = true // Clipboard integration
}

enum TerminalCursorStyle: String, Codable, CaseIterable {
    case block = "Block"
    case underline = "Underline"
    case bar = "Bar"
}

enum BellStyle: String, Codable, CaseIterable {
    case none = "None"
    case visual = "Visual"
    case sound = "Sound"
    case both = "Both"
}

enum TerminalTheme: String, Codable, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case solarizedDark = "Solarized Dark"
    case solarizedLight = "Solarized Light"
    case dracula = "Dracula"
    case nord = "Nord"
    case oneDark = "One Dark"
    
    var colors: TerminalColorPalette {
        switch self {
        case .dark:
            return TerminalColorPalette.dark
        case .light:
            return TerminalColorPalette.light
        case .solarizedDark:
            return TerminalColorPalette.solarizedDark
        case .solarizedLight:
            return TerminalColorPalette.solarizedLight
        case .dracula:
            return TerminalColorPalette.dracula
        case .nord:
            return TerminalColorPalette.nord
        case .oneDark:
            return TerminalColorPalette.oneDark
        }
    }
}

struct TerminalColorPalette: Codable, Hashable {
    var background: TerminalColor
    var foreground: TerminalColor
    var cursor: TerminalColor
    var selection: TerminalColor
    
    // ANSI colors (0-15)
    var black: TerminalColor
    var red: TerminalColor
    var green: TerminalColor
    var yellow: TerminalColor
    var blue: TerminalColor
    var magenta: TerminalColor
    var cyan: TerminalColor
    var white: TerminalColor
    var brightBlack: TerminalColor
    var brightRed: TerminalColor
    var brightGreen: TerminalColor
    var brightYellow: TerminalColor
    var brightBlue: TerminalColor
    var brightMagenta: TerminalColor
    var brightCyan: TerminalColor
    var brightWhite: TerminalColor
    
    static let dark = TerminalColorPalette(
        background: TerminalColor(red: 0.1, green: 0.1, blue: 0.1),
        foreground: TerminalColor(red: 0.9, green: 0.9, blue: 0.9),
        cursor: TerminalColor(red: 0.8, green: 0.8, blue: 0.8),
        selection: TerminalColor(red: 0.3, green: 0.3, blue: 0.5),
        black: TerminalColor(red: 0, green: 0, blue: 0),
        red: TerminalColor(red: 0.8, green: 0, blue: 0),
        green: TerminalColor(red: 0, green: 0.8, blue: 0),
        yellow: TerminalColor(red: 0.8, green: 0.8, blue: 0),
        blue: TerminalColor(red: 0, green: 0, blue: 0.8),
        magenta: TerminalColor(red: 0.8, green: 0, blue: 0.8),
        cyan: TerminalColor(red: 0, green: 0.8, blue: 0.8),
        white: TerminalColor(red: 0.8, green: 0.8, blue: 0.8),
        brightBlack: TerminalColor(red: 0.4, green: 0.4, blue: 0.4),
        brightRed: TerminalColor(red: 1, green: 0.2, blue: 0.2),
        brightGreen: TerminalColor(red: 0.2, green: 1, blue: 0.2),
        brightYellow: TerminalColor(red: 1, green: 1, blue: 0.2),
        brightBlue: TerminalColor(red: 0.2, green: 0.2, blue: 1),
        brightMagenta: TerminalColor(red: 1, green: 0.2, blue: 1),
        brightCyan: TerminalColor(red: 0.2, green: 1, blue: 1),
        brightWhite: TerminalColor(red: 1, green: 1, blue: 1)
    )
    
    static let light = TerminalColorPalette(
        background: TerminalColor(red: 1, green: 1, blue: 1),
        foreground: TerminalColor(red: 0.1, green: 0.1, blue: 0.1),
        cursor: TerminalColor(red: 0.2, green: 0.2, blue: 0.2),
        selection: TerminalColor(red: 0.7, green: 0.7, blue: 0.9),
        black: TerminalColor(red: 0, green: 0, blue: 0),
        red: TerminalColor(red: 0.7, green: 0, blue: 0),
        green: TerminalColor(red: 0, green: 0.6, blue: 0),
        yellow: TerminalColor(red: 0.6, green: 0.6, blue: 0),
        blue: TerminalColor(red: 0, green: 0, blue: 0.7),
        magenta: TerminalColor(red: 0.7, green: 0, blue: 0.7),
        cyan: TerminalColor(red: 0, green: 0.6, blue: 0.6),
        white: TerminalColor(red: 0.7, green: 0.7, blue: 0.7),
        brightBlack: TerminalColor(red: 0.3, green: 0.3, blue: 0.3),
        brightRed: TerminalColor(red: 0.9, green: 0.1, blue: 0.1),
        brightGreen: TerminalColor(red: 0.1, green: 0.8, blue: 0.1),
        brightYellow: TerminalColor(red: 0.9, green: 0.9, blue: 0.1),
        brightBlue: TerminalColor(red: 0.1, green: 0.1, blue: 0.9),
        brightMagenta: TerminalColor(red: 0.9, green: 0.1, blue: 0.9),
        brightCyan: TerminalColor(red: 0.1, green: 0.9, blue: 0.9),
        brightWhite: TerminalColor(red: 0.9, green: 0.9, blue: 0.9)
    )
    
    static let solarizedDark = TerminalColorPalette(
        background: TerminalColor(red: 0, green: 0.168627, blue: 0.211765),
        foreground: TerminalColor(red: 0.513726, green: 0.580392, blue: 0.588235),
        cursor: TerminalColor(red: 0.513726, green: 0.580392, blue: 0.588235),
        selection: TerminalColor(red: 0.027451, green: 0.211765, blue: 0.258824),
        black: TerminalColor(red: 0.027451, green: 0.211765, blue: 0.258824),
        red: TerminalColor(red: 0.862745, green: 0.196078, blue: 0.184314),
        green: TerminalColor(red: 0.521569, green: 0.6, blue: 0),
        yellow: TerminalColor(red: 0.709804, green: 0.537255, blue: 0),
        blue: TerminalColor(red: 0.149020, green: 0.545098, blue: 0.823529),
        magenta: TerminalColor(red: 0.827451, green: 0.211765, blue: 0.509804),
        cyan: TerminalColor(red: 0.164706, green: 0.631373, blue: 0.596078),
        white: TerminalColor(red: 0.933333, green: 0.909804, blue: 0.835294),
        brightBlack: TerminalColor(red: 0, green: 0.168627, blue: 0.211765),
        brightRed: TerminalColor(red: 0.796078, green: 0.294118, blue: 0.086275),
        brightGreen: TerminalColor(red: 0.345098, green: 0.431373, blue: 0.458824),
        brightYellow: TerminalColor(red: 0.396078, green: 0.482353, blue: 0.513726),
        brightBlue: TerminalColor(red: 0.513726, green: 0.580392, blue: 0.588235),
        brightMagenta: TerminalColor(red: 0.423529, green: 0.443137, blue: 0.768627),
        brightCyan: TerminalColor(red: 0.576471, green: 0.631373, blue: 0.631373),
        brightWhite: TerminalColor(red: 0.992157, green: 0.964706, blue: 0.890196)
    )
    
    static let solarizedLight = TerminalColorPalette(
        background: TerminalColor(red: 0.992157, green: 0.964706, blue: 0.890196),
        foreground: TerminalColor(red: 0.396078, green: 0.482353, blue: 0.513726),
        cursor: TerminalColor(red: 0.396078, green: 0.482353, blue: 0.513726),
        selection: TerminalColor(red: 0.933333, green: 0.909804, blue: 0.835294),
        black: TerminalColor(red: 0.027451, green: 0.211765, blue: 0.258824),
        red: TerminalColor(red: 0.862745, green: 0.196078, blue: 0.184314),
        green: TerminalColor(red: 0.521569, green: 0.6, blue: 0),
        yellow: TerminalColor(red: 0.709804, green: 0.537255, blue: 0),
        blue: TerminalColor(red: 0.149020, green: 0.545098, blue: 0.823529),
        magenta: TerminalColor(red: 0.827451, green: 0.211765, blue: 0.509804),
        cyan: TerminalColor(red: 0.164706, green: 0.631373, blue: 0.596078),
        white: TerminalColor(red: 0.933333, green: 0.909804, blue: 0.835294),
        brightBlack: TerminalColor(red: 0, green: 0.168627, blue: 0.211765),
        brightRed: TerminalColor(red: 0.796078, green: 0.294118, blue: 0.086275),
        brightGreen: TerminalColor(red: 0.345098, green: 0.431373, blue: 0.458824),
        brightYellow: TerminalColor(red: 0.396078, green: 0.482353, blue: 0.513726),
        brightBlue: TerminalColor(red: 0.513726, green: 0.580392, blue: 0.588235),
        brightMagenta: TerminalColor(red: 0.423529, green: 0.443137, blue: 0.768627),
        brightCyan: TerminalColor(red: 0.576471, green: 0.631373, blue: 0.631373),
        brightWhite: TerminalColor(red: 0.992157, green: 0.964706, blue: 0.890196)
    )
    
    static let dracula = TerminalColorPalette(
        background: TerminalColor(red: 0.156863, green: 0.164706, blue: 0.211765),
        foreground: TerminalColor(red: 0.972549, green: 0.972549, blue: 0.949020),
        cursor: TerminalColor(red: 0.972549, green: 0.972549, blue: 0.949020),
        selection: TerminalColor(red: 0.262745, green: 0.278431, blue: 0.352941),
        black: TerminalColor(red: 0.156863, green: 0.164706, blue: 0.211765),
        red: TerminalColor(red: 1, green: 0.333333, blue: 0.333333),
        green: TerminalColor(red: 0.313726, green: 0.980392, blue: 0.482353),
        yellow: TerminalColor(red: 0.945098, green: 0.980392, blue: 0.549020),
        blue: TerminalColor(red: 0.741176, green: 0.576471, blue: 0.976471),
        magenta: TerminalColor(red: 1, green: 0.470588, blue: 0.776471),
        cyan: TerminalColor(red: 0.541176, green: 0.913725, blue: 0.992157),
        white: TerminalColor(red: 0.972549, green: 0.972549, blue: 0.949020),
        brightBlack: TerminalColor(red: 0.262745, green: 0.278431, blue: 0.352941),
        brightRed: TerminalColor(red: 1, green: 0.423529, blue: 0.423529),
        brightGreen: TerminalColor(red: 0.403922, green: 0.980392, blue: 0.572549),
        brightYellow: TerminalColor(red: 0.945098, green: 0.980392, blue: 0.639216),
        brightBlue: TerminalColor(red: 0.831373, green: 0.666667, blue: 0.976471),
        brightMagenta: TerminalColor(red: 1, green: 0.560784, blue: 0.866667),
        brightCyan: TerminalColor(red: 0.631373, green: 0.913725, blue: 0.992157),
        brightWhite: TerminalColor(red: 1, green: 1, blue: 1)
    )
    
    static let nord = TerminalColorPalette(
        background: TerminalColor(red: 0.180392, green: 0.203922, blue: 0.250980),
        foreground: TerminalColor(red: 0.847059, green: 0.870588, blue: 0.913725),
        cursor: TerminalColor(red: 0.847059, green: 0.870588, blue: 0.913725),
        selection: TerminalColor(red: 0.262745, green: 0.298039, blue: 0.368627),
        black: TerminalColor(red: 0.231373, green: 0.258824, blue: 0.321569),
        red: TerminalColor(red: 0.749020, green: 0.380392, blue: 0.415686),
        green: TerminalColor(red: 0.639216, green: 0.745098, blue: 0.549020),
        yellow: TerminalColor(red: 0.921569, green: 0.796078, blue: 0.545098),
        blue: TerminalColor(red: 0.505882, green: 0.631373, blue: 0.756863),
        magenta: TerminalColor(red: 0.705882, green: 0.556863, blue: 0.678431),
        cyan: TerminalColor(red: 0.537255, green: 0.752941, blue: 0.682353),
        white: TerminalColor(red: 0.898039, green: 0.913725, blue: 0.941176),
        brightBlack: TerminalColor(red: 0.301961, green: 0.337255, blue: 0.415686),
        brightRed: TerminalColor(red: 0.749020, green: 0.380392, blue: 0.415686),
        brightGreen: TerminalColor(red: 0.639216, green: 0.745098, blue: 0.549020),
        brightYellow: TerminalColor(red: 0.921569, green: 0.796078, blue: 0.545098),
        brightBlue: TerminalColor(red: 0.505882, green: 0.631373, blue: 0.756863),
        brightMagenta: TerminalColor(red: 0.705882, green: 0.556863, blue: 0.678431),
        brightCyan: TerminalColor(red: 0.568627, green: 0.733333, blue: 0.717647),
        brightWhite: TerminalColor(red: 0.925490, green: 0.937255, blue: 0.956863)
    )
    
    static let oneDark = TerminalColorPalette(
        background: TerminalColor(red: 0.156863, green: 0.172549, blue: 0.203922),
        foreground: TerminalColor(red: 0.670588, green: 0.698039, blue: 0.745098),
        cursor: TerminalColor(red: 0.670588, green: 0.698039, blue: 0.745098),
        selection: TerminalColor(red: 0.231373, green: 0.254902, blue: 0.305882),
        black: TerminalColor(red: 0.156863, green: 0.172549, blue: 0.203922),
        red: TerminalColor(red: 0.878431, green: 0.423529, blue: 0.458824),
        green: TerminalColor(red: 0.596078, green: 0.764706, blue: 0.470588),
        yellow: TerminalColor(red: 0.819608, green: 0.705882, blue: 0.403922),
        blue: TerminalColor(red: 0.384314, green: 0.631373, blue: 0.968627),
        magenta: TerminalColor(red: 0.776471, green: 0.447059, blue: 0.784314),
        cyan: TerminalColor(red: 0.337255, green: 0.713726, blue: 0.756863),
        white: TerminalColor(red: 0.670588, green: 0.698039, blue: 0.745098),
        brightBlack: TerminalColor(red: 0.356863, green: 0.388235, blue: 0.454902),
        brightRed: TerminalColor(red: 0.905882, green: 0.533333, blue: 0.556863),
        brightGreen: TerminalColor(red: 0.678431, green: 0.807843, blue: 0.568627),
        brightYellow: TerminalColor(red: 0.878431, green: 0.780392, blue: 0.525490),
        brightBlue: TerminalColor(red: 0.509804, green: 0.694118, blue: 0.972549),
        brightMagenta: TerminalColor(red: 0.831373, green: 0.560784, blue: 0.835294),
        brightCyan: TerminalColor(red: 0.466667, green: 0.764706, blue: 0.796078),
        brightWhite: TerminalColor(red: 0.760784, green: 0.784314, blue: 0.819608)
    )
}