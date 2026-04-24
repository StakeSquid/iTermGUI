import Foundation
import Testing
@testable import iTermGUI

@Suite("SSHConfigParser.parseConfigContent")
struct SSHConfigParserContentTests {
    private func parser(user: String = "ci-user") -> SSHConfigParser {
        SSHConfigParser(userNameProvider: { user })
    }

    @Test func parsesSimpleConfig() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.simpleConfig)
        #expect(profiles.count == 1)
        let p = profiles[0]
        #expect(p.name == "example")
        #expect(p.host == "example.com")
        #expect(p.username == "alex")
        #expect(p.port == 2222)
        #expect(p.privateKeyPath?.hasSuffix("/.ssh/id_rsa") == true)
        #expect(p.authMethod == .publicKey)
    }

    @Test func skipsWildcardHost() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.wildcardConfig)
        #expect(profiles.count == 1)
        #expect(profiles[0].name == "real-host")
    }

    @Test func usesUserNameProviderWhenUserAbsent() {
        let input = """
        Host no-user
            HostName no-user.example.com
        """
        let profiles = parser(user: "injected-user").parseConfigContent(input)
        #expect(profiles[0].username == "injected-user")
    }

    @Test func usesHostAliasWhenHostNameAbsent() {
        let input = "Host bare-alias"
        let profiles = parser().parseConfigContent(input)
        #expect(profiles.count == 1)
        #expect(profiles[0].host == "bare-alias")
    }

    @Test func emptyInputReturnsEmpty() {
        #expect(parser().parseConfigContent(SSHConfigFixtures.emptyConfig).isEmpty)
    }

    @Test func commentsOnlyReturnsEmpty() {
        #expect(parser().parseConfigContent(SSHConfigFixtures.commentsOnlyConfig).isEmpty)
    }

    @Test func invalidPortFallsBackToDefaults() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.invalidPortConfig)
        #expect(profiles.count == 1)
        #expect(profiles[0].port == 22)
        #expect(profiles[0].connectionTimeout == 30)
    }

    @Test func booleanFieldsAreCaseInsensitive() {
        let input = """
        Host flexible
            HostName h
            Compression YES
            StrictHostKeyChecking NO
        """
        let profiles = parser().parseConfigContent(input)
        #expect(profiles[0].compression == true)
        #expect(profiles[0].strictHostKeyChecking == false)
    }

    @Test func strictHostKeyCheckingDefaultsToTrueWhenAbsent() {
        let input = """
        Host default-strict
            HostName h
        """
        let profiles = parser().parseConfigContent(input)
        #expect(profiles[0].strictHostKeyChecking == true)
    }

    @Test func multiHostConfigParsesEachBlock() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.multiHostConfig)
        #expect(profiles.count == 3)
        #expect(profiles.map(\.name) == ["a", "b", "c"])
        #expect(profiles[0].compression)
        #expect(profiles[1].strictHostKeyChecking == false)
        #expect(profiles[2].jumpHost == "jump.example.com")
        #expect(profiles[2].proxyCommand?.hasPrefix("nc -X connect") == true)
    }

    @Test func spaceSeparatedLocalForwardParses() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.portForwardConfig)
        #expect(profiles.count == 1)
        let fwd = profiles[0].localForwards[0]
        #expect(fwd.localPort == 8080)
        #expect(fwd.remoteHost == "localhost")
        #expect(fwd.remotePort == 80)
    }

    @Test func colonSeparatedLocalForwardParses() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.colonForwardConfig)
        let fwd = profiles[0].localForwards[0]
        #expect(fwd.localPort == 8080)
        #expect(fwd.remoteHost == "localhost")
        #expect(fwd.remotePort == 80)
    }

    @Test func malformedPortForwardIsIgnored() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.malformedForwardConfig)
        #expect(profiles[0].localForwards.isEmpty)
    }

    @Test func identityFilePresenceSetsPublicKeyAuth() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.bothKeysConfig)
        #expect(profiles[0].authMethod == .publicKey)
        #expect(profiles[0].identityFile?.hasSuffix("/.ssh/custom_id") == true)
    }

    @Test func identityFileAbsenceSetsPasswordAuth() {
        let input = """
        Host passworded
            HostName h
        """
        let profiles = parser().parseConfigContent(input)
        #expect(profiles[0].authMethod == .password)
    }

    @Test func remoteForwardParses() {
        let profiles = parser().parseConfigContent(SSHConfigFixtures.portForwardConfig)
        let rfwd = profiles[0].remoteForwards[0]
        #expect(rfwd.localPort == 9090)
        #expect(rfwd.remoteHost == "internal")
        #expect(rfwd.remotePort == 9090)
    }
}

