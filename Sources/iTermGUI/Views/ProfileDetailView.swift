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
    
    enum DetailTab: String, CaseIterable {
        case connection = "Connection"
        case authentication = "Authentication"
        case advanced = "Advanced"
        case terminal = "Terminal"
        case commands = "Commands"
        case embeddedTerminalSettings = "Terminal Settings"
        case embeddedTerminal = "Embedded Terminal"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(profile: editedProfile, isEditing: $isEditing) {
                saveChanges()
            } onCancel: {
                cancelEditing()
            } onConnect: {
                profileManager.connectToProfile(profile)
            } onSFTP: {
                profileManager.openSFTPForProfile(profile)
            }
            
            TabView(selection: $selectedTab) {
                ConnectionTabView(profile: $editedProfile, isEditing: isEditing)
                    .tabItem { Label("Connection", systemImage: "network") }
                    .tag(DetailTab.connection)
                
                AuthenticationTabView(profile: $editedProfile, isEditing: isEditing)
                    .tabItem { Label("Authentication", systemImage: "key") }
                    .tag(DetailTab.authentication)
                
                AdvancedTabView(profile: $editedProfile, isEditing: isEditing)
                    .tabItem { Label("Advanced", systemImage: "gearshape") }
                    .tag(DetailTab.advanced)
                
                TerminalTabView(profile: $editedProfile, isEditing: isEditing)
                    .tabItem { Label("Terminal", systemImage: "terminal") }
                    .tag(DetailTab.terminal)
                
                CommandsTabView(profile: $editedProfile, isEditing: isEditing)
                    .tabItem { Label("Commands", systemImage: "command") }
                    .tag(DetailTab.commands)
                
                EmbeddedTerminalSettingsView(profile: $editedProfile, isEditing: isEditing)
                    .tabItem { Label("Terminal Settings", systemImage: "gearshape") }
                    .tag(DetailTab.embeddedTerminalSettings)
                
                PersistentTerminalView(currentProfileId: editedProfile.id)
                    .tabItem { Label("Embedded Terminal", systemImage: "terminal.fill") }
                    .tag(DetailTab.embeddedTerminal)
            }
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileChanged"))) { _ in
            editedProfile = profile
            isEditing = false
        }
        .onChange(of: profile) { newProfile in
            // When a different profile is selected, update the edited profile and exit edit mode
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
            
            // Update the profile in existing terminal sessions
            TerminalSessionManager.shared.updateProfile(for: updatedProfile.id, newProfile: updatedProfile)
        }
        isEditing = false
    }
    
    private func cancelEditing() {
        editedProfile = profile
        isEditing = false
    }
}

