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
        }
        .frame(width: 500, height: 400)
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