@Suite("SSHConfigParser.createProfile")
struct SSHConfigParserCreateProfileTests {
    private func parser(user: String = "u") -> SSHConfigParser {
        SSHConfigParser(userNameProvider: { user })
    }

    @Test func wildcardHostReturnsNil() {
        #expect(parser().createProfile(from: "*", config: [:]) == nil)
        #expect(parser().createProfile(from: "foo*bar", config: [:]) == nil)
    }

    @Test func validPortParses() {
        let p = parser().createProfile(from: "x", config: ["port": "8022"])
        #expect(p?.port == 8022)
    }

    @Test func invalidPortFallsBack() {
        let p = parser().createProfile(from: "x", config: ["port": "abc"])
        #expect(p?.port == 22)
    }
}

@Suite("SSHConfigParser.parsePortForward")
struct SSHConfigParserPortForwardTests {
    private let parser = SSHConfigParser()

    @Test func spaceSeparated() {
        let pf = parser.parsePortForward("8080 host 80", isLocal: true)
        #expect(pf?.localPort == 8080)
        #expect(pf?.remoteHost == "host")
        #expect(pf?.remotePort == 80)
    }

    @Test func colonSeparated() {
        let pf = parser.parsePortForward("8080:host:80", isLocal: true)
        #expect(pf?.localPort == 8080)
        #expect(pf?.remoteHost == "host")
        #expect(pf?.remotePort == 80)
    }

    @Test func mixedSeparators() {
        let pf = parser.parsePortForward("8080 host:80", isLocal: true)
        #expect(pf?.localPort == 8080)
    }

    @Test func fewerThanThreePartsReturnsNil() {
        #expect(parser.parsePortForward("8080", isLocal: true) == nil)
        #expect(parser.parsePortForward("8080 host", isLocal: true) == nil)
        #expect(parser.parsePortForward("", isLocal: true) == nil)
    }

    @Test func malformedIntsFallBackToZero() {
        let pf = parser.parsePortForward("abc host xyz", isLocal: true)
        #expect(pf?.localPort == 0)
        #expect(pf?.remoteHost == "host")
        #expect(pf?.remotePort == 0)
    }
}

@Suite("String.expandingTildeInPath")
struct StringTildeExpansionTests {
    @Test func tildeSlashExpandsToHomeDirectory() {
        let expanded = "~/.ssh/id_rsa".expandingTildeInPath()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(expanded == "\(home)/.ssh/id_rsa")
    }

    @Test func loneTildeIsNotExpanded() {
        #expect("~".expandingTildeInPath() == "~")
    }

    @Test func pathWithoutTildeUnchanged() {
        #expect("/absolute/path".expandingTildeInPath() == "/absolute/path")
    }

    @Test func tildeUsernameNotExpanded() {
        #expect("~alex/docs".expandingTildeInPath() == "~alex/docs")
    }

    @Test func emptyStringUnchanged() {
        #expect("".expandingTildeInPath() == "")
    }
}

@Suite("SSHConfigParser.parseConfigFile via injected file store")
struct SSHConfigParserFileStoreTests {
    @Test func readsFromInjectedStore() async throws {
        let store = InMemoryProfileFileStore()
        let url = URL(fileURLWithPath: "/fake/.ssh/config")
        store.seed(url, withString: SSHConfigFixtures.simpleConfig)

        let parser = SSHConfigParser(
            userNameProvider: { "u" },
            fileStore: store
        )
        let profiles = try await parser.parseConfigFile(at: url)
        #expect(profiles.count == 1)
        #expect(profiles[0].name == "example")
    }

    @Test func throwsWhenFileAbsent() async {
        let store = InMemoryProfileFileStore()
        let parser = SSHConfigParser(fileStore: store)
        do {
            _ = try await parser.parseConfigFile(at: URL(fileURLWithPath: "/nope"))
            Issue.record("expected error")
        } catch {
            // expected
        }
    }
}
