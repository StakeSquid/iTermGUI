import SwiftUI

struct ProfileListView: View {
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $profileManager.searchText)
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            List(profileManager.filteredProfiles, selection: $profileManager.selectedProfiles) { profile in
                ProfileRow(profile: profile)
                    .tag(profile)
                    .contextMenu {
                        if profileManager.selectedProfiles.contains(profile) && profileManager.selectedProfiles.count > 1 {
                            // Multi-selection context menu
                            Button("Connect \(profileManager.selectedProfiles.count) Servers in Tabs") {
                                profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .tabs)
                            }
                            Button("Connect \(profileManager.selectedProfiles.count) Servers in Separate Windows") {
                                profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .windows)
                            }
                            Divider()
                            Button("Delete \(profileManager.selectedProfiles.count) Profiles", role: .destructive) {
                                for selectedProfile in profileManager.selectedProfiles {
                                    profileManager.deleteProfile(selectedProfile)
                                }
                            }
                        } else {
                            // Single selection context menu
                            Button("Connect") {
                                profileManager.connectToProfile(profile)
                            }
                            Button("Connect in New Window") {
                                profileManager.connectToProfile(profile)
                            }
                            Divider()
                            Button("Edit") {
                                profileManager.selectedProfile = profile
                            }
                            Button("Duplicate") {
                                profileManager.duplicateProfile(profile)
                            }
                            Divider()
                            Button("Toggle Favorite") {
                                profileManager.toggleFavorite(profile)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                profileManager.deleteProfile(profile)
                            }
                        }
                    }
            }
            .listStyle(.inset)
            .onChange(of: profileManager.selectedProfiles) { newSelection in
                // Update selectedProfile for detail view
                if let firstProfile = newSelection.first, newSelection.count == 1 {
                    profileManager.selectedProfile = firstProfile
                }
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if !profileManager.selectedProfiles.isEmpty {
                    Menu {
                        Button("Connect in Tabs") {
                            profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .tabs)
                        }
                        Button("Connect in Separate Windows") {
                            profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .windows)
                        }
                    } label: {
                        Label("Connect \(profileManager.selectedProfiles.count)", systemImage: "play.fill")
                    }
                    .disabled(profileManager.selectedProfiles.isEmpty)
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    profileManager.createNewProfile()
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onDeleteCommand {
            for profile in profileManager.selectedProfiles {
                profileManager.deleteProfile(profile)
            }
        }
    }
}

struct ProfileRow: View {
    let profile: SSHProfile
    
    var body: some View {
        HStack {
            Image(systemName: profile.isFavorite ? "star.fill" : "star")
                .foregroundColor(profile.isFavorite ? .yellow : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .fontWeight(.medium)
                HStack {
                    Text(profile.connectionString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let lastUsed = profile.lastUsed {
                        Text("• \(lastUsed, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search profiles...", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}