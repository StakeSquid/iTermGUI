import Foundation
import SwiftUI
import Combine

enum ConnectionMode: String, CaseIterable {
    case tabs = "Tabs in Same Window"
    case windows = "Separate Windows"
}

@MainActor
class ProfileManager: ObservableObject {
    @Published var profiles: [SSHProfile] = []
    @Published var groups: [ProfileGroup] = ProfileGroup.defaultGroups
    @Published var selectedProfile: SSHProfile?
    @Published var selectedProfiles: Set<SSHProfile> = []
    @Published var searchText: String = ""
    @Published var selectedGroup: ProfileGroup?
    @Published var isImporting: Bool = false
    @Published var isExporting: Bool = false
    @Published var connectionMode: ConnectionMode = .tabs
    
    private let storage = ProfileStorage()
    private let sshConfigParser = SSHConfigParser()
    private let iTerm2Service = ITerm2Service()
    private var cancellables = Set<AnyCancellable>()
    
    var filteredProfiles: [SSHProfile] {
        let filtered = searchText.isEmpty ? profiles : profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let group = selectedGroup {
            switch group.name {
            case "All Profiles":
                return filtered
            case "Favorites":
                return filtered.filter { $0.isFavorite }
            case "Recent":
                return filtered.filter { $0.lastUsed != nil }.sorted {
                    ($0.lastUsed ?? Date.distantPast) > ($1.lastUsed ?? Date.distantPast)
                }.prefix(10).map { $0 }
            default:
                return filtered.filter { group.profileIDs.contains($0.id) }
            }
        }
        
        return filtered
    }
    
    init() {
        loadProfiles()
        setupAutoSave()
    }
    
    private func setupAutoSave() {
        $profiles
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveProfiles()
            }
            .store(in: &cancellables)
    }
    
    func loadProfiles() {
        profiles = storage.loadProfiles()
        groups = storage.loadGroups()
        if groups.isEmpty {
            groups = ProfileGroup.defaultGroups
        }
    }
    
    func saveProfiles() {
        storage.saveProfiles(profiles)
        storage.saveGroups(groups)
    }
    
    func createNewProfile() {
        let newProfile = SSHProfile(
            name: "New Profile",
            host: "hostname.example.com",
            username: NSUserName()
        )
        profiles.append(newProfile)
        selectedProfile = newProfile
    }
    
    func deleteProfile(_ profile: SSHProfile) {
        profiles.removeAll { $0.id == profile.id }
        for i in groups.indices {
            groups[i].profileIDs.remove(profile.id)
        }
        if selectedProfile?.id == profile.id {
            selectedProfile = nil
        }
    }
    
    func duplicateProfile(_ profile: SSHProfile) {
        let newProfile = SSHProfile(
            id: UUID(),
            name: "\(profile.name) Copy",
            host: profile.host,
            port: profile.port,
            username: profile.username,
            authMethod: profile.authMethod,
            privateKeyPath: profile.privateKeyPath,
            password: profile.password,
            group: profile.group,
            tags: profile.tags,
            jumpHost: profile.jumpHost,
            localForwards: profile.localForwards,
            remoteForwards: profile.remoteForwards,
            proxyCommand: profile.proxyCommand,
            identityFile: profile.identityFile,
            strictHostKeyChecking: profile.strictHostKeyChecking,
            compression: profile.compression,
            connectionTimeout: profile.connectionTimeout,
            serverAliveInterval: profile.serverAliveInterval,
            isFavorite: profile.isFavorite,
            customCommands: profile.customCommands,
            terminalSettings: profile.terminalSettings,
            lastUsed: nil,
            createdAt: Date(),
            modifiedAt: Date()
        )
        profiles.append(newProfile)
        selectedProfile = newProfile
    }
    
    func toggleFavorite(_ profile: SSHProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].isFavorite.toggle()
        }
    }
    
    func connectToProfile(_ profile: SSHProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].lastUsed = Date()
        }
        iTerm2Service.openConnection(profile: profile, mode: .windows)
    }
    
    func connectToProfiles(_ profiles: [SSHProfile], mode: ConnectionMode = .tabs) {
        for profile in profiles {
            if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) {
                self.profiles[index].lastUsed = Date()
            }
        }
        iTerm2Service.openConnections(profiles: profiles, mode: mode)
    }
    
    func connectToSelectedProfiles() {
        let profilesToConnect = Array(selectedProfiles)
        if !profilesToConnect.isEmpty {
            connectToProfiles(profilesToConnect)
        }
    }
    
    func importFromSSHConfig() {
        isImporting = true
        Task {
            do {
                let importedProfiles = try await sshConfigParser.parseDefaultConfig()
                await MainActor.run {
                    for profile in importedProfiles {
                        if !profiles.contains(where: { $0.name == profile.name }) {
                            profiles.append(profile)
                        }
                    }
                    isImporting = false
                }
            } catch {
                print("Error importing SSH config: \(error)")
                await MainActor.run {
                    isImporting = false
                }
            }
        }
    }
    
    func importFromFile(url: URL) {
        Task {
            do {
                let importedProfiles = try await sshConfigParser.parseConfigFile(at: url)
                await MainActor.run {
                    for profile in importedProfiles {
                        if !profiles.contains(where: { $0.name == profile.name }) {
                            profiles.append(profile)
                        }
                    }
                }
            } catch {
                print("Error importing from file: \(error)")
            }
        }
    }
    
    func exportProfiles() {
        isExporting = true
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "ssh_config"
        panel.message = "Export SSH profiles to config file"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.exportToFile(url: url)
            }
            self.isExporting = false
        }
    }
    
    private func exportToFile(url: URL) {
        let configContent = profiles.map { $0.toSSHConfigEntry() }.joined(separator: "\n\n")
        do {
            try configContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Error exporting profiles: \(error)")
        }
    }
    
    func addProfileToGroup(_ profile: SSHProfile, group: ProfileGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].profileIDs.insert(profile.id)
        }
    }
    
    func removeProfileFromGroup(_ profile: SSHProfile, group: ProfileGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].profileIDs.remove(profile.id)
        }
    }
}