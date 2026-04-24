import Foundation
@testable import iTermGUI

func makeProfile(
    id: UUID = UUID(),
    name: String = "test",
    host: String = "example.com",
    port: Int = 22,
    username: String = "alex",
    authMethod: AuthMethod = .publicKey,
    privateKeyPath: String? = nil,
    password: String? = nil,
    tags: Set<String> = [],
    jumpHost: String? = nil,
    localForwards: [PortForward] = [],
    remoteForwards: [PortForward] = [],
    proxyCommand: String? = nil,
    identityFile: String? = nil,
    strictHostKeyChecking: Bool = true,
    compression: Bool = false,
    connectionTimeout: Int = 30,
    serverAliveInterval: Int = 60,
    isFavorite: Bool = false,
    customCommands: [String] = [],
    terminalSettings: TerminalSettings = TerminalSettings(),
    embeddedTerminalSettings: EmbeddedTerminalSettings? = nil,
    lastUsed: Date? = nil,
    createdAt: Date = Date(),
    modifiedAt: Date = Date()
) -> SSHProfile {
    SSHProfile(
        id: id,
        name: name,
        host: host,
        port: port,
        username: username,
        authMethod: authMethod,
        privateKeyPath: privateKeyPath,
        password: password,
        tags: tags,
        jumpHost: jumpHost,
        localForwards: localForwards,
        remoteForwards: remoteForwards,
        proxyCommand: proxyCommand,
        identityFile: identityFile,
        strictHostKeyChecking: strictHostKeyChecking,
        compression: compression,
        connectionTimeout: connectionTimeout,
        serverAliveInterval: serverAliveInterval,
        isFavorite: isFavorite,
        customCommands: customCommands,
        terminalSettings: terminalSettings,
        embeddedTerminalSettings: embeddedTerminalSettings,
        lastUsed: lastUsed,
        createdAt: createdAt,
        modifiedAt: modifiedAt
    )
}

func makeGroup(
    id: UUID = UUID(),
    name: String = "Test Group",
    icon: String = "folder",
    color: String = "blue",
    profileIDs: Set<UUID> = [],
    isExpanded: Bool = true,
    sortOrder: Int = 0
) -> ProfileGroup {
    ProfileGroup(
        id: id,
        name: name,
        icon: icon,
        color: color,
        profileIDs: profileIDs,
        isExpanded: isExpanded,
        sortOrder: sortOrder
    )
}

func makeGlobalDefaults(
    terminalSettings: TerminalSettings = TerminalSettings(),
    embeddedTerminalSettings: EmbeddedTerminalSettings = EmbeddedTerminalSettings(),
    customCommands: [String] = [],
    connectionTimeout: Int = 30,
    serverAliveInterval: Int = 60,
    strictHostKeyChecking: Bool = true,
    compression: Bool = false
) -> GlobalDefaults {
    GlobalDefaults(
        terminalSettings: terminalSettings,
        embeddedTerminalSettings: embeddedTerminalSettings,
        customCommands: customCommands,
        connectionTimeout: connectionTimeout,
        serverAliveInterval: serverAliveInterval,
        strictHostKeyChecking: strictHostKeyChecking,
        compression: compression
    )
}

func makeStubStorage(
    fileStore: ProfileFileStore? = nil,
    keychain: KeychainStore? = nil,
    rootDirectory: URL = URL(fileURLWithPath: "/tmp/iTermGUI-tests")
) -> ProfileStorage {
    ProfileStorage(
        rootDirectory: rootDirectory,
        fileStore: fileStore ?? InMemoryProfileFileStore(),
        keychain: keychain ?? InMemoryKeychainStore(),
        keychainService: "com.iTermGUI.tests",
        migrateFromDocuments: false
    )
}

func makeStubITerm2Service(
    scriptRunner: AppleScriptRunner? = nil,
    processRunner: ProcessRunner? = nil,
    fileStore: ProfileFileStore? = nil,
    root: URL = URL(fileURLWithPath: "/tmp/iTermGUI-dyn")
) -> ITerm2Service {
    ITerm2Service(
        dynamicProfilesRoot: root,
        fileStore: fileStore ?? InMemoryProfileFileStore(),
        scriptRunner: scriptRunner ?? FakeAppleScriptRunner(),
        processRunner: processRunner ?? FakeProcessRunner()
    )
}
