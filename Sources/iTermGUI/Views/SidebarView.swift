import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var isAddingGroup = false
    @State private var newGroupName = ""
    
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
                                // TODO: Implement rename
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
    }
}

