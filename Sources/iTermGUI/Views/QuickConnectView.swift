import SwiftUI

struct QuickConnectView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var searchText = ""
    
    var filteredProfiles: [SSHProfile] {
        if searchText.isEmpty {
            return profileManager.profiles.filter { $0.isFavorite || $0.lastUsed != nil }
                .sorted { profile1, profile2 in
                    if profile1.isFavorite != profile2.isFavorite {
                        return profile1.isFavorite
                    }
                    let date1 = profile1.lastUsed ?? Date.distantPast
                    let date2 = profile2.lastUsed ?? Date.distantPast
                    return date1 > date2
                }
                .prefix(10)
                .map { $0 }
        } else {
            return profileManager.profiles.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.host.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search profiles...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            
            Divider()
            
            if filteredProfiles.isEmpty {
                VStack {
                    Spacer()
                    Text("No profiles found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredProfiles) { profile in
                            QuickConnectRow(profile: profile) {
                                profileManager.connectToProfile(profile)
                                NSApp.keyWindow?.close()
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 400)
    }
}

struct QuickConnectRow: View {
    let profile: SSHProfile
    let onConnect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onConnect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        if profile.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        Text(profile.name)
                            .fontWeight(.medium)
                    }
                    Text(profile.connectionString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.accentColor)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}