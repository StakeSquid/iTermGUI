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
    m.groups = groups.isEmpty ? ProfileGroup.defaultGroups : groups
    return m
}

@Suite("ProfileManager.filteredProfiles search") @MainActor
struct ProfileManagerSearchTests {
    @Test func emptySearchReturnsAll() {
        let m = makeManager(profiles: [
            makeProfile(name: "a", host: "h1"),
            makeProfile(name: "b", host: "h2")
        ])
        #expect(m.filteredProfiles.count == 2)
    }

    @Test func searchMatchesName() {
        let m = makeManager(profiles: [
            makeProfile(name: "production"),
            makeProfile(name: "staging")
        ])
        m.searchText = "prod"
        #expect(m.filteredProfiles.map(\.name) == ["production"])
    }

    @Test func searchMatchesHost() {
        let m = makeManager(profiles: [
            makeProfile(name: "a", host: "api.example.com"),
            makeProfile(name: "b", host: "www.example.com")
        ])
        m.searchText = "api"
        #expect(m.filteredProfiles.map(\.host) == ["api.example.com"])
    }

    @Test func searchMatchesUsername() {
        let m = makeManager(profiles: [
            makeProfile(name: "a", username: "deploy"),
            makeProfile(name: "b", username: "admin")
        ])
        m.searchText = "deploy"
        #expect(m.filteredProfiles.map(\.name) == ["a"])
    }

    @Test func searchMatchesTags() {
        let m = makeManager(profiles: [
            makeProfile(name: "a", tags: ["prod", "critical"]),
            makeProfile(name: "b", tags: ["dev"])
        ])
        m.searchText = "critical"
        #expect(m.filteredProfiles.map(\.name) == ["a"])
    }

    @Test func searchIsCaseInsensitive() {
        let m = makeManager(profiles: [makeProfile(name: "Production")])
        m.searchText = "production"
        #expect(m.filteredProfiles.count == 1)

        m.searchText = "PRODUCTION"
        #expect(m.filteredProfiles.count == 1)
    }
}

@Suite("ProfileManager.filteredProfiles group filtering") @MainActor
struct ProfileManagerGroupFilterTests {
    @Test func allProfilesGroupReturnsAll() {
        let all = makeGroup(name: "All Profiles")
        let m = makeManager(profiles: [
            makeProfile(name: "a"),
            makeProfile(name: "b")
        ], groups: [all])
        m.selectedGroup = all
        #expect(m.filteredProfiles.count == 2)
    }

    @Test func favoritesGroupFiltersFavorites() {
        let favs = makeGroup(name: "Favorites")
        let fav = makeProfile(name: "a", isFavorite: true)
        let nonFav = makeProfile(name: "b", isFavorite: false)
        let m = makeManager(profiles: [fav, nonFav], groups: [favs])
        m.selectedGroup = favs
        #expect(m.filteredProfiles.map(\.name) == ["a"])
    }

    @Test func recentGroupExcludesNilLastUsed() {
        let recent = makeGroup(name: "Recent")
        let used = makeProfile(name: "used", lastUsed: Date())
        let never = makeProfile(name: "never", lastUsed: nil)
        let m = makeManager(profiles: [used, never], groups: [recent])
        m.selectedGroup = recent
        #expect(m.filteredProfiles.map(\.name) == ["used"])
    }

    @Test func recentGroupTopsOutAtTen() {
        let recent = makeGroup(name: "Recent")
        var profiles: [SSHProfile] = []
        for i in 0..<15 {
            profiles.append(makeProfile(
                name: "p\(i)",
                lastUsed: Date(timeIntervalSince1970: TimeInterval(i * 1000))
            ))
        }
        let m = makeManager(profiles: profiles, groups: [recent])
        m.selectedGroup = recent
        #expect(m.filteredProfiles.count == 10)
    }

    @Test func recentGroupSortsByLastUsedDescending() {
        let recent = makeGroup(name: "Recent")
        let oldest = makeProfile(name: "oldest", lastUsed: Date(timeIntervalSince1970: 100))
        let newest = makeProfile(name: "newest", lastUsed: Date(timeIntervalSince1970: 1000))
        let m = makeManager(profiles: [oldest, newest], groups: [recent])
        m.selectedGroup = recent
        #expect(m.filteredProfiles.map(\.name) == ["newest", "oldest"])
    }

