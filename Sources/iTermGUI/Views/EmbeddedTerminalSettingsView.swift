import SwiftUI

struct EmbeddedTerminalSettingsView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    
    @State private var selectedTheme: TerminalTheme
    @State private var fontFamily: String
    @State private var fontSize: CGFloat
    @State private var cursorStyle: TerminalCursorStyle
    @State private var cursorBlink: Bool
    @State private var scrollbackLines: Int
    @State private var mouseReporting: Bool
    @State private var copyOnSelect: Bool
    @State private var pasteOnMiddleClick: Bool
    @State private var pasteOnRightClick: Bool
    @State private var bellStyle: BellStyle
    @State private var autoReconnect: Bool
    @State private var reconnectDelay: Int
    @State private var keepAliveInterval: Int
    @State private var terminalType: String
    @State private var onConnectCommands: [String]
    @State private var newCommand: String = ""
    
    init(profile: Binding<SSHProfile>, isEditing: Bool) {
        self._profile = profile
        self.isEditing = isEditing
        
        let settings = profile.wrappedValue.effectiveEmbeddedTerminalSettings
        self._selectedTheme = State(initialValue: settings.theme)
        self._fontFamily = State(initialValue: settings.fontFamily)
        self._fontSize = State(initialValue: settings.fontSize)
        self._cursorStyle = State(initialValue: settings.cursorStyle)
        self._cursorBlink = State(initialValue: settings.cursorBlink)
        self._scrollbackLines = State(initialValue: settings.scrollbackLines)
        self._mouseReporting = State(initialValue: settings.mouseReporting)
        self._copyOnSelect = State(initialValue: settings.copyOnSelect)
        self._pasteOnMiddleClick = State(initialValue: settings.pasteOnMiddleClick)
        self._pasteOnRightClick = State(initialValue: settings.pasteOnRightClick)
        self._bellStyle = State(initialValue: settings.bellStyle)
        self._autoReconnect = State(initialValue: settings.autoReconnect)
        self._reconnectDelay = State(initialValue: settings.reconnectDelay)
        self._keepAliveInterval = State(initialValue: settings.keepAliveInterval)
        self._terminalType = State(initialValue: settings.terminalType)
        self._onConnectCommands = State(initialValue: settings.onConnectCommands)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Theme Section
                themeSection
                
                Divider()
                
                // Appearance Section
                appearanceSection
                
                Divider()
                
                // Behavior Section
                behaviorSection
                
                Divider()
                
                // Connection Section
                connectionSection
                
                Divider()
                
                // Advanced Section
                advancedSection
            }
            .padding()
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: profile) { _ in
            loadSettings()
        }
        .onChange(of: selectedTheme) { _ in saveSettings() }
        .onChange(of: fontFamily) { _ in saveSettings() }
        .onChange(of: fontSize) { _ in saveSettings() }
        .onChange(of: cursorStyle) { _ in saveSettings() }
        .onChange(of: cursorBlink) { _ in saveSettings() }
        .onChange(of: scrollbackLines) { _ in saveSettings() }
        .onChange(of: mouseReporting) { _ in saveSettings() }
        .onChange(of: copyOnSelect) { _ in saveSettings() }
        .onChange(of: pasteOnMiddleClick) { _ in saveSettings() }
        .onChange(of: pasteOnRightClick) { _ in saveSettings() }
        .onChange(of: bellStyle) { _ in saveSettings() }
        .onChange(of: autoReconnect) { _ in saveSettings() }
        .onChange(of: reconnectDelay) { _ in saveSettings() }
        .onChange(of: keepAliveInterval) { _ in saveSettings() }
        .onChange(of: terminalType) { _ in saveSettings() }
    }
    
    var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
            
            Picker("Color Theme", selection: $selectedTheme) {
                ForEach(TerminalTheme.allCases, id: \.self) { theme in
                    HStack {
                        ThemePreview(theme: theme)
                            .frame(width: 60, height: 20)
                        Text(theme.rawValue)
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(.menu)
            .disabled(!isEditing)
            .frame(width: 200)
            
            // Theme preview
            ThemePreview(theme: selectedTheme)
                .frame(height: 80)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)
            
            HStack {
                Text("Font Family:")
                TextField("Font", text: $fontFamily)
                    .frame(width: 150)
                    .disabled(!isEditing)
                
                Button("Select...") {
                    showFontPicker()
                }
                .disabled(!isEditing)
            }
            
            HStack {
                Text("Font Size:")
                Slider(value: $fontSize, in: 9...24, step: 1)
                    .frame(width: 150)
                    .disabled(!isEditing)
                Text("\(Int(fontSize)) pt")
                    .frame(width: 40)
            }
            
            HStack {
                Text("Cursor Style:")
                Picker("", selection: $cursorStyle) {
                    ForEach(TerminalCursorStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(!isEditing)
            }
            
            Toggle("Cursor Blink", isOn: $cursorBlink)
                .disabled(!isEditing)
            
            Toggle("Use Bold Fonts", isOn: .constant(true))
                .disabled(!isEditing)
            
            Toggle("Use Bright Colors for Bold", isOn: .constant(true))
                .disabled(!isEditing)
        }
    }
    
    var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Behavior")
                .font(.headline)
            
            HStack {
                Text("Scrollback Lines:")
                TextField("", value: $scrollbackLines, format: .number)
                    .frame(width: 80)
                    .disabled(!isEditing)
            }
            
            Toggle("Enable Mouse Reporting", isOn: $mouseReporting)
                .disabled(!isEditing)
            
            Toggle("Copy on Select", isOn: $copyOnSelect)
                .disabled(!isEditing)
            
            Toggle("Paste on Middle Click", isOn: $pasteOnMiddleClick)
                .disabled(!isEditing)
            
            Toggle("Paste on Right Click", isOn: $pasteOnRightClick)
                .disabled(!isEditing)
            
            HStack {
                Text("Bell:")
                Picker("", selection: $bellStyle) {
                    ForEach(BellStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(!isEditing)
            }
        }
    }
    
    var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)
            
            Toggle("Auto Reconnect", isOn: $autoReconnect)
                .disabled(!isEditing)
            
            HStack {
                Text("Reconnect Delay:")
                TextField("", value: $reconnectDelay, format: .number)
                    .frame(width: 60)
                    .disabled(!isEditing || !autoReconnect)
                Text("seconds")
            }
            
            HStack {
                Text("Keep Alive Interval:")
                TextField("", value: $keepAliveInterval, format: .number)
                    .frame(width: 60)
                    .disabled(!isEditing)
                Text("seconds")
            }
            
            // Commands on connect
            VStack(alignment: .leading, spacing: 8) {
                Text("Commands on Connect:")
                    .font(.subheadline)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(onConnectCommands, id: \.self) { command in
                            HStack {
                                Text(command)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if isEditing {
                                    Button(action: {
                                        removeCommand(command)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 100)
                
                if isEditing {
                    HStack {
                        TextField("New command", text: $newCommand)
                            .onSubmit {
                                addCommand()
                            }
                        
                        Button("Add") {
                            addCommand()
                        }
                    }
                }
            }
        }
    }
    
    var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.headline)
            
            HStack {
                Text("Terminal Type:")
                TextField("", text: $terminalType)
                    .frame(width: 150)
                    .disabled(!isEditing)
            }
            
            HStack {
                Text("Locale:")
                TextField("", text: .constant("en_US.UTF-8"))
                    .frame(width: 150)
                    .disabled(!isEditing)
            }
            
            Toggle("Enable Sixel Graphics", isOn: .constant(false))
                .disabled(!isEditing)
            
            Toggle("Enable OSC 52 (Clipboard)", isOn: .constant(true))
                .disabled(!isEditing)
        }
    }
    
    private func loadSettings() {
        let settings = profile.effectiveEmbeddedTerminalSettings
        selectedTheme = settings.theme
        fontFamily = settings.fontFamily
        fontSize = settings.fontSize
        cursorStyle = settings.cursorStyle
        cursorBlink = settings.cursorBlink
        scrollbackLines = settings.scrollbackLines
        mouseReporting = settings.mouseReporting
        copyOnSelect = settings.copyOnSelect
        pasteOnMiddleClick = settings.pasteOnMiddleClick
        pasteOnRightClick = settings.pasteOnRightClick
        bellStyle = settings.bellStyle
        autoReconnect = settings.autoReconnect
        reconnectDelay = settings.reconnectDelay
        keepAliveInterval = settings.keepAliveInterval
        terminalType = settings.terminalType
        onConnectCommands = settings.onConnectCommands
    }
    
    private func saveSettings() {
        guard isEditing else { return }
        
        var settings = EmbeddedTerminalSettings()
        settings.theme = selectedTheme
        settings.fontFamily = fontFamily
        settings.fontSize = fontSize
        settings.cursorStyle = cursorStyle
        settings.cursorBlink = cursorBlink
        settings.scrollbackLines = scrollbackLines
        settings.mouseReporting = mouseReporting
        settings.copyOnSelect = copyOnSelect
        settings.pasteOnMiddleClick = pasteOnMiddleClick
        settings.pasteOnRightClick = pasteOnRightClick
        settings.bellStyle = bellStyle
        settings.autoReconnect = autoReconnect
        settings.reconnectDelay = reconnectDelay
        settings.keepAliveInterval = keepAliveInterval
        settings.terminalType = terminalType
        settings.onConnectCommands = onConnectCommands
        
        profile.embeddedTerminalSettings = settings
    }
    
    private func addCommand() {
        guard !newCommand.isEmpty else { return }
        onConnectCommands.append(newCommand)
        newCommand = ""
        saveSettings()
    }
    
    private func removeCommand(_ command: String) {
        onConnectCommands.removeAll { $0 == command }
        saveSettings()
    }
    
    private func showFontPicker() {
        let fontManager = NSFontManager.shared
        let fontPanel = NSFontPanel.shared
        
        fontPanel.setPanelFont(
            NSFont(name: fontFamily, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            isMultiple: false
        )
        
        fontPanel.orderFront(nil)
        
        // Note: Font selection would need additional delegate handling
        // This is a simplified version
    }
}

struct ThemePreview: View {
    let theme: TerminalTheme
    
    var body: some View {
        let colors = theme.colors
        
        VStack(alignment: .leading, spacing: 2) {
            // Sample terminal output
            HStack(spacing: 4) {
                Text("$")
                    .foregroundColor(colors.green.color)
                Text("ls -la")
                    .foregroundColor(colors.foreground.color)
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            
            HStack(spacing: 4) {
                Text("file.txt")
                    .foregroundColor(colors.blue.color)
                Text("directory/")
                    .foregroundColor(colors.cyan.color)
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            
            Text("Error: not found")
                .foregroundColor(colors.red.color)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background.color)
    }
}