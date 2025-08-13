import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } content: {
            ProfileListView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        } detail: {
            if let profile = profileManager.selectedProfile {
                ProfileDetailView(profile: profile)
                    .id(profile.id) // Force view refresh when profile ID changes
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Profile Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a profile from the list or create a new one")
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                Button(action: {
                    profileManager.createNewProfile()
                }) {
                    Label("New Profile", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    profileManager.importFromSSHConfig()
                }) {
                    Label("Import SSH Config", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

