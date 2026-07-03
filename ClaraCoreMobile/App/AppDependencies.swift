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
        let organizationEngineMode = OrganizationEngineModeStore.load()
        let modelProviderConfiguration = ModelProviderConfigurationStore.load()
        let modelProviderAPIKey = (try? apiKeyStore.read(service: .modelProvider)) ?? (try? apiKeyStore.read(service: .deepSeek))
        let hasAcceptedExternalModelProcessing = ExternalModelProcessingConsentStore.isAccepted()
        let reflectionService: ReflectionService
        let reflectionConfiguration: ReflectionConfiguration
        if organizationEngineMode == .externalModel,
           hasAcceptedExternalModelProcessing,
           let modelProviderAPIKey,
           !modelProviderAPIKey.isEmpty,
           let baseURL = modelProviderConfiguration.baseURL,
           !modelProviderConfiguration.trimmedModel.isEmpty {
            reflectionService = OpenAICompatibleReflectionService(
                apiKey: modelProviderAPIKey,
                model: modelProviderConfiguration.trimmedModel,
                baseURL: baseURL
            )
            reflectionConfiguration = ReflectionConfiguration(
                mode: .remoteModel,
                preferredEngineMode: organizationEngineMode,
                modelProvider: modelProviderConfiguration.normalized,
                hasSavedModelKey: true,
                hasAcceptedExternalProcessing: hasAcceptedExternalModelProcessing
            )
        } else {
            reflectionService = RuleBasedReflectionService()
            reflectionConfiguration = ReflectionConfiguration(
                mode: .localPlaceholder,
                preferredEngineMode: organizationEngineMode,
                modelProvider: modelProviderConfiguration.normalized,
                hasSavedModelKey: modelProviderAPIKey?.isEmpty == false,
                hasAcceptedExternalProcessing: hasAcceptedExternalModelProcessing
            )
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
