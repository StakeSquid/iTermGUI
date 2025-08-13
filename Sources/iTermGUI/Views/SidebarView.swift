import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var isAddingGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroup: ProfileGroup?
    @State private var renameText = ""
    
    var body: some View {
        List(selection: $profileManager.selectedGroup) {
            Section("Groups") {
                ForEach(profileManager.groups) { group in
                    HStack {
                        Image(systemName: group.icon)
                            .foregroundColor(Color(group.color))
                        Text(group.name)
                        Spacer()
                        if group.name != "All Profiles" {
                            let count = profileManager.profiles.filter { profile in
                                group.name == "Favorites" ? profile.isFavorite : group.profileIDs.contains(profile.id)
                            }.count
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(group)
                    .contextMenu {
                        if !["All Profiles", "Favorites", "Recent"].contains(group.name) {
                            Button("Rename") {
                                renameText = group.name
                                renamingGroup = group
                            }
                            Button("Delete", role: .destructive) {
                                profileManager.groups.removeAll { $0.id == group.id }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("iTermGUI")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    isAddingGroup = true
                }) {
                    Image(systemName: "plus")
                }
                .popover(isPresented: $isAddingGroup) {
                    VStack(spacing: 15) {
                        Text("New Group")
                            .font(.headline)
                        TextField("Group Name", text: $newGroupName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        HStack {
                            Button("Cancel") {
                                isAddingGroup = false
                                newGroupName = ""
                            }
                            .keyboardShortcut(.escape)
                            
                            Button("Create") {
                                if !newGroupName.isEmpty {
                                    let newGroup = ProfileGroup(
                                        name: newGroupName,
                                        sortOrder: profileManager.groups.count
                                    )
                                    profileManager.groups.append(newGroup)
                                    newGroupName = ""
                                    isAddingGroup = false
                                }
                            }
                            .keyboardShortcut(.return)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if profileManager.selectedGroup == nil {
                profileManager.selectedGroup = profileManager.groups.first
            }
        }
        .sheet(item: $renamingGroup) { group in
            VStack(spacing: 15) {
                Text("Rename Group")
                    .font(.headline)
                TextField("Group Name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                HStack {
                    Button("Cancel") {
                        renamingGroup = nil
                        renameText = ""
                    }
                    .keyboardShortcut(.escape)
                    
                    Button("Rename") {
                        if !renameText.isEmpty,
                           let index = profileManager.groups.firstIndex(where: { $0.id == group.id }) {
                            profileManager.groups[index].name = renameText
                            profileManager.saveProfiles()
                        }
                        renamingGroup = nil
                        renameText = ""
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 300, height: 150)
        }
    }
}

