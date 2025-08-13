import SwiftUI

struct ProfileListView: View {
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                SearchBar(text: $profileManager.searchText)
                    .padding(.horizontal)
                
                SortBar(sortOption: $profileManager.sortOption, 
                        sortAscending: $profileManager.sortAscending)
                    .padding(.horizontal)
            }
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
                            Menu("Add \(profileManager.selectedProfiles.count) Profiles to Group") {
                                ForEach(profileManager.groups.filter { !["All Profiles", "Favorites", "Recent"].contains($0.name) }) { group in
                                    Button(group.name) {
                                        for selectedProfile in profileManager.selectedProfiles {
                                            profileManager.addProfileToGroup(selectedProfile, group: group)
                                        }
                                    }
                                }
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
                            Menu("Add to Group") {
                                ForEach(profileManager.groups.filter { !["All Profiles", "Favorites", "Recent"].contains($0.name) }) { group in
                                    Button(group.name) {
                                        profileManager.addProfileToGroup(profile, group: group)
                                    }
                                }
                            }
                            if let currentGroup = profileManager.groups.first(where: { $0.profileIDs.contains(profile.id) && !["All Profiles", "Favorites", "Recent"].contains($0.name) }) {
                                Button("Remove from \(currentGroup.name)") {
                                    profileManager.removeProfileFromGroup(profile, group: currentGroup)
                                }
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
            
            ToolbarItem(placement: .automatic) {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                    }
                    .help("Open Settings (⌘,)")
                } else {
                    Button(action: {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }) {
                        Image(systemName: "gearshape")
                    }
                    .help("Open Settings (⌘,)")
                }
            }
        }
        .onDeleteCommand {
            for profile in profileManager.selectedProfiles {
                profileManager.deleteProfile(profile)
            }
        }
        .onSubmit {
            // Connect when pressing Enter
            if let firstProfile = profileManager.selectedProfiles.first {
                if profileManager.selectedProfiles.count == 1 {
                    profileManager.connectToProfile(firstProfile)
                } else {
                    profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .tabs)
                }
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

struct SortBar: View {
    @Binding var sortOption: ProfileSortOption
    @Binding var sortAscending: Bool
    
    var body: some View {
        HStack {
            Label("Sort by:", systemImage: "arrow.up.arrow.down")
                .foregroundColor(.secondary)
                .labelStyle(.titleAndIcon)
            
            Picker("Sort by", selection: $sortOption) {
                ForEach(ProfileSortOption.allCases, id: \.self) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            Button(action: {
                sortAscending.toggle()
            }) {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help(sortAscending ? "Sort ascending" : "Sort descending")
            
            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}