struct HeaderView: View {
    @EnvironmentObject var profileManager: ProfileManager
    let profile: SSHProfile
    @Binding var isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let onConnect: () -> Void
    let onSFTP: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                profileManager.selectedProfile = nil
            }) {
                Label("Home", systemImage: "house")
            }
            .buttonStyle(.bordered)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(profile.connectionString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isEditing {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Button("Save", action: onSave)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Edit") {
                    isEditing = true
                    // Ensure window is key for text input
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.keyWindow {
                        window.makeKey()
                        window.makeFirstResponder(window.contentView)
                    }
                }
                Button(action: onSFTP) {
                    Label("SFTP", systemImage: "folder")
                }
                Button(action: onConnect) {
                    Label("Connect", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ConnectionTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    
    var body: some View {
        Form {
            Section {
                TextField("Profile Name", text: $profile.name)
                    .disabled(!isEditing)
                TextField("Host", text: $profile.host)
                    .disabled(!isEditing)
                TextField("Port", value: $profile.port, format: .number)
                    .disabled(!isEditing)
                TextField("Username", text: $profile.username)
                    .disabled(!isEditing)
            }
            
            Section("Proxy") {
                TextField("Jump Host", text: Binding(
                    get: { profile.jumpHost ?? "" },
                    set: { profile.jumpHost = $0.isEmpty ? nil : $0 }
                ))
                .disabled(!isEditing)
                .help("Use another host as a jump server (ProxyJump)")
                
                TextField("Proxy Command", text: Binding(
                    get: { profile.proxyCommand ?? "" },
                    set: { profile.proxyCommand = $0.isEmpty ? nil : $0 }
                ))
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

struct AuthenticationTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    @State private var showingFilePicker = false
    
    var body: some View {
        Form {
            Section {
                Picker("Authentication Method", selection: $profile.authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .disabled(!isEditing)
                
                if profile.authMethod == .publicKey {
                    HStack {
                        TextField("Private Key Path", text: Binding(
                            get: { profile.privateKeyPath ?? "" },
                            set: { profile.privateKeyPath = $0.isEmpty ? nil : $0 }
                        ))
                        .disabled(!isEditing)
                        Button("Browse...") {
                            showingFilePicker = true
                        }
                        .disabled(!isEditing)
                    }
                } else if profile.authMethod == .password {
                    SecureField("Password", text: Binding(
                        get: { profile.password ?? "" },
                        set: { profile.password = $0.isEmpty ? nil : $0 }
                    ))
                    .disabled(!isEditing)
                    .help("Password will be stored in Keychain")
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

struct AdvancedTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    
    var body: some View {
        Form {
            Section("Connection Settings") {
                Toggle("Compression", isOn: $profile.compression)
                    .disabled(!isEditing)
                Toggle("Strict Host Key Checking", isOn: $profile.strictHostKeyChecking)
                    .disabled(!isEditing)
                
                HStack {
                    Text("Connection Timeout")
                    TextField("seconds", value: $profile.connectionTimeout, format: .number)
                        .frame(width: 60)
                        .disabled(!isEditing)
                    Text("seconds")
                }
                
                HStack {
                    Text("Server Alive Interval")
                    TextField("seconds", value: $profile.serverAliveInterval, format: .number)
                        .frame(width: 60)
                        .disabled(!isEditing)
                    Text("seconds")
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

struct TerminalTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    
    var body: some View {
        Form {
            Section("Appearance") {
                TextField("Color Scheme", text: $profile.terminalSettings.colorScheme)
                    .disabled(!isEditing)
                TextField("Font Family", text: $profile.terminalSettings.fontFamily)
                    .disabled(!isEditing)
                Stepper("Font Size: \(profile.terminalSettings.fontSize)", 
                       value: $profile.terminalSettings.fontSize, 
                       in: 8...24)
                    .disabled(!isEditing)
                
                Picker("Cursor Style", selection: $profile.terminalSettings.cursorStyle) {
                    ForEach(CursorStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .disabled(!isEditing)
            }
            
            Section("Behavior") {
                HStack {
                    Text("Scrollback Lines")
                    TextField("lines", value: $profile.terminalSettings.scrollbackLines, format: .number)
                        .frame(width: 80)
                        .disabled(!isEditing)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct CommandsTabView: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    @State private var newCommand = ""
    @State private var selection = Set<String>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Commands to run on connection")
                    .font(.headline)
                Spacer()
                if !isEditing {
                    Text("Click Edit to manage commands")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Drag to reorder • Select to delete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            List(selection: isEditing ? $selection : .constant(Set<String>())) {
                ForEach(profile.customCommands.indices, id: \.self) { index in
                    HStack {
                        if isEditing {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Text(profile.customCommands[index])
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .tag(profile.customCommands[index])
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
            .frame(minHeight: 100, maxHeight: 300)
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            
            if isEditing {
                VStack(spacing: 8) {
                    HStack {
                        TextField("New command", text: $newCommand)
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                NSApp.activate(ignoringOtherApps: true)
                            }
                            .onSubmit {
                                if !newCommand.isEmpty {
                                    profile.customCommands.append(newCommand)
                                    newCommand = ""
                                }
                            }
                        Button("Add") {
                            if !newCommand.isEmpty {
                                profile.customCommands.append(newCommand)
                                newCommand = ""
                            }
                        }
                        .keyboardShortcut(.return, modifiers: [])
                    }
                    
                    if !selection.isEmpty {
                        HStack {
                            Button(action: {
                                profile.customCommands.removeAll { selection.contains($0) }
                                selection.removeAll()
                            }) {
                                Label("Delete Selected", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Text("\(selection.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct TagEditor: View {
    @Binding var tags: Set<String>
    let isEditing: Bool
    @State private var newTag = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tags")
                Spacer()
                if isEditing && tags.isEmpty {
                    Text("Click + to add tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(tags).sorted(), id: \.self) { tag in
                        TagView(tag: tag, isEditing: isEditing) {
                            if isEditing {
                                tags.remove(tag)
                            }
                        }
                    }
                    
                    if isEditing {
                        HStack(spacing: 4) {
                            TextField("Add tag", text: $newTag)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    addTag()
                                }
                            
                            Button(action: addTag) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .disabled(newTag.isEmpty)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
            }
            .frame(minHeight: 30)
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
                Button(action: {
                    onDelete()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove tag")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.2))
        .cornerRadius(12)
    }
}

struct PortForwardingEditor: View {
    @Binding var localForwards: [PortForward]
    @Binding var remoteForwards: [PortForward]
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Local Port Forwarding")
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(localForwards.indices, id: \.self) { index in
                PortForwardRow(forward: $localForwards[index], isEditing: isEditing)
            }
            
            Text("Remote Port Forwarding")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top)
            ForEach(remoteForwards.indices, id: \.self) { index in
                PortForwardRow(forward: $remoteForwards[index], isEditing: isEditing)
            }
        }
    }
}

struct PortForwardRow: View {
    @Binding var forward: PortForward
    let isEditing: Bool
    
    var body: some View {
        HStack {
            TextField("Local Port", value: $forward.localPort, format: .number)
                .frame(width: 80)
                .disabled(!isEditing)
            Text("→")
            TextField("Remote Host", text: $forward.remoteHost)
                .disabled(!isEditing)
            Text(":")
            TextField("Remote Port", value: $forward.remotePort, format: .number)
                .frame(width: 80)
                .disabled(!isEditing)
        }
    }
}

struct GroupSelector: View {
    @Binding var profile: SSHProfile
    let isEditing: Bool
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Groups")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(profileManager.groups.filter { !["All Profiles", "Favorites", "Recent"].contains($0.name) }) { group in
                        let isInGroup = group.profileIDs.contains(profile.id)
                        Button(action: {
                            if isEditing {
                                if isInGroup {
                                    profileManager.removeProfileFromGroup(profile, group: group)
                                } else {
                                    profileManager.addProfileToGroup(profile, group: group)
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isInGroup {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                }
                                Text(group.name)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isInGroup ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isEditing)
                    }
                    
                    if profileManager.groups.filter({ !["All Profiles", "Favorites", "Recent"].contains($0.name) }).isEmpty {
                        Text("No custom groups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}