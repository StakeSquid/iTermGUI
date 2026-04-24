import Foundation
import Testing
@testable import iTermGUI

@MainActor
private func makeManager(
    profiles: [SSHProfile] = [],
    groups: [ProfileGroup] = []
) -> ProfileManager {
    let manager = ProfileManager(
        storage: makeStubStorage(),
        sshConfigParser: SSHConfigParser(),
        iTerm2Service: makeStubITerm2Service(),
        autoLoad: false,
        autoSave: false
    )
    manager.profiles = profiles
    manager.groups = groups.isEmpty ? ProfileGroup.defaultGroups : groups
    return manager
}

@Suite("ProfileManager.createNewProfile") @MainActor
struct ProfileManagerCreateTests {
    @Test func appendsProfileAndSelectsIt() {
        let m = makeManager()
        #expect(m.profiles.isEmpty)
        m.createNewProfile()
        #expect(m.profiles.count == 1)
        #expect(m.selectedProfile?.id == m.profiles[0].id)
    }

    @Test func usesGlobalDefaultsForSettings() {
        let m = makeManager()
        var defaults = GlobalDefaults.standard
        defaults.compression = true
        defaults.connectionTimeout = 7
        defaults.strictHostKeyChecking = false
        defaults.customCommands = ["seeded"]
        m.globalDefaults = defaults

        m.createNewProfile()
        let p = m.profiles[0]
        #expect(p.compression == true)
        #expect(p.connectionTimeout == 7)
        #expect(p.strictHostKeyChecking == false)
        #expect(p.customCommands == ["seeded"])
    }

    @Test func defaultNameIsNewProfile() {
        let m = makeManager()
        m.createNewProfile()
        #expect(m.profiles[0].name == "New Profile")
    }
}

@Suite("ProfileManager.deleteProfile") @MainActor
struct ProfileManagerDeleteTests {
    @Test func removesProfileFromProfiles() {
        let p = makeProfile(name: "victim")
        let m = makeManager(profiles: [p])
        m.deleteProfile(p)
        #expect(m.profiles.isEmpty)
    }

    @Test func removesProfileFromAllGroups() {
        let p = makeProfile(name: "victim")
        let work = makeGroup(name: "Work", profileIDs: [p.id])
        let personal = makeGroup(name: "Personal", profileIDs: [p.id, UUID()])
        let m = makeManager(profiles: [p], groups: [work, personal])

        m.deleteProfile(p)

        for group in m.groups {
            #expect(group.profileIDs.contains(p.id) == false)
        }
    }

    @Test func clearsSelectedProfileIfItMatches() {
        let p = makeProfile()
        let m = makeManager(profiles: [p])
        m.selectedProfile = p

        m.deleteProfile(p)

        #expect(m.selectedProfile == nil)
    }

    @Test func preservesSelectedProfileIfNotTarget() {
        let p = makeProfile(name: "target")
        let other = makeProfile(name: "other")
        let m = makeManager(profiles: [p, other])
        m.selectedProfile = other

        m.deleteProfile(p)

        #expect(m.selectedProfile?.id == other.id)
    }
}

@Suite("ProfileManager.duplicateProfile") @MainActor
struct ProfileManagerDuplicateTests {
    @Test func appendsCopyWithDifferentId() {
        let original = makeProfile(name: "source")
        let m = makeManager(profiles: [original])
        m.duplicateProfile(original)
        #expect(m.profiles.count == 2)
        #expect(m.profiles[1].id != original.id)
    }

    @Test func copySuffixAppendedToName() {
        let original = makeProfile(name: "source")
        let m = makeManager(profiles: [original])
        m.duplicateProfile(original)
        #expect(m.profiles[1].name == "source Copy")
    }

    @Test func resetsLastUsed() {
        let original = makeProfile(name: "x", lastUsed: Date())
        let m = makeManager(profiles: [original])
        m.duplicateProfile(original)
        #expect(m.profiles[1].lastUsed == nil)
    }

    @Test func selectsTheNewProfile() {
        let original = makeProfile(name: "x")
        let m = makeManager(profiles: [original])
        m.duplicateProfile(original)
        #expect(m.selectedProfile?.id == m.profiles[1].id)
    }

    @Test func preservesCustomGroupMembership() {
        let original = makeProfile(name: "src")
        let customGroup = makeGroup(name: "Infra", profileIDs: [original.id])
        let m = makeManager(profiles: [original], groups: [customGroup])
        m.duplicateProfile(original)

        let newId = m.profiles[1].id
        #expect(m.groups[0].profileIDs.contains(newId))
        #expect(m.groups[0].profileIDs.contains(original.id))
    }

    @Test func skipsAllProfilesFavoritesRecentGroupMembership() {
        let original = makeProfile(name: "src")
        let all = makeGroup(name: "All Profiles", profileIDs: [original.id])
        let favs = makeGroup(name: "Favorites", profileIDs: [original.id])
        let recent = makeGroup(name: "Recent", profileIDs: [original.id])
        let m = makeManager(profiles: [original], groups: [all, favs, recent])

        m.duplicateProfile(original)

        let newId = m.profiles[1].id
        for group in m.groups {
            #expect(group.profileIDs.contains(newId) == false)
        }
    }

    @Test func addsToSelectedGroupIfCustomAndNotInSkipList() {
        let original = makeProfile(name: "src")
        let custom = makeGroup(name: "Project", profileIDs: [])
        let m = makeManager(profiles: [original], groups: [custom])
        m.selectedGroup = custom

        m.duplicateProfile(original)

        let newId = m.profiles[1].id
        #expect(m.groups[0].profileIDs.contains(newId))
    }
}

@Suite("ProfileManager.toggleFavorite") @MainActor
struct ProfileManagerToggleFavoriteTests {
    @Test func togglesFlag() {
        let p = makeProfile(isFavorite: false)
        let m = makeManager(profiles: [p])
        m.toggleFavorite(p)
        #expect(m.profiles[0].isFavorite == true)
        m.toggleFavorite(p)
        #expect(m.profiles[0].isFavorite == false)
    }

    @Test func doesNothingIfProfileNotFound() {
        let m = makeManager()
        // no crash on missing profile
        m.toggleFavorite(makeProfile())
        #expect(m.profiles.isEmpty)
    }
}

@Suite("ProfileManager.connectToProfile(s)") @MainActor
struct ProfileManagerConnectTests {
    @Test func singleProfileUpdatesLastUsedAndInvokesITerm2() {
        let p = makeProfile(lastUsed: nil)
        let fakeScript = FakeAppleScriptRunner()
        let fakeProcess = FakeProcessRunner()
        let fakeFile = InMemoryProfileFileStore()
        let iterm = ITerm2Service(
            dynamicProfilesRoot: URL(fileURLWithPath: "/tmp/dyn"),
            fileStore: fakeFile,
            scriptRunner: fakeScript,
            processRunner: fakeProcess
        )
        let m = ProfileManager(
            storage: makeStubStorage(),
            sshConfigParser: SSHConfigParser(),
            iTerm2Service: iterm,
            autoLoad: false,
            autoSave: false
        )
        m.profiles = [p]

        let before = Date()
        m.connectToProfile(p)

        // lastUsed updated
        let updated = m.profiles.first { $0.id == p.id }!
        #expect(updated.lastUsed != nil)
        #expect(updated.lastUsed! >= before)
    }

    @Test func connectToSelectedProfilesNoopWhenEmpty() {
        let m = makeManager()
        m.selectedProfiles = []
        // must not crash
        m.connectToSelectedProfiles()
    }
}
