import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @AppStorage("defaultUsername") private var defaultUsername = NSUserName()
    @AppStorage("defaultPort") private var defaultPort = 22
    @AppStorage("defaultAuthMethod") private var defaultAuthMethod = AuthMethod.publicKey.rawValue
    @AppStorage("autoBackup") private var autoBackup = true
    @AppStorage("backupInterval") private var backupInterval = 7
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        TabView {
            GeneralSettings(
                defaultUsername: $defaultUsername,
                defaultPort: $defaultPort,
                defaultAuthMethod: $defaultAuthMethod,
                showMenuBarIcon: $showMenuBarIcon,
                launchAtLogin: $launchAtLogin
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            BackupSettings(
                autoBackup: $autoBackup,
                backupInterval: $backupInterval
            )
            .tabItem {
                Label("Backup", systemImage: "externaldrive")
            }
            
            ImportExportSettings()
            .tabItem {
                Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
            }
            
            GlobalDefaultsSettings()
            .tabItem {
                Label("Defaults", systemImage: "text.badge.checkmark")
            }
        }
        .frame(width: 500, height: 450)
    }
}

struct GeneralSettings: View {
    @Binding var defaultUsername: String
    @Binding var defaultPort: Int
    @Binding var defaultAuthMethod: String
    @Binding var showMenuBarIcon: Bool
    @Binding var launchAtLogin: Bool
    
