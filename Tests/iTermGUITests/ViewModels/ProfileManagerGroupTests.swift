import Foundation
import Testing
@testable import iTermGUI

@MainActor
private func makeManager(profiles: [SSHProfile] = [], groups: [ProfileGroup] = []) -> ProfileManager {
    let m = ProfileManager(
        storage: makeStubStorage(),
        sshConfigParser: SSHConfigParser(),
        iTerm2Service: makeStubITerm2Service(),
        autoLoad: false,
        autoSave: false
    )
    m.profiles = profiles
    m.groups = groups
    return m
}

@Suite("ProfileManager.addProfileToGroup") @MainActor
struct ProfileManagerAddToGroupTests {
    @Test func insertsProfileIntoSpecifiedGroup() {
        let p = makeProfile()
        let g = makeGroup(name: "Work")
        let m = makeManager(profiles: [p], groups: [g])

        m.addProfileToGroup(p, group: g)

        #expect(m.groups[0].profileIDs.contains(p.id))
    }

    @Test func isIdempotent() {
        let p = makeProfile()
        let g = makeGroup(name: "Work", profileIDs: [p.id])
        let m = makeManager(profiles: [p], groups: [g])

        m.addProfileToGroup(p, group: g)
        m.addProfileToGroup(p, group: g)

        #expect(m.groups[0].profileIDs.count == 1)
    }

    @Test func doesNothingForUnknownGroup() {
        let p = makeProfile()
        let existingGroup = makeGroup(name: "Work")
        let strangerGroup = makeGroup(name: "Stranger")
        let m = makeManager(profiles: [p], groups: [existingGroup])

        m.addProfileToGroup(p, group: strangerGroup)

        #expect(m.groups[0].profileIDs.isEmpty)
    }
}

@Suite("ProfileManager.removeProfileFromGroup") @MainActor
struct ProfileManagerRemoveFromGroupTests {
    @Test func removesProfileFromSpecifiedGroup() {
        let p = makeProfile()
        let g = makeGroup(name: "Work", profileIDs: [p.id])
        let m = makeManager(profiles: [p], groups: [g])

        m.removeProfileFromGroup(p, group: g)

        #expect(m.groups[0].profileIDs.isEmpty)
    }

    @Test func isIdempotent() {
        let p = makeProfile()
        let g = makeGroup(name: "Work")
        let m = makeManager(profiles: [p], groups: [g])

        m.removeProfileFromGroup(p, group: g)
        m.removeProfileFromGroup(p, group: g)

        #expect(m.groups[0].profileIDs.isEmpty)
    }

    @Test func onlyRemovesFromMatchingGroup() {
        let p = makeProfile()
        let work = makeGroup(name: "Work", profileIDs: [p.id])
        let personal = makeGroup(name: "Personal", profileIDs: [p.id])
        let m = makeManager(profiles: [p], groups: [work, personal])

        m.removeProfileFromGroup(p, group: work)

        #expect(m.groups[0].profileIDs.contains(p.id) == false)
        #expect(m.groups[1].profileIDs.contains(p.id))
    }
}

@Suite("ProfileManager delete cascades to groups") @MainActor
struct ProfileManagerDeleteCascadeTests {
    @Test func deletingProfileScrubsItFromEveryGroup() {
        let p = makeProfile()
        let work = makeGroup(name: "Work", profileIDs: [p.id, UUID()])
        let personal = makeGroup(name: "Personal", profileIDs: [p.id])
        let all = makeGroup(name: "All Profiles", profileIDs: [p.id])
        let m = makeManager(profiles: [p], groups: [work, personal, all])

        m.deleteProfile(p)

        for group in m.groups {
            #expect(group.profileIDs.contains(p.id) == false)
        }
    }
}
