import SwiftUI

struct ProfileDetailView: View {
    @EnvironmentObject var profileManager: ProfileManager
    let profile: SSHProfile
    @State private var editedProfile: SSHProfile
    @State private var isEditing: Bool = false
    @State private var selectedTab: DetailTab = .connection
    @State private var showingKeyPicker = false

    init(profile: SSHProfile) {
        self.profile = profile
        self._editedProfile = State(initialValue: profile)
    }

    enum DetailTab: String, CaseIterable, Identifiable {
        case connection = "Connection"
        case authentication = "Authentication"
        case advanced = "Advanced"
        case terminal = "Terminal"
        case commands = "Commands"
        case embeddedTerminalSettings = "Terminal Settings"
        case embeddedTerminal = "Embedded Terminal"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .connection: return "network"
            case .authentication: return "key"
            case .advanced: return "gearshape"
            case .terminal: return "terminal"
            case .commands: return "command"
            case .embeddedTerminalSettings: return "slider.horizontal.3"
            case .embeddedTerminal: return "terminal.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            DetailBackdrop(profile: profile)

            VStack(spacing: 0) {
                DetailHeader(
                    profile: editedProfile,
                    isEditing: $isEditing,
                    onSave: saveChanges,
                    onCancel: cancelEditing,
                    onConnect: { profileManager.connectToProfile(profile) },
                    onSFTP: { profileManager.openSFTPForProfile(profile) }
                )

                GlassTabBar(selection: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                Group {
                    switch selectedTab {
                    case .connection:
                        ConnectionTabView(profile: $editedProfile, isEditing: isEditing)
                    case .authentication:
                        AuthenticationTabView(profile: $editedProfile, isEditing: isEditing)
                    case .advanced:
                        AdvancedTabView(profile: $editedProfile, isEditing: isEditing)
                    case .terminal:
                        TerminalTabView(profile: $editedProfile, isEditing: isEditing)
                    case .commands:
                        CommandsTabView(profile: $editedProfile, isEditing: isEditing)
                    case .embeddedTerminalSettings:
                        EmbeddedTerminalSettingsView(profile: $editedProfile, isEditing: isEditing)
                    case .embeddedTerminal:
                        PersistentTerminalView(currentProfileId: editedProfile.id)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileChanged"))) { _ in
            editedProfile = profile
            isEditing = false
        }
        .onChange(of: profile) { newProfile in
            editedProfile = newProfile
            isEditing = false
            selectedTab = .connection
        }
    }

    private func saveChanges() {
        if let index = profileManager.profiles.firstIndex(where: { $0.id == profile.id }) {
            var updatedProfile = editedProfile
            updatedProfile.modifiedAt = Date()
            profileManager.profiles[index] = updatedProfile
            profileManager.selectedProfile = updatedProfile
            TerminalSessionManager.shared.updateProfile(for: updatedProfile.id, newProfile: updatedProfile)
        }
        isEditing = false
    }

    private func cancelEditing() {
        editedProfile = profile
        isEditing = false
    }
}

// MARK: - Header

struct DetailHeader: View {
    @EnvironmentObject var profileManager: ProfileManager
    let profile: SSHProfile
    @Binding var isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let onConnect: () -> Void
    let onSFTP: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                profileManager.selectedProfile = nil
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassBackground(in: .circle, fallback: .thinMaterial)
            .help("Back to home")

            ProfileAvatar(profile: profile, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    if profile.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    if let lastUsed = profile.lastUsed {
                        Text(lastUsed.compactRelativeString())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(profile.connectionString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let jump = profile.jumpHost, !jump.isEmpty {
                        Text("via \(jump)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }

            Spacer()

            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(.separator.opacity(0.5))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isEditing {
            HStack(spacing: 8) {
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape)
                Button("Save", action: onSave)
                    .keyboardShortcut(.return)
                    .glassProminentButton()
            }
        } else {
            actionButtonsCluster
        }
    }

    @ViewBuilder
    private var actionButtonsCluster: some View {
        let cluster = HStack(spacing: 6) {
            HeaderIconButton(systemName: "terminal", help: "Open localhost console") {
                ITerm2Service().openLocalhost()
            }
            HeaderIconButton(systemName: "pencil", help: "Edit profile") {
                isEditing = true
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.keyWindow {
                    window.makeKey()
                    window.makeFirstResponder(window.contentView)
                }
            }
            HeaderIconButton(systemName: "folder", help: "Open SFTP file transfer", action: onSFTP)

            Button(action: onConnect) {
                Label("Connect", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .glassProminentButton()
            .keyboardShortcut(.return, modifiers: .command)
            .help("Connect to this profile (⌘↩)")
        }

        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 6) { cluster }
        } else {
            cluster
        }
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                .frame(width: 30, height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassBackground(in: .capsule, fallback: .thinMaterial)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

// MARK: - Connection Tab

struct ConnectionTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool

    var body: some View {
        Form {
            Section("Server") {
                TextField("Profile Name", text: $profile.name, prompt: Text("Required"))
                    .disabled(!isEditing)
                TextField("Host", text: $profile.host, prompt: Text("hostname.example.com"))
                    .disabled(!isEditing)
                TextField("Port", value: $profile.port, format: .number, prompt: Text("22"))
                    .disabled(!isEditing)
                TextField("Username", text: $profile.username, prompt: Text(NSUserName()))
                    .disabled(!isEditing)
            }

            Section("Proxy") {
                TextField("Jump Host", text: Binding(
                    get: { profile.jumpHost ?? "" },
                    set: { profile.jumpHost = $0.isEmpty ? nil : $0 }
                ), prompt: Text("user@bastion.example.com"))
                .disabled(!isEditing)
                .help("Use another host as a jump server (ProxyJump)")

                TextField("Proxy Command", text: Binding(
                    get: { profile.proxyCommand ?? "" },
                    set: { profile.proxyCommand = $0.isEmpty ? nil : $0 }
                ), prompt: Text("Optional"))
                .disabled(!isEditing)
                .help("Custom proxy command")
            }

            Section("Organization") {
                TagEditor(tags: $profile.tags, isEditing: isEditing)
                Toggle("Favorite", isOn: $profile.isFavorite)
                    .disabled(!isEditing)
                GroupSelector(profile: $profile, isEditing: isEditing)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Authentication Tab

struct AuthenticationTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    @State private var showingFilePicker = false

    var body: some View {
        Form {
            Section("Method") {
                Picker("Authentication", selection: $profile.authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!isEditing)
            }

            switch profile.authMethod {
            case .publicKey:
                Section {
                    HStack(spacing: 6) {
                        TextField("Private Key Path", text: Binding(
                            get: { profile.privateKeyPath ?? "" },
                            set: { profile.privateKeyPath = $0.isEmpty ? nil : $0 }
                        ), prompt: Text("~/.ssh/id_rsa"))
                        .font(.system(.body, design: .monospaced))
                        .disabled(!isEditing)

                        Button {
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "folder")
                        }
                        .disabled(!isEditing)
                        .help("Browse for key file")
                    }
                } header: {
                    Text("Public Key")
                } footer: {
                    Text("Common locations: ~/.ssh/id_rsa, ~/.ssh/id_ed25519")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .password:
                Section {
                    SecureField("Password", text: Binding(
                        get: { profile.password ?? "" },
                        set: { profile.password = $0.isEmpty ? nil : $0 }
                    ), prompt: Text("Stored in Keychain"))
                    .disabled(!isEditing)
                } header: {
                    Text("Password")
                } footer: {
                    Label("Passwords are stored securely in the macOS Keychain", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .keyboardInteractive, .certificate:
                Section {
                    Label("This method has no additional fields. Configure via SSH config or system tools.", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                profile.privateKeyPath = url.path
            }
        }
    }
}

// MARK: - Advanced Tab

struct AdvancedTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool

    var body: some View {
        Form {
            Section("Connection") {
                Toggle("Compression", isOn: $profile.compression)
                    .disabled(!isEditing)
                Toggle("Strict Host Key Checking", isOn: $profile.strictHostKeyChecking)
                    .disabled(!isEditing)

                LabeledContent("Connection Timeout") {
                    UnitNumberField(
                        value: $profile.connectionTimeout,
                        unit: "seconds",
                        prompt: "30",
                        disabled: !isEditing
                    )
                }

                LabeledContent("Server Alive Interval") {
                    UnitNumberField(
                        value: $profile.serverAliveInterval,
                        unit: "seconds",
                        prompt: "60",
                        disabled: !isEditing
                    )
                }
            }

            Section("Port Forwarding") {
                PortForwardingEditor(
                    localForwards: $profile.localForwards,
                    remoteForwards: $profile.remoteForwards,
                    isEditing: isEditing
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Terminal Tab

struct TerminalTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool

    var body: some View {
        Form {
            Section("Appearance") {
                TextField("Color Scheme", text: $profile.terminalSettings.colorScheme, prompt: Text("Default"))
                    .disabled(!isEditing)
                TextField("Font Family", text: $profile.terminalSettings.fontFamily, prompt: Text("Monaco"))
                    .disabled(!isEditing)
                Stepper(
                    "Font Size: \(profile.terminalSettings.fontSize) pt",
                    value: $profile.terminalSettings.fontSize,
                    in: 8...24
                )
                .disabled(!isEditing)

                Picker("Cursor Style", selection: $profile.terminalSettings.cursorStyle) {
                    ForEach(CursorStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .disabled(!isEditing)
            }

            Section("Behavior") {
                TextField("Scrollback Lines", value: $profile.terminalSettings.scrollbackLines, format: .number, prompt: Text("10000"))
                    .disabled(!isEditing)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shared field helpers

struct UnitNumberField: View {
    @Binding var value: Int
    let unit: String
    let prompt: String
    let disabled: Bool
    var width: CGFloat = 60

    var body: some View {
        HStack(spacing: 6) {
            TextField("", value: $value, format: .number, prompt: Text(prompt))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: width)
                .disabled(disabled)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Commands Tab

struct CommandsTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    @State private var newCommand = ""
    @State private var selection = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Startup Commands")
                        .font(.headline)
                    Text(isEditing
                         ? "Drag to reorder \u{2022} Select to delete"
                         : "Click Edit to modify"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if !profile.customCommands.isEmpty {
                    Text("\(profile.customCommands.count) command\(profile.customCommands.count == 1 ? "" : "s")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.12), in: Capsule())
                }
            }

            if profile.customCommands.isEmpty && !isEditing {
                CommandsEmptyState()
            } else {
                List(selection: isEditing ? $selection : .constant(Set<String>())) {
                    ForEach(profile.customCommands, id: \.self) { command in
                        HStack(spacing: 8) {
                            if isEditing {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tint)
                            Text(command)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                        }
                        .tag(command)
                    }
                    .onMove { source, destination in
                        if isEditing {
                            profile.customCommands.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .onDelete { indices in
                        if isEditing {
                            profile.customCommands.remove(atOffsets: indices)
                        }
                    }
                }
                .frame(minHeight: 140, maxHeight: 320)
                .listStyle(.bordered(alternatesRowBackgrounds: true))
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Add a command, e.g. cd /var/log", text: $newCommand)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onAppear {
                                NSApp.activate(ignoringOtherApps: true)
                            }
                            .onSubmit(addCommand)

                        Button("Add", action: addCommand)
                            .keyboardShortcut(.return, modifiers: [])
                            .disabled(newCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if !selection.isEmpty {
                        HStack {
                            Button(role: .destructive) {
                                profile.customCommands.removeAll { selection.contains($0) }
                                selection.removeAll()
                            } label: {
                                Label("Delete Selected", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Text("\(selection.count) selected")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private func addCommand() {
        let trimmed = newCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.customCommands.append(trimmed)
        newCommand = ""
    }
}

private struct CommandsEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "command")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No Startup Commands")
                .font(.headline)
            Text("Add commands to run automatically when you connect.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(20)
        .glassBackground(in: .rect(cornerRadius: 10), fallback: .thinMaterial)
    }
}

// MARK: - Tags

struct TagEditor: View {
    @Binding var tags: Set<String>
    let isEditing: Bool
    @State private var newTag = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                Spacer()
            }

            if tags.isEmpty && !isEditing {
                Text("No tags")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    tagPillRow
                        .padding(.vertical, 1)
                }
            }
        }
    }

    @ViewBuilder
    private var tagPillRow: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer {
                tagPillContent
            }
        } else {
            tagPillContent
        }
    }

    @ViewBuilder
    private var tagPillContent: some View {
        HStack(spacing: 6) {
            ForEach(Array(tags).sorted(), id: \.self) { tag in
                TagView(tag: tag, isEditing: isEditing) {
                    if isEditing {
                        tags.remove(tag)
                    }
                }
            }

            if isEditing {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 60, idealWidth: 80)
                        .focused($isTextFieldFocused)
                        .onSubmit(addTag)

                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassBackground(in: .rect(cornerRadius: 12), fallback: .thinMaterial)
            }
        }
    }

    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty {
            tags.insert(trimmedTag)
            newTag = ""
            isTextFieldFocused = true
        }
    }
}

struct TagView: View {
    let tag: String
    let isEditing: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove tag")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassBackground(tinted: .accentColor, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Port Forwarding

struct PortForwardingEditor: View {
    @Binding var localForwards: [PortForward]
    @Binding var remoteForwards: [PortForward]
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            forwardingGroup(
                title: "Local Forwarding",
                subtitle: "Forward a local port to a remote host through SSH",
                forwards: $localForwards
            )

            forwardingGroup(
                title: "Remote Forwarding",
                subtitle: "Expose a local port through the remote host",
                forwards: $remoteForwards
            )
        }
    }

    @ViewBuilder
    private func forwardingGroup(title: String, subtitle: String, forwards: Binding<[PortForward]>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if forwards.wrappedValue.isEmpty {
                Text("None configured")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(forwards) { $forward in
                    PortForwardRow(forward: $forward, isEditing: isEditing)
                }
            }
        }
    }
}

struct PortForwardRow: View {
    @Binding var forward: PortForward
    let isEditing: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("Local", value: $forward.localPort, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .disabled(!isEditing)
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("host", text: $forward.remoteHost)
                .textFieldStyle(.roundedBorder)
                .disabled(!isEditing)
            Text(":")
                .foregroundStyle(.secondary)
            TextField("Port", value: $forward.remotePort, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .disabled(!isEditing)
        }
    }
}

// MARK: - Group Selector

struct GroupSelector: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    @EnvironmentObject var profileManager: ProfileManager

    private var customGroups: [ProfileGroup] {
        profileManager.groups.filter { !["All Profiles", "Favorites", "Recent"].contains($0.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Groups")

            if customGroups.isEmpty {
                Text("No custom groups yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    groupPillRow
                        .padding(.vertical, 1)
                }
            }
        }
    }

    @ViewBuilder
    private var groupPillRow: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer {
                groupPillContent
            }
        } else {
            groupPillContent
        }
    }

    @ViewBuilder
    private var groupPillContent: some View {
        HStack(spacing: 6) {
            ForEach(customGroups) { group in
                let isInGroup = group.profileIDs.contains(profile.id)
                Button {
                    if isEditing {
                        if isInGroup {
                            profileManager.removeProfileFromGroup(profile, group: group)
                        } else {
                            profileManager.addProfileToGroup(profile, group: group)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isInGroup ? "checkmark.circle.fill" : group.icon)
                            .font(.caption)
                            .foregroundStyle(isInGroup ? Color.white : Color(group.color))
                        Text(group.name)
                            .font(.caption)
                            .foregroundStyle(isInGroup ? Color.white : Color.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .modifier(GroupPillBackground(isInGroup: isInGroup))
                }
                .buttonStyle(.plain)
                .disabled(!isEditing)
            }
        }
    }
}

private struct GroupPillBackground: ViewModifier {
    let isInGroup: Bool

    func body(content: Content) -> some View {
        if isInGroup {
            content.glassBackground(tinted: .accentColor, in: .rect(cornerRadius: 12))
        } else {
            content.glassBackground(in: .rect(cornerRadius: 12), fallback: .thinMaterial)
        }
    }
}

// MARK: - Identifiable conformance for ForEach binding

extension PortForward: Identifiable {
    var id: String { "\(localPort)-\(remoteHost)-\(remotePort)" }
}

// MARK: - Detail backdrop

private struct DetailBackdrop: View {
    let profile: SSHProfile

    var body: some View {
        let tint = ProfileAvatar.color(for: profile)
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [tint.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(maxHeight: 280)
            .frame(maxWidth: .infinity, alignment: .top)

            LinearGradient(
                colors: [.accentColor.opacity(0.05), Color.clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

// MARK: - Glass tab bar

struct GlassTabBar: View {
    @Binding var selection: ProfileDetailView.DetailTab
    @Namespace private var animation

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            tabRow
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var tabRow: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 4) {
                tabButtons
            }
        } else {
            tabButtons
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 4) {
            ForEach(ProfileDetailView.DetailTab.allCases) { tab in
                TabPill(
                    tab: tab,
                    isSelected: selection == tab,
                    namespace: animation
                ) {
                    withAnimation(.smooth(duration: 0.22)) {
                        selection = tab
                    }
                }
            }
        }
    }
}

private struct TabPill: View {
    let tab: ProfileDetailView.DetailTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(TabPillBackground(isSelected: isSelected, isHovered: isHovered, namespace: namespace, tab: tab))
        .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        if isSelected { return .white }
        if isHovered { return .primary }
        return .secondary
    }
}

private struct TabPillBackground: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool
    let namespace: Namespace.ID
    let tab: ProfileDetailView.DetailTab

    func body(content: Content) -> some View {
        if isSelected {
            if #available(macOS 26, *) {
                content
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
                    .glassEffectID("selectedTab", in: namespace)
            } else {
                content
                    .background(Color.accentColor, in: Capsule())
            }
        } else if isHovered {
            content
                .background(.primary.opacity(0.06), in: Capsule())
        } else {
            content
                .background(Color.clear, in: Capsule())
        }
    }
}
