import XCTest
@testable import ClaraCoreMobile

final class AppDatabaseTests: XCTestCase {
    func testPreparedDatabaseDirectoryIsExcludedFromBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("claracore-database-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try AppDatabase.prepareDatabaseDirectory(directory)

        var values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testDeleteAllLocalUserDataClearsUserTables() throws {
        let database = try AppDatabase(path: ":memory:")
        let capture = RawCapture(source: .manual, rawContent: "A long source conversation to archive.")
        let inboxStore = InboxStore(database: database)
        let importSessionStore = ImportSessionStore(database: database)
        let memoriaStore = MemoriaStore(database: database)
        let continuityStore = ContinuityStore(database: database)
        let contextCardStore = ContextCardStore(database: database)

        _ = try inboxStore.enqueue(capture)
        let session = try importSessionStore.create(from: capture, title: "Imported conversation")
        try importSessionStore.addSegments([
            CaptureSegment(
                sessionId: session.id,
                sequence: 0,
                content: capture.rawContent,
                characterRange: 0..<capture.rawContent.count
            )
        ])
        _ = try memoriaStore.store(content: "Remember this", tags: ["test"], isPrivate: false)
        _ = try continuityStore.create(title: "Line", lastPosition: "Continue here", nextStep: "Next")
        _ = try contextCardStore.create(title: "Custom card", agentProfile: "Agent", userProfile: "User")

        try database.deleteAllLocalUserData()

        XCTAssertTrue(try inboxStore.pending().isEmpty)
        XCTAssertTrue(try importSessionStore.archive().isEmpty)
        XCTAssertTrue(try memoriaStore.recent().isEmpty)
        XCTAssertTrue(try continuityStore.active().isEmpty)
        XCTAssertTrue(try contextCardStore.list().isEmpty)
    }

    func testDeleteDatabaseDirectoryRemovesLocalStorageDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("claracore-reset-\(UUID().uuidString)", isDirectory: true)
        try AppDatabase.prepareDatabaseDirectory(directory)
        try "database".write(
            to: directory.appendingPathComponent("claracore.sqlite"),
            atomically: true,
            encoding: .utf8
        )

        try AppDatabase.deleteDatabaseDirectory(directory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testScreenshotFixtureSeederOnlyRunsWhenRequested() throws {
        let defaults = try makeIsolatedDefaults()
        let dependencies = try AppDependencies.live(
            apiKeyStore: TestScreenshotAPIKeyStore(),
            userDefaults: defaults,
            databasePath: ":memory:"
        )

        try AppStoreScreenshotFixtureSeeder.seedIfRequested(
            dependencies: dependencies,
            environment: [:]
        )

        XCTAssertTrue(try dependencies.importSessionStore.archive().isEmpty)
        XCTAssertTrue(try dependencies.memoriaStore.recent().isEmpty)
        XCTAssertTrue(try dependencies.continuityStore.active().isEmpty)
        XCTAssertEqual(OrganizationEngineModeStore.load(userDefaults: defaults), .localRules)
    }

    func testScreenshotFixtureSeederMapsRequestedInitialTabs() {
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(environment: [:]),
            .importer
        )
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(
                environment: [
                    AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "import-result"
                ]
            ),
            .importer
        )
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(
                environment: [
                    AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "archive"
                ]
            ),
            .archive
        )
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(
                environment: [
                    AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "memory"
                ]
            ),
            .memoria
        )
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(
                environment: [
                    AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "shared-line"
                ]
            ),
            .continuity
        )
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.target(
                environment: [
                    AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "recall-package"
                ]
            ),
            .recallPackage
        )
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(
                environment: [
                    AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "settings"
                ]
            ),
            .settings
        )
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(
                environment: [
                    AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "settings-support"
                ]
            ),
            .settings
        )
    }

    func testScreenshotFixtureSeederIgnoresTabWhenScreenshotModeIsOff() {
        XCTAssertEqual(
            AppStoreScreenshotFixtureSeeder.initialTab(
                environment: [
                    AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "archive"
                ]
            ),
            .importer
        )
    }

    func testScreenshotFixtureSeederCreatesIdempotentSafeSampleData() throws {
        let defaults = try makeIsolatedDefaults()
        let keyStore = TestScreenshotAPIKeyStore()
        let dependencies = try AppDependencies.live(
            apiKeyStore: keyStore,
            userDefaults: defaults,
            databasePath: ":memory:"
        )

        try AppStoreScreenshotFixtureSeeder.seedIfRequested(
            dependencies: dependencies,
            environment: [
                AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "archive"
            ]
        )
        try AppStoreScreenshotFixtureSeeder.seedIfRequested(
            dependencies: dependencies,
            environment: [
                AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "archive"
            ]
        )

        let archive = try dependencies.importSessionStore.archive()
        let memories = try dependencies.memoriaStore.recent()
        let lines = try dependencies.continuityStore.active()

        XCTAssertEqual(archive.count, 1)
        XCTAssertEqual(memories.count, 2)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(archive.first?.session.sourceApp, "DeepSeek")
        XCTAssertEqual(lines.first?.title, "ClaraCore 上架准备共同线")
        XCTAssertTrue(memories.allSatisfy { $0.tags.contains("screenshot-sample") })
        XCTAssertFalse(archive.first?.rawContent.localizedCaseInsensitiveContains("sk-") ?? true)
        XCTAssertFalse(archive.first?.rawContent.localizedCaseInsensitiveContains("api key") ?? true)
        XCTAssertEqual(OrganizationEngineModeStore.load(userDefaults: defaults), .externalModel)
        XCTAssertTrue(ExternalModelProcessingConsentStore.isAccepted(userDefaults: defaults))
        XCTAssertEqual(ModelProviderConfigurationStore.load(userDefaults: defaults).providerName, "示例 OpenAI-compatible")
        XCTAssertEqual(ModelProviderConfigurationStore.load(userDefaults: defaults).baseURLString, "https://api.example.com/v1")
        XCTAssertEqual(ModelProviderConfigurationStore.load(userDefaults: defaults).model, "context-organizer-demo")
        XCTAssertNil(try keyStore.read(service: .modelProvider))
    }

    func testScreenshotFixtureSeederKeepsImportTargetCleanForFirstScreenshot() throws {
        let defaults = try makeIsolatedDefaults()
        let dependencies = try AppDependencies.live(
            apiKeyStore: TestScreenshotAPIKeyStore(),
            userDefaults: defaults,
            databasePath: ":memory:"
        )

        try AppStoreScreenshotFixtureSeeder.seedIfRequested(
            dependencies: dependencies,
            environment: [
                AppStoreScreenshotFixtureSeeder.environmentKey: "1",
                AppStoreScreenshotFixtureSeeder.tabEnvironmentKey: "import"
            ]
        )

        XCTAssertTrue(try dependencies.importSessionStore.archive().isEmpty)
        XCTAssertTrue(try dependencies.memoriaStore.recent().isEmpty)
        XCTAssertTrue(try dependencies.continuityStore.active().isEmpty)
        XCTAssertEqual(OrganizationEngineModeStore.load(userDefaults: defaults), .externalModel)
        XCTAssertTrue(ExternalModelProcessingConsentStore.isAccepted(userDefaults: defaults))
        XCTAssertEqual(ModelProviderConfigurationStore.load(userDefaults: defaults).model, "context-organizer-demo")
    }

    private func makeIsolatedDefaults() throws -> UserDefaults {
        let suiteName = "screenshot-fixture-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class TestScreenshotAPIKeyStore: APIKeyStore {
    func read(service: APIKeyService) throws -> String? { nil }
    func save(_ value: String, service: APIKeyService) throws {}
    func delete(service: APIKeyService) throws {}
}
