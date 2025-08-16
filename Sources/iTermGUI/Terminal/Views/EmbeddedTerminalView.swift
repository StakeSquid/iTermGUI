import SwiftUI
import SwiftTerm

struct EmbeddedTerminalView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @StateObject private var sessionManager = TerminalSessionManager.shared
    
    let profile: SSHProfile
    @State private var sessions: [TerminalSession] = []
    @State private var selectedSessionId: UUID?
    @State private var terminalSize: CGSize = .zero
    @State private var showNewTabButton: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TerminalTabBar(
                sessions: sessions,
                selectedSessionId: $selectedSessionId,
                onNewTab: createNewSession,
                onCloseTab: closeSession,
                onSelectTab: selectSession
            )
            .frame(height: 36)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Terminal content
            if let selectedSession = sessions.first(where: { $0.id == selectedSessionId }) {
                TerminalContentView(session: selectedSession)
                    .background(GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                terminalSize = geometry.size
                                updateTerminalSize(geometry.size)
                            }
                            .onChange(of: geometry.size) { newSize in
                                terminalSize = newSize
                                updateTerminalSize(newSize)
                            }
                    })
            } else {
                EmptyTerminalView(onConnect: createNewSession)
            }
        }
        .onAppear {
            loadSessions()
        }
        .onChange(of: profile) { _ in
            loadSessions()
        }
    }
    
    private func loadSessions() {
        sessions = sessionManager.getActiveSessions(for: profile.id)
        
        if sessions.isEmpty {
            // Auto-create first session
            createNewSession()
        } else if selectedSessionId == nil || !sessions.contains(where: { $0.id == selectedSessionId }) {
            selectedSessionId = sessions.first?.id
        }
    }
    
    private func createNewSession() {
        let settings = profile.embeddedTerminalSettings ?? EmbeddedTerminalSettings()
        let session = sessionManager.createSession(for: profile, settings: settings)
        sessions = sessionManager.getActiveSessions(for: profile.id)
        selectedSessionId = session.id
        sessionManager.setActiveSession(session.id)
    }
    
    private func closeSession(_ session: TerminalSession) {
        sessionManager.closeSession(session)
        sessions = sessionManager.getActiveSessions(for: profile.id)
        
        if selectedSessionId == session.id {
            selectedSessionId = sessions.first?.id
            if let newSelectedId = selectedSessionId {
                sessionManager.setActiveSession(newSelectedId)
            }
        }
    }
    
    private func selectSession(_ session: TerminalSession) {
        selectedSessionId = session.id
        sessionManager.setActiveSession(session.id)
    }
    
    private func updateTerminalSize(_ size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        
        // Calculate terminal columns and rows based on font metrics
        let fontSize = CGFloat(profile.terminalSettings.fontSize)
        let charWidth = fontSize * 0.6 // Approximate character width
        let lineHeight = fontSize * 1.2 // Approximate line height
        
        let columns = Int(size.width / charWidth)
        let rows = Int(size.height / lineHeight)
        
        // Update all sessions for this profile
        for session in sessions {
            session.resize(columns: max(80, columns), rows: max(24, rows))
        }
    }
}

struct TerminalTabBar: View {
    let sessions: [TerminalSession]
    @Binding var selectedSessionId: UUID?
    let onNewTab: () -> Void
    let onCloseTab: (TerminalSession) -> Void
    let onSelectTab: (TerminalSession) -> Void
    
    @State private var hoveredTabId: UUID?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(sessions) { session in
                    TerminalTab(
                        session: session,
                        isSelected: session.id == selectedSessionId,
                        isHovered: session.id == hoveredTabId,
                        onSelect: { onSelectTab(session) },
                        onClose: { onCloseTab(session) }
                    )
                    .onHover { hovering in
                        hoveredTabId = hovering ? session.id : nil
                    }
                }
                
                // New tab button
                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }
}