    var body: some View {
        Form {
            Section("Default Connection Settings") {
                TextField("Default Username", text: $defaultUsername)
                TextField("Default Port", value: $defaultPort, format: .number)
                Picker("Default Auth Method", selection: $defaultAuthMethod) {
                    ForEach(AuthMethod.allCases, id: \.rawValue) { method in
                        Text(method.rawValue).tag(method.rawValue)
                    }
                }
            }
            
            Section("Application") {
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct BackupSettings: View {
    @Binding var autoBackup: Bool
    @Binding var backupInterval: Int
    @State private var backupLocation: String = "~/Documents/iTermGUI Backups"
    
    var body: some View {
        Form {
            Section("Automatic Backup") {
                Toggle("Enable automatic backup", isOn: $autoBackup)
                
                if autoBackup {
                    Picker("Backup interval", selection: $backupInterval) {
                        Text("Daily").tag(1)
                        Text("Weekly").tag(7)
                        Text("Monthly").tag(30)
                    }
                    
                    HStack {
                        TextField("Backup location", text: $backupLocation)
                        Button("Choose...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            
                            if panel.runModal() == .OK {
                                backupLocation = panel.url?.path ?? backupLocation
                            }
                        }
                    }
                }
            }
            
            Section {
                Button("Backup Now") {
                    performBackup()
                }
                
                Button("Restore from Backup...") {
                    restoreFromBackup()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func performBackup() {
        // TODO: Implement backup
    }
    
    private func restoreFromBackup() {
        // TODO: Implement restore
    }
}

struct ImportExportSettings: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var importFormat = "SSH Config"
    @State private var exportFormat = "SSH Config"
    
    var body: some View {
        Form {
            Section("Import") {
                Picker("Import format", selection: $importFormat) {
                    Text("SSH Config").tag("SSH Config")
                    Text("JSON").tag("JSON")
                    Text("PuTTY").tag("PuTTY")
                }
                
                HStack {
                    Spacer()
                    Button("Import from File...") {
                        importFromFile()
                    }
                    Button("Import from ~/.ssh/config") {
                        profileManager.importFromSSHConfig()
                    }
                    Spacer()
                }
            }
            
            Section("Export") {
                Picker("Export format", selection: $exportFormat) {
                    Text("SSH Config").tag("SSH Config")
                    Text("JSON").tag("JSON")
                    Text("iTerm2 Dynamic Profiles").tag("iTerm2")
                }
                
                HStack {
                    Spacer()
                    Button("Export All Profiles...") {
                        profileManager.exportProfiles()
                    }
                    Button("Export Selected...") {
                        exportSelected()
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            profileManager.importFromFile(url: url)
        }
    }
    
    private func exportSelected() {
        // TODO: Implement export selected
    }
}

struct GlobalDefaultsSettings: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showingApplyAlert = false
    @State private var showingSaveAlert = false
    
    var body: some View {
        Form {
            Section("Terminal Settings") {
                TextField("Color Scheme", text: $profileManager.globalDefaults.terminalSettings.colorScheme)
                TextField("Font Family", text: $profileManager.globalDefaults.terminalSettings.fontFamily)
                Stepper("Font Size: \(profileManager.globalDefaults.terminalSettings.fontSize)", 
                       value: $profileManager.globalDefaults.terminalSettings.fontSize, 
                       in: 8...24)
                
                Picker("Cursor Style", selection: $profileManager.globalDefaults.terminalSettings.cursorStyle) {
                    ForEach(CursorStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                
                HStack {
                    Text("Scrollback Lines")
                    TextField("lines", value: $profileManager.globalDefaults.terminalSettings.scrollbackLines, format: .number)
                        .frame(width: 80)
                }
            }
            
            Section("Connection Settings") {
                Toggle("Compression", isOn: $profileManager.globalDefaults.compression)
                Toggle("Strict Host Key Checking", isOn: $profileManager.globalDefaults.strictHostKeyChecking)
                
                HStack {
                    Text("Connection Timeout")
                    TextField("seconds", value: $profileManager.globalDefaults.connectionTimeout, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                }
                
                HStack {
                    Text("Server Alive Interval")
                    TextField("seconds", value: $profileManager.globalDefaults.serverAliveInterval, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                }
            }
            
            Section("Default Commands") {
                Text("Commands to run on connection:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                CustomCommandsEditor(commands: $profileManager.globalDefaults.customCommands)
            }
            
            Section {
                HStack {
                    Spacer()
                    
                    if let selectedProfile = profileManager.selectedProfile {
                        Button("Save Current Profile as Defaults") {
                            profileManager.saveCurrentProfileAsDefaults(selectedProfile)
                            showingSaveAlert = true
                        }
                        .help("Use the settings from the currently selected profile as the new defaults")
                    }
                    
                    Button("Apply Defaults to All Profiles") {
                        showingApplyAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Update all existing profiles with the current default settings")
                    
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Defaults Saved", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text("The current profile's settings have been saved as the new defaults.")
        }
        .alert("Apply Defaults to All Profiles?", isPresented: $showingApplyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Apply", role: .destructive) {
                profileManager.applyDefaultsToAllProfiles()
            }
        } message: {
            Text("This will update all existing profiles with the current default settings. This action cannot be undone.")
        }
    }
}

struct CustomCommandsEditor: View {
    @Binding var commands: [String]
    @State private var newCommand = ""
    @State private var selection = Set<String>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Drag to reorder • Click to select • Delete key to remove")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !selection.isEmpty {
                    Text("\(selection.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            List(selection: $selection) {
                ForEach(commands.indices, id: \.self) { index in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(commands[index])
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .tag(commands[index])
                }
                .onMove { source, destination in
                    commands.move(fromOffsets: source, toOffset: destination)
                }
                .onDelete { indices in
                    commands.remove(atOffsets: indices)
                }
            }
            .frame(minHeight: 100, maxHeight: 200)
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .onDeleteCommand {
                if !selection.isEmpty {
                    commands.removeAll { selection.contains($0) }
                    selection.removeAll()
                }
            }
            
            HStack {
                TextField("New command", text: $newCommand)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !newCommand.isEmpty {
                            commands.append(newCommand)
                            newCommand = ""
                        }
                    }
                Button("Add") {
                    if !newCommand.isEmpty {
                        commands.append(newCommand)
                        newCommand = ""
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                
                if !selection.isEmpty {
                    Button(action: {
                        commands.removeAll { selection.contains($0) }
                        selection.removeAll()
                    }) {
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

