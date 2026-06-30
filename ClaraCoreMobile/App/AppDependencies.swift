import Foundation

struct AppDependencies {
    let database: AppDatabase
    let contextCardStore: ContextCardStore
    let memoriaStore: MemoriaStore
    let continuityStore: ContinuityStore
    let inboxStore: InboxStore
    let importSessionStore: ImportSessionStore
    let segmenter: CaptureSegmenting
    let importSessionPreparer: ImportSessionPreparer
    let deepSeekShareImporter: DeepSeekShareImporter
    let conversationImporterRegistry: ConversationImporterRegistry
    let reflectionService: ReflectionService
    let reflectionRunner: ReflectionRunner
    let digestCommitter: DigestCommitter
    let apiKeyStore: APIKeyStore
    let reflectionConfiguration: ReflectionConfiguration

    static func live(apiKeyStore: APIKeyStore = KeychainAPIKeyStore()) throws -> AppDependencies {
        let database = try AppDatabase()
        let contextCardStore = ContextCardStore(database: database)
        _ = try contextCardStore.defaultCard()
        let memoriaStore = MemoriaStore(database: database)
        let continuityStore = ContinuityStore(database: database)
        let inboxStore = InboxStore(database: database)
        let importSessionStore = ImportSessionStore(database: database)
        let segmenter = FixedSizeCaptureSegmenter()
        let deepSeekAPIKey = try? apiKeyStore.read(service: .deepSeek)
        let reflectionService: ReflectionService
        let reflectionConfiguration: ReflectionConfiguration
        if let deepSeekAPIKey, !deepSeekAPIKey.isEmpty {
            reflectionService = DeepSeekReflectionService(apiKey: deepSeekAPIKey)
            reflectionConfiguration = ReflectionConfiguration(mode: .deepSeek)
        } else {
            reflectionService = RuleBasedReflectionService()
            reflectionConfiguration = ReflectionConfiguration(mode: .localPlaceholder)
        }
        let deepSeekShareImporter = DeepSeekShareImporter()
        return AppDependencies(
            database: database,
            contextCardStore: contextCardStore,
            memoriaStore: memoriaStore,
            continuityStore: continuityStore,
            inboxStore: inboxStore,
            importSessionStore: importSessionStore,
            segmenter: segmenter,
            importSessionPreparer: ImportSessionPreparer(
                inboxStore: inboxStore,
                sessionStore: importSessionStore,
                segmenter: segmenter
            ),
            deepSeekShareImporter: deepSeekShareImporter,
            conversationImporterRegistry: ConversationImporterRegistry.live(deepSeekImporter: deepSeekShareImporter),
            reflectionService: reflectionService,
            reflectionRunner: ReflectionRunner(
                sessionStore: importSessionStore,
                reflectionService: reflectionService
            ),
            digestCommitter: DigestCommitter(
                memoriaStore: memoriaStore,
                continuityStore: continuityStore
            ),
            apiKeyStore: apiKeyStore,
            reflectionConfiguration: reflectionConfiguration
        )
    }
}