struct TerminalTab: View {
    let session: TerminalSession
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var showCloseButton: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            statusIndicator
            titleText
            closeButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tabBackground)
        .overlay(tabBorder)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            showCloseButton = hovering
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }
    
    @ViewBuilder
    private var titleText: some View {
        Text(session.title)
            .font(.system(size: 11))
            .lineLimit(1)
            .truncationMode(.tail)
    }
    
    @ViewBuilder
    private var closeButton: some View {
        if showCloseButton || isHovered {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
            }
            .buttonStyle(.plain)
            .frame(width: 14, height: 14)
        }
    }
    
    private var tabBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
    }
    
    private var tabBorder: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Reconnect") {
            session.connect()
        }
        .disabled(session.state == .connected)
        
        Button("Disconnect") {
            session.disconnect()
        }
        .disabled(session.state == .disconnected)
        
        Divider()
        
        Button("Close Tab") {
            onClose()
        }
    }
    
    private var statusColor: SwiftUI.Color {
        switch session.state {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
}

struct TerminalContentView: View {
    @ObservedObject var session: TerminalSession
    @State private var terminalView: LocalProcessTerminalView?
    
    var body: some View {
        ZStack {
            if let terminal = terminalView {
                TerminalViewWrapper(terminal: terminal, session: session)
                    .background(session.settings.theme.colors.background.color)
            } else {
                ProgressView("Initializing terminal...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
            
            // Status overlay for disconnected/error states
            if case .disconnected = session.state {
                DisconnectedOverlay(onReconnect: { session.connect() })
            } else if case .error(let message) = session.state {
                ErrorOverlay(message: message, onRetry: { session.connect() })
            }
        }
        .onAppear {
            setupTerminal()
        }
    }
    
    private func setupTerminal() {
        let terminal = LocalProcessTerminalView(frame: .zero)
        
        // Configure terminal appearance
        terminal.font = NSFont(name: session.settings.fontFamily, size: session.settings.fontSize) ?? NSFont.monospacedSystemFont(ofSize: session.settings.fontSize, weight: .regular)
        
        // Apply theme colors
        let theme = session.settings.theme.colors
        // SwiftTerm uses its own Color type, we need to convert
        let swiftTermColors = theme.toSwiftTermNSColors().map { nsColor -> SwiftTerm.Color in
            let r = nsColor.redComponent
            let g = nsColor.greenComponent
            let b = nsColor.blueComponent
            return SwiftTerm.Color(red: UInt16(r * 65535), green: UInt16(g * 65535), blue: UInt16(b * 65535))
        }
        terminal.installColors(swiftTermColors)
        
        // Set up terminal options
        terminal.optionAsMetaKey = true
        terminal.allowMouseReporting = session.settings.mouseReporting
        
        // Store reference
        self.terminalView = terminal
        session.terminal = terminal
        
        // Start the SSH process if not already connected
        if session.state == .disconnected {
            session.connect()
        }
    }
}

struct TerminalViewWrapper: NSViewRepresentable {
    let terminal: LocalProcessTerminalView
    let session: TerminalSession
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        // The terminal is already configured in setupTerminal()
        // and SSH connection is handled in session.connect()
        return terminal
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Update terminal if settings changed
    }
}

struct EmptyTerminalView: View {
    let onConnect: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No terminal session")
                .font(.title3)
            
            Button("Open Terminal") {
                onConnect()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct DisconnectedOverlay: View {
    let onReconnect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            
            Text("Disconnected")
                .font(.headline)
            
            Button("Reconnect") {
                onReconnect()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .cornerRadius(8)
    }
}

struct ErrorOverlay: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.red)
            
            Text("Connection Error")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 300)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .cornerRadius(8)
    }
}

// Helper extensions
extension TerminalSettings {
    func toEmbeddedSettings() -> EmbeddedTerminalSettings {
        EmbeddedTerminalSettings(
            theme: .dark,
            fontFamily: fontFamily,
            fontSize: CGFloat(fontSize),
            cursorStyle: cursorStyle.toEmbeddedStyle(),
            scrollbackLines: scrollbackLines
        )
    }
}

extension CursorStyle {
    func toEmbeddedStyle() -> TerminalCursorStyle {
        switch self {
        case .block: return .block
        case .underline: return .underline
        case .bar: return .bar
        }
    }
}

extension TerminalColorPalette {
    func toSwiftTermColors() -> [SwiftUI.Color] {
        return [
            black.color, red.color, green.color, yellow.color, 
            blue.color, magenta.color, cyan.color, white.color,
            brightBlack.color, brightRed.color, brightGreen.color, brightYellow.color,
            brightBlue.color, brightMagenta.color, brightCyan.color, brightWhite.color
        ]
    }
    
    func toSwiftTermNSColors() -> [NSColor] {
        return [
            black.nsColor, red.nsColor, green.nsColor, yellow.nsColor,
            blue.nsColor, magenta.nsColor, cyan.nsColor, white.nsColor,
            brightBlack.nsColor, brightRed.nsColor, brightGreen.nsColor, brightYellow.nsColor,
            brightBlue.nsColor, brightMagenta.nsColor, brightCyan.nsColor, brightWhite.nsColor
        ]
    }
}