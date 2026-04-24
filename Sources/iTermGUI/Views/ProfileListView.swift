import SwiftUI

struct ProfileListView: View {
    @EnvironmentObject var profileManager: ProfileManager

    private var navigationTitle: String {
        profileManager.selectedGroup?.name ?? "Profiles"
    }

    private var navigationSubtitle: String {
        let count = profileManager.filteredProfiles.count
        return count == 1 ? "1 profile" : "\(count) profiles"
    }

    var body: some View {
        VStack(spacing: 0) {
            FilterBar()
                .environmentObject(profileManager)

            Divider()

            profileList
        }
        .navigationTitle(navigationTitle)
        .toolbar { toolbarContent }
        .onDeleteCommand {
            for profile in profileManager.selectedProfiles {
                profileManager.deleteProfile(profile)
            }
        }
        .onSubmit(of: .text) {
            handleSubmit()
        }
    }

    @ViewBuilder
    private var profileList: some View {
        if profileManager.filteredProfiles.isEmpty {
            ProfileListEmptyState(
                hasSearch: !profileManager.searchText.isEmpty,
                searchText: profileManager.searchText,
                onCreate: profileManager.createNewProfile
            )
        } else {
            List(profileManager.filteredProfiles, selection: $profileManager.selectedProfiles) { profile in
                ProfileRow(profile: profile) {
                    profileManager.connectToProfile(profile)
                }
                .tag(profile)
                .listRowSeparator(.hidden)
                .contextMenu {
                    profileContextMenu(for: profile)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .onChange(of: profileManager.selectedProfiles) { newSelection in
                if newSelection.count == 1, let firstProfile = newSelection.first {
                    profileManager.selectedProfile = firstProfile
                }
            }
        }
    }

    @ViewBuilder
    private func profileContextMenu(for profile: SSHProfile) -> some View {
        if profileManager.selectedProfiles.contains(profile) && profileManager.selectedProfiles.count > 1 {
            multiSelectionMenu
        } else {
            singleSelectionMenu(for: profile)
        }
    }

    @ViewBuilder
    private var multiSelectionMenu: some View {
        let count = profileManager.selectedProfiles.count
        Button("Connect \(count) Servers in Tabs") {
            profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .tabs)
        }
        Button("Connect \(count) Servers in Separate Windows") {
            profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .windows)
        }
        Divider()
        Button("Toggle Favorite for \(count) Profiles") {
            for profile in profileManager.selectedProfiles {
                profileManager.toggleFavorite(profile)
            }
        }
        Divider()
        Menu("Add \(count) Profiles to Group") {
            ForEach(customGroups) { group in
                Button(group.name) {
                    for profile in profileManager.selectedProfiles {
                        profileManager.addProfileToGroup(profile, group: group)
                    }
                }
            }
        }
        Divider()
        Button("Delete \(count) Profiles", role: .destructive) {
            for profile in profileManager.selectedProfiles {
                profileManager.deleteProfile(profile)
            }
        }
    }

    @ViewBuilder
    private func singleSelectionMenu(for profile: SSHProfile) -> some View {
        Button("Connect") { profileManager.connectToProfile(profile) }
        Button("SFTP File Transfer") { profileManager.openSFTPForProfile(profile) }
        Divider()
        Button("Edit") { profileManager.selectedProfile = profile }
        Button("Duplicate") { profileManager.duplicateProfile(profile) }
        Divider()
        Button(profile.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            profileManager.toggleFavorite(profile)
        }
        Divider()
        Menu("Add to Group") {
            ForEach(customGroups) { group in
                Button(group.name) {
                    profileManager.addProfileToGroup(profile, group: group)
                }
            }
        }
        if let currentGroup = currentCustomGroup(for: profile) {
            Button("Remove from \(currentGroup.name)") {
                profileManager.removeProfileFromGroup(profile, group: currentGroup)
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            profileManager.deleteProfile(profile)
        }
    }

    private var customGroups: [ProfileGroup] {
        profileManager.groups.filter { !["All Profiles", "Favorites", "Recent"].contains($0.name) }
    }

    private func currentCustomGroup(for profile: SSHProfile) -> ProfileGroup? {
        profileManager.groups.first {
            $0.profileIDs.contains(profile.id) && !["All Profiles", "Favorites", "Recent"].contains($0.name)
        }
    }

    private func handleSubmit() {
        if let firstProfile = profileManager.selectedProfiles.first {
            if profileManager.selectedProfiles.count == 1 {
                profileManager.connectToProfile(firstProfile)
            } else {
                profileManager.connectToProfiles(Array(profileManager.selectedProfiles), mode: .tabs)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
                .help("Connect selected profiles")
            }
        }

        ToolbarItem(placement: .automatic) {
            Button {
                profileManager.createNewProfile()
            } label: {
                Image(systemName: "plus")
            }
            .help("New Profile (⌘N)")
        }

        ToolbarItem(placement: .automatic) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Open Settings (⌘,)")
            } else {
                Button {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Open Settings (⌘,)")
            }
        }
    }
}

private struct ProfileListEmptyState: View {
    let hasSearch: Bool
    let searchText: String
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: hasSearch ? "magnifyingglass" : "square.stack.3d.up.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(hasSearch ? "No Matches" : "No Profiles")
                    .font(.title3.weight(.semibold))

                Text(hasSearch
                     ? "No profiles match \u{201C}\(searchText)\u{201D}"
                     : "Create your first profile to get started"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            if !hasSearch {
                Button(action: onCreate) {
                    Label("New Profile", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ProfileRow: View {
    let profile: SSHProfile
    var onDoubleClick: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 11) {
            ProfileAvatar(profile: profile, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    if profile.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
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

                Text(profile.connectionString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !profile.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(profile.tags).sorted().prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.tint.opacity(0.13), in: Capsule())
                        }
                        if profile.tags.count > 3 {
                            Text("+\(profile.tags.count - 3)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(isHovered ? Color.accentColor : Color.secondary.opacity(0.0))
                .help("Double-click to connect")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onDoubleClick {
            onDoubleClick?()
        }
    }
}


struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search profiles, hosts, tags", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isFocused ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }
}

struct SortBar: View {
    @Binding var sortOption: ProfileSortOption
    @Binding var sortAscending: Bool

    var body: some View {
        Menu {
            Picker("Sort by", selection: $sortOption) {
                ForEach(ProfileSortOption.allCases, id: \.self) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            Divider()
            Toggle("Ascending", isOn: $sortAscending)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                Text(sortOption.rawValue)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort options")
    }
}

private struct FilterBar: View {
    @EnvironmentObject var profileManager: ProfileManager

    private var profileCountLabel: String {
        let count = profileManager.filteredProfiles.count
        return count == 1 ? "1 profile" : "\(count) profiles"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SearchBar(text: $profileManager.searchText)

                SortBar(
                    sortOption: $profileManager.sortOption,
                    sortAscending: $profileManager.sortAscending
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Text(profileCountLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if !profileManager.searchText.isEmpty {
                    Button {
                        profileManager.searchText = ""
                    } label: {
                        Text("Clear filter")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }
}
