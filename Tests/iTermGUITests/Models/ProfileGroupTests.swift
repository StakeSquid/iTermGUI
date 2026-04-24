import Foundation
import Testing
@testable import iTermGUI

@Suite("ProfileGroup.defaultGroups")
struct ProfileGroupDefaultsTests {
    @Test func returnsExactlySixGroups() {
        #expect(ProfileGroup.defaultGroups.count == 6)
    }

    @Test func groupsAreOrderedBySortOrderAscending() {
        let orders = ProfileGroup.defaultGroups.map(\.sortOrder)
        #expect(orders == [0, 1, 2, 3, 4, 5])
    }

    @Test func firstGroupIsAllProfiles() {
        let first = ProfileGroup.defaultGroups[0]
        #expect(first.name == "All Profiles")
        #expect(first.icon == "square.stack")
        #expect(first.color == "gray")
    }

    @Test func secondGroupIsFavorites() {
        let group = ProfileGroup.defaultGroups[1]
        #expect(group.name == "Favorites")
        #expect(group.icon == "star")
        #expect(group.color == "yellow")
    }

    @Test func thirdGroupIsRecent() {
        let group = ProfileGroup.defaultGroups[2]
        #expect(group.name == "Recent")
        #expect(group.icon == "clock")
        #expect(group.color == "blue")
    }

    @Test func remainingGroupsAreWorkPersonalProjects() {
        let names = ProfileGroup.defaultGroups.dropFirst(3).map(\.name)
        #expect(names == ["Work", "Personal", "Projects"])
    }

    @Test func defaultGroupsHaveEmptyProfileIDs() {
        for group in ProfileGroup.defaultGroups {
            #expect(group.profileIDs.isEmpty)
        }
    }

    @Test func defaultGroupsAreAllExpanded() {
        for group in ProfileGroup.defaultGroups {
            #expect(group.isExpanded)
        }
    }
}

@Suite("ProfileGroup init defaults")
struct ProfileGroupInitTests {
    @Test func iconDefaultsToFolder() {
        #expect(ProfileGroup(name: "X").icon == "folder")
    }

    @Test func colorDefaultsToBlue() {
        #expect(ProfileGroup(name: "X").color == "blue")
    }

    @Test func profileIDsDefaultsToEmpty() {
        #expect(ProfileGroup(name: "X").profileIDs.isEmpty)
    }

    @Test func isExpandedDefaultsToTrue() {
        #expect(ProfileGroup(name: "X").isExpanded)
    }

    @Test func sortOrderDefaultsToZero() {
        #expect(ProfileGroup(name: "X").sortOrder == 0)
    }
}

@Suite("ProfileGroup Codable round-trip")
struct ProfileGroupCodableTests {
    @Test func roundTripPreservesAllFields() throws {
        let ids: Set<UUID> = [UUID(), UUID(), UUID()]
        let original = ProfileGroup(
            id: UUID(),
            name: "Infra",
            icon: "server.rack",
            color: "red",
            profileIDs: ids,
            isExpanded: false,
            sortOrder: 7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProfileGroup.self, from: data)
        #expect(decoded == original)
        #expect(decoded.profileIDs == ids)
    }
}

@Suite("ProfileGroup Hashable")
struct ProfileGroupHashableTests {
    @Test func sameIdAndFieldsAreEqual() {
        let id = UUID()
        let a = ProfileGroup(id: id, name: "A")
        let b = ProfileGroup(id: id, name: "A")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func differentIdsProduceNotEqual() {
        let a = ProfileGroup(id: UUID(), name: "X")
        let b = ProfileGroup(id: UUID(), name: "X")
        #expect(a != b)
    }
}
