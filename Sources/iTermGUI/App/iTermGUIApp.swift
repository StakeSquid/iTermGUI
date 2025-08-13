import SwiftUI

@main
struct iTermGUIApp: App {
    @StateObject private var profileManager = ProfileManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileManager)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Profile") {
                    profileManager.createNewProfile()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .importExport) {
                Button("Import SSH Config...") {
                    profileManager.importFromSSHConfig()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Export Profiles...") {
                    profileManager.exportProfiles()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(profileManager)
        }
    }
}