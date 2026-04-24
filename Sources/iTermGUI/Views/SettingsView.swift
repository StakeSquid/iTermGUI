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
            .environmentObject(profileManager)
            .tabItem {
                Label("Backup", systemImage: "externaldrive")
            }

            ImportExportSettings()
                .tabItem {
                    Label("Import / Export", systemImage: "square.and.arrow.up.on.square")
                }

            GlobalDefaultsSettings()
                .tabItem {
                    Label("Defaults", systemImage: "text.badge.checkmark")
                }
        }
        .frame(width: 540, height: 480)
    }
}

// MARK: - General

struct GeneralSettings: View {
    @Binding var defaultUsername: String
    @Binding var defaultPort: Int
    @Binding var defaultAuthMethod: String
    @Binding var showMenuBarIcon: Bool
    @Binding var launchAtLogin: Bool

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $defaultUsername, prompt: Text(NSUserName()))
                TextField("Port", value: $defaultPort, format: .number, prompt: Text("22"))
                Picker("Auth Method", selection: $defaultAuthMethod) {
                    ForEach(AuthMethod.allCases, id: \.rawValue) { method in
                        Text(method.rawValue).tag(method.rawValue)
                    }
                }
            } header: {
                Text("Default Connection Settings")
            } footer: {
                Text("These values are used when creating a new profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Application") {
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Backup

struct BackupSettings: View {
    @EnvironmentObject var profileManager: ProfileManager
    @Binding var autoBackup: Bool
    @Binding var backupInterval: Int
    @State private var backupLocation: String = "~/Documents/iTermGUI Backups"
    @State private var showingBackupAlert = false
    @State private var showingRestoreAlert = false
    @State private var backupMessage = ""
    @State private var restoreMessage = ""
    @State private var isBackupSuccess = false
    @State private var isRestoreSuccess = false

    var body: some View {
        Form {
            Section("Automatic Backup") {
                Toggle("Enable automatic backup", isOn: $autoBackup)

                if autoBackup {
                    Picker("Interval", selection: $backupInterval) {
                        Text("Daily").tag(1)
                        Text("Weekly").tag(7)
                        Text("Monthly").tag(30)
                    }

                    LabeledContent("Location") {
                        HStack(spacing: 6) {
                            TextField("", text: $backupLocation, prompt: Text("Path"))
                                .labelsHidden()
                                .font(.caption.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                if panel.runModal() == .OK {
                                    backupLocation = panel.url?.path ?? backupLocation
                                }
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("Manual Actions") {
                HStack {
                    Button {
                        performBackup()
                    } label: {
                        Label("Back Up Now…", systemImage: "arrow.clockwise.icloud")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        restoreFromBackup()
                    } label: {
                        Label("Restore from Backup…", systemImage: "arrow.counterclockwise.icloud")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            }
        }
        .formStyle(.grouped)
        .alert(isBackupSuccess ? "Backup Successful" : "Backup Failed", isPresented: $showingBackupAlert) {
            Button("OK") { }
        } message: {
            Text(backupMessage)
        }
        .alert(isRestoreSuccess ? "Restore Successful" : "Restore Failed", isPresented: $showingRestoreAlert) {
            if isRestoreSuccess {
                Button("OK") { profileManager.loadProfiles() }
            } else {
                Button("OK") { }
            }
        } message: {
            Text(restoreMessage)
        }
    }

    private func performBackup() {
        let panel = NSSavePanel()
        let dateString = Date().formatted(date: .abbreviated, time: .omitted).replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "iTermGUI_Backup_\(dateString).json"
        panel.allowedContentTypes = [.json]
        panel.message = "Choose location for backup file"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let backupData = BackupData(
                        profiles: profileManager.profiles,
                        groups: profileManager.groups,
                        globalDefaults: profileManager.globalDefaults,
                        backupDate: Date()
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(backupData)
                    try data.write(to: url)
                    backupMessage = "Backup saved successfully to \(url.lastPathComponent)"
                    isBackupSuccess = true
                } catch {
                    backupMessage = "Failed to save backup: \(error.localizedDescription)"
                    isBackupSuccess = false
                }
                showingBackupAlert = true
            }
        }
    }

    private func restoreFromBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Select backup file to restore"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let backupData = try decoder.decode(BackupData.self, from: data)
                    profileManager.profiles = backupData.profiles
                    profileManager.groups = backupData.groups
                    profileManager.globalDefaults = backupData.globalDefaults
                    profileManager.saveProfiles()

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short

                    restoreMessage = "Successfully restored \(backupData.profiles.count) profiles from backup created on \(dateFormatter.string(from: backupData.backupDate))"
                    isRestoreSuccess = true
                } catch {
                    restoreMessage = "Failed to restore backup: \(error.localizedDescription)"
                    isRestoreSuccess = false
                }
                showingRestoreAlert = true
            }
        }
    }
}

struct BackupData: Codable {
    let profiles: [SSHProfile]
    let groups: [ProfileGroup]
    let globalDefaults: GlobalDefaults
    let backupDate: Date
}

// MARK: - Import / Export

struct ImportExportSettings: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var importFormat = "SSH Config"
    @State private var exportFormat = "SSH Config"

    var body: some View {
        Form {
            Section {
                Picker("Format", selection: $importFormat) {
                    Text("SSH Config").tag("SSH Config")
                    Text("JSON").tag("JSON")
                    Text("PuTTY").tag("PuTTY")
                }

                HStack {
                    Button {
                        importFromFile()
                    } label: {
                        Label("Import from File…", systemImage: "doc")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        profileManager.importFromSSHConfig()
                    } label: {
                        Label("Import ~/.ssh/config", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            } header: {
                Text("Import")
            }

            Section {
                Picker("Format", selection: $exportFormat) {
                    Text("SSH Config").tag("SSH Config")
                    Text("JSON").tag("JSON")
                    Text("iTerm2 Dynamic Profiles").tag("iTerm2")
                }

                HStack {
                    Button {
                        profileManager.exportProfiles()
                    } label: {
                        Label("Export All Profiles…", systemImage: "tray.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        exportSelected()
                    } label: {
                        Label("Export Selected…", systemImage: "doc.badge.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            } header: {
                Text("Export")
            }
        }
        .formStyle(.grouped)
    }

    private func importFromFile() {
        if importFormat == "JSON" {
            profileManager.importProfilesFromJSON()
        } else {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.text]
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let url = panel.url {
                profileManager.importFromFile(url: url)
            }
        }
    }

    private func exportSelected() {
        if exportFormat == "JSON" {
            profileManager.exportProfilesToJSON()
        } else {
            profileManager.exportProfiles()
        }
    }
}

// MARK: - Global Defaults

struct GlobalDefaultsSettings: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showingApplyAlert = false
    @State private var showingSaveAlert = false

    var body: some View {
        Form {
            Section("iTerm2 Terminal") {
                TextField("Color Scheme", text: $profileManager.globalDefaults.terminalSettings.colorScheme, prompt: Text("Default"))
                TextField("Font Family", text: $profileManager.globalDefaults.terminalSettings.fontFamily, prompt: Text("Monaco"))
                Stepper(
                    "Font Size: \(profileManager.globalDefaults.terminalSettings.fontSize) pt",
                    value: $profileManager.globalDefaults.terminalSettings.fontSize,
                    in: 8...24
                )

                Picker("Cursor Style", selection: $profileManager.globalDefaults.terminalSettings.cursorStyle) {
                    ForEach(CursorStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }

                TextField("Scrollback Lines", value: $profileManager.globalDefaults.terminalSettings.scrollbackLines, format: .number, prompt: Text("10000"))
            }

            Section("Embedded Terminal") {
                Picker("Theme", selection: $profileManager.globalDefaults.embeddedTerminalSettings.theme) {
                    ForEach(TerminalTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }

                TextField("Font Family", text: $profileManager.globalDefaults.embeddedTerminalSettings.fontFamily, prompt: Text("SF Mono"))

                Stepper(
                    "Font Size: \(Int(profileManager.globalDefaults.embeddedTerminalSettings.fontSize)) pt",
                    value: $profileManager.globalDefaults.embeddedTerminalSettings.fontSize,
                    in: 9...24
                )

                Toggle("Mouse Reporting", isOn: $profileManager.globalDefaults.embeddedTerminalSettings.mouseReporting)
                Toggle("Auto Reconnect", isOn: $profileManager.globalDefaults.embeddedTerminalSettings.autoReconnect)

                TextField("Scrollback Lines", value: $profileManager.globalDefaults.embeddedTerminalSettings.scrollbackLines, format: .number, prompt: Text("10000"))
            }

            Section("Connection") {
                Toggle("Compression", isOn: $profileManager.globalDefaults.compression)
                Toggle("Strict Host Key Checking", isOn: $profileManager.globalDefaults.strictHostKeyChecking)

                LabeledContent("Connection Timeout") {
                    UnitNumberField(
                        value: $profileManager.globalDefaults.connectionTimeout,
                        unit: "seconds",
                        prompt: "30",
                        disabled: false
                    )
                }

                LabeledContent("Server Alive Interval") {
                    UnitNumberField(
                        value: $profileManager.globalDefaults.serverAliveInterval,
                        unit: "seconds",
                        prompt: "60",
                        disabled: false
                    )
                }
            }

            Section {
                CustomCommandsEditor(commands: $profileManager.globalDefaults.customCommands)
            } header: {
                Text("Default Startup Commands")
            } footer: {
                Text("New profiles inherit these commands.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    if let selectedProfile = profileManager.selectedProfile {
                        Button {
                            profileManager.saveCurrentProfileAsDefaults(selectedProfile)
                            showingSaveAlert = true
                        } label: {
                            Label("Save Current as Defaults", systemImage: "square.and.arrow.down.on.square")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .help("Use the settings from the currently selected profile as the new defaults")
                    }

                    Button(role: .destructive) {
                        showingApplyAlert = true
                    } label: {
                        Label("Apply to All Profiles", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .help("Update all existing profiles with the current default settings")
                }
            }
        }
        .formStyle(.grouped)
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

// MARK: - Commands editor (Settings)

struct CustomCommandsEditor: View {
    @Binding var commands: [String]
    @State private var newCommand = ""
    @State private var selection = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Drag to reorder \u{2022} Click to select")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !selection.isEmpty {
                    Text("\(selection.count) selected")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            List(selection: $selection) {
                ForEach(commands, id: \.self) { command in
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(command)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .tag(command)
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

            HStack(spacing: 8) {
                TextField("New command", text: $newCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        addCommand()
                    }

                Button("Add", action: addCommand)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(newCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !selection.isEmpty {
                    Button(role: .destructive) {
                        commands.removeAll { selection.contains($0) }
                        selection.removeAll()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func addCommand() {
        let trimmed = newCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        commands.append(trimmed)
        newCommand = ""
    }
}