    @Test func customGroupFiltersByProfileIDs() {
        let p1 = makeProfile(name: "a")
        let p2 = makeProfile(name: "b")
        let p3 = makeProfile(name: "c")
        let custom = makeGroup(name: "Mine", profileIDs: [p1.id, p3.id])
        let m = makeManager(profiles: [p1, p2, p3], groups: [custom])
        m.selectedGroup = custom
        #expect(Set(m.filteredProfiles.map(\.name)) == ["a", "c"])
    }

    @Test func nilGroupReturnsAllFilteredAndSorted() {
        let m = makeManager(profiles: [
            makeProfile(name: "b"),
            makeProfile(name: "a")
        ])
        m.selectedGroup = nil
        // Default sort is by name ascending
        #expect(m.filteredProfiles.map(\.name) == ["a", "b"])
    }
}

@Suite("ProfileManager.sortProfiles") @MainActor
struct ProfileManagerSortTests {
    @Test func nameSortAscending() {
        let m = makeManager()
        m.sortOption = .name
        m.sortAscending = true
        let sorted = m.sortProfiles([
            makeProfile(name: "charlie"),
            makeProfile(name: "alpha"),
            makeProfile(name: "BRAVO")
        ])
        #expect(sorted.map(\.name) == ["alpha", "BRAVO", "charlie"])
    }

    @Test func nameSortDescending() {
        let m = makeManager()
        m.sortOption = .name
        m.sortAscending = false
        let sorted = m.sortProfiles([
            makeProfile(name: "a"),
            makeProfile(name: "b"),
            makeProfile(name: "c")
        ])
        #expect(sorted.map(\.name) == ["c", "b", "a"])
    }

    @Test func hostSortAscendingCaseInsensitive() {
        let m = makeManager()
        m.sortOption = .host
        m.sortAscending = true
        let sorted = m.sortProfiles([
            makeProfile(host: "Charlie.example.com"),
            makeProfile(host: "alpha.example.com"),
            makeProfile(host: "bravo.example.com")
        ])
        #expect(sorted.map(\.host).first == "alpha.example.com")
    }

    @Test func lastUsedSortNilTreatedAsDistantPast() {
        let m = makeManager()
        m.sortOption = .lastUsed
        m.sortAscending = false
        let oldest = makeProfile(name: "oldest", lastUsed: Date(timeIntervalSince1970: 10))
        let newest = makeProfile(name: "newest", lastUsed: Date(timeIntervalSince1970: 1000))
        let never = makeProfile(name: "never", lastUsed: nil)
        let sorted = m.sortProfiles([oldest, newest, never])
        // Descending: newest first, then oldest, then never
        #expect(sorted.map(\.name) == ["newest", "oldest", "never"])
    }

    @Test func createdAtSortAscending() {
        let m = makeManager()
        m.sortOption = .createdAt
        m.sortAscending = true
        let early = makeProfile(name: "early", createdAt: Date(timeIntervalSince1970: 100))
        let mid = makeProfile(name: "mid", createdAt: Date(timeIntervalSince1970: 500))
        let late = makeProfile(name: "late", createdAt: Date(timeIntervalSince1970: 1000))
        let sorted = m.sortProfiles([late, early, mid])
        #expect(sorted.map(\.name) == ["early", "mid", "late"])
    }

    @Test func favoriteSortPutsFavoritesFirstWithNameTieBreaker() {
        let m = makeManager()
        m.sortOption = .favorite
        m.sortAscending = true
        let favA = makeProfile(name: "z-fav", isFavorite: true)
        let favB = makeProfile(name: "a-fav", isFavorite: true)
        let regular = makeProfile(name: "regular", isFavorite: false)
        let sorted = m.sortProfiles([regular, favA, favB])
        #expect(sorted[0].name == "a-fav")
        #expect(sorted[1].name == "z-fav")
        #expect(sorted[2].name == "regular")
    }
}
