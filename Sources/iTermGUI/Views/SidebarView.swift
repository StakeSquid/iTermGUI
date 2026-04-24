import SwiftUI

private let systemGroupNames: Set<String> = ["All Profiles", "Favorites", "Recent"]

struct SidebarView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var isAddingGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroup: ProfileGroup?
    @State private var renameText = ""

    private var sortedGroups: [ProfileGroup] {
        profileManager.groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var smartGroups: [ProfileGroup] {
        sortedGroups.filter { systemGroupNames.contains($0.name) }
    }

    private var customGroups: [ProfileGroup] {
        sortedGroups.filter { !systemGroupNames.contains($0.name) }
    }

    var body: some View {
        List(selection: $profileManager.selectedGroup) {
            Section {
                ForEach(smartGroups) { group in
                    GroupRow(
                        group: group,
                        count: count(for: group),
                        isSystem: true
                    )
                    .tag(group)
                }
            } header: {
                SectionHeader(title: "Smart")
            }

            Section {
                ForEach(customGroups) { group in
                    GroupRow(
                        group: group,
                        count: count(for: group),
                        isSystem: false
                    )
                    .tag(group)
                    .contextMenu {
                        Button("Rename") {
                            renameText = group.name
                            renamingGroup = group
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteGroup(group)
                        }
                    }
                }
                .onMove(perform: moveCustomGroups)
            } header: {
                HStack(spacing: 6) {
                    SectionHeader(title: "Groups")
                    Spacer()
                    Button {
                        isAddingGroup = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("New Group")
                    .popover(isPresented: $isAddingGroup, arrowEdge: .top) {
                        NewGroupPopover(
                            name: $newGroupName,
                            onCancel: {
                                isAddingGroup = false
                                newGroupName = ""
                            },
                            onCreate: createGroup
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("iTermGUI")
        .onAppear {
            if profileManager.selectedGroup == nil {
                profileManager.selectedGroup = profileManager.groups.first
            }
        }
        .sheet(item: $renamingGroup) { group in
            RenameGroupSheet(
                originalName: group.name,
                renameText: $renameText,
                onCancel: {
                    renamingGroup = nil
                    renameText = ""
                },
                onSave: { newName in
                    renameGroup(group, to: newName)
                    renamingGroup = nil
                    renameText = ""
                }
            )
        }
    }

    private func count(for group: ProfileGroup) -> Int? {
        switch group.name {
        case "All Profiles":
            return profileManager.profiles.count
        case "Favorites":
            return profileManager.profiles.filter(\.isFavorite).count
        case "Recent":
            return profileManager.profiles.filter { $0.lastUsed != nil }.count
        default:
            return profileManager.profiles.filter { group.profileIDs.contains($0.id) }.count
        }
    }

    private func createGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newGroup = ProfileGroup(
            name: trimmed,
            sortOrder: profileManager.groups.count
        )
        profileManager.groups.append(newGroup)
        newGroupName = ""
        isAddingGroup = false
    }

    private func deleteGroup(_ group: ProfileGroup) {
        profileManager.groups.removeAll { $0.id == group.id }
    }

    private func renameGroup(_ group: ProfileGroup, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = profileManager.groups.firstIndex(where: { $0.id == group.id }) else { return }
        profileManager.groups[index].name = trimmed
        profileManager.saveProfiles()
    }

    private func moveCustomGroups(from source: IndexSet, to destination: Int) {
        var custom = customGroups
        custom.move(fromOffsets: source, toOffset: destination)

        let smartCount = smartGroups.count
        for (index, group) in smartGroups.enumerated() {
            if let i = profileManager.groups.firstIndex(where: { $0.id == group.id }) {
                profileManager.groups[i].sortOrder = index
            }
        }
        for (index, group) in custom.enumerated() {
            if let i = profileManager.groups.firstIndex(where: { $0.id == group.id }) {
                profileManager.groups[i].sortOrder = smartCount + index
            }
        }
        profileManager.saveProfiles()
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct GroupRow: View {
    let group: ProfileGroup
    let count: Int?
    let isSystem: Bool

    private var iconColor: Color {
        Color(group.color)
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: group.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 18, alignment: .center)

            Text(group.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if let count {
                Text("\(count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 1)
    }
}

private struct NewGroupPopover: View {
    @Binding var name: String
    let onCancel: () -> Void
    let onCreate: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Group")
                .font(.headline)

            TextField("Group Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .frame(width: 220)
                .onSubmit(onCreate)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape)
                Button("Create", action: onCreate)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .onAppear { isFocused = true }
    }
}

private struct RenameGroupSheet: View {
    let originalName: String
    @Binding var renameText: String
    let onCancel: () -> Void
    let onSave: (String) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Group")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Original")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(originalName)
                    .font(.subheadline)
            }

            TextField("Group Name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { onSave(renameText) }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape)
                Button("Rename") { onSave(renameText) }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { isFocused = true }
    }
}
