import XCTest
@testable import ClaraCoreMobile

final class ClaraErrorPresenterTests: XCTestCase {
    func testPresentsModelProviderMissingKeyError() {
        let message = ClaraErrorPresenter.message(for: OpenAICompatibleReflectionService.ServiceError.missingAPIKey)

        XCTAssertEqual(message, "默认整理模型 API Key 未配置。请先在设置里保存 Key。")
    }

    func testPresentsModelProviderUnauthorizedError() {
        let message = ClaraErrorPresenter.message(for: OpenAICompatibleReflectionService.ServiceError.httpStatus(401, ""))

        XCTAssertEqual(message, "默认整理模型 Key 无效或没有权限。请检查 Key 后重试。")
    }

    func testPresentsKeychainAccessErrorsWithoutInternalStatusCodes() {
        let message = ClaraErrorPresenter.message(for: KeychainAPIKeyStore.StoreError.unexpectedStatus(-34018))

        XCTAssertEqual(message, "无法访问本机 Keychain。请确认设备未受限制，稍后重试；如果问题持续，可以删除模型 Key 后重新保存。")
        XCTAssertFalse(message.contains("-34018"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("osstatus"))
    }

    func testPresentsInvalidKeychainDataRecovery() {
        let message = ClaraErrorPresenter.message(for: KeychainAPIKeyStore.StoreError.invalidData)

        XCTAssertEqual(message, "本机 Keychain 中的模型 Key 数据无法读取。请删除模型 Key 后重新保存。")
    }

    func testPresentsNetworkOfflineError() {
        let message = ClaraErrorPresenter.message(for: URLError(.notConnectedToInternet))

        XCTAssertEqual(message, "网络不可用。请检查网络连接后重试。")
    }

    func testPresentsUnsupportedFileImportError() {
        let message = ClaraErrorPresenter.message(for: FileConversationImporter.ImportError.unsupportedFile)

        XCTAssertEqual(message, "暂时只支持导入 .txt 文本文件。")
    }

    func testPresentsPrivateShareImportError() {
        let message = ClaraErrorPresenter.message(for: GenericURLConversationImporter.ImportError.privateOrUnauthorized)

        XCTAssertEqual(message, "这个分享链接需要登录或未公开。请确认它是公开分享链接，或改用复制文本导入。")
    }

    func testPresentsInsecureURLImportError() {
        let message = ClaraErrorPresenter.message(for: ConversationImporterRegistry.RegistryError.insecureURL("example.com"))

        XCTAssertEqual(message, "链接导入只支持 https:// 公开链接。请重新生成 example.com 的 HTTPS 分享链接，或改用复制文本导入。")
    }

    func testPresentsOversizedImportError() {
        let error = RawCapture.ValidationError.oversizedImport(currentCharacters: 240_001, maxCharacters: 240_000)

        XCTAssertEqual(
            ClaraErrorPresenter.message(for: error),
            "这次导入约 240,001 字，超过当前上限 240,000 字。请把原文拆成几次导入，或只粘贴最需要整理的部分。"
        )
    }

    func testPresentsEmptyRawCaptureImportError() {
        let message = ClaraErrorPresenter.message(for: RawCapture.ValidationError.emptyImport)

        XCTAssertEqual(message, "导入内容为空。请粘贴一段对话文本、公开分享链接，或选择包含文字的 .txt 文件。")
    }

    func testPresentsNoSegmentsReflectionRunnerError() {
        let message = ClaraErrorPresenter.message(for: ReflectionRunner.RunnerError.noSegments)

        XCTAssertEqual(message, "没有可整理的内容片段。请重新导入包含文字的对话、公开分享链接或 .txt 文件。")
    }

    func testSupportDiagnosticTextContainsVersionAndNoSensitiveData() {
        let text = AppVersionInfo.supportDiagnosticText(
            info: [
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "7",
                "CFBundleIdentifier": "com.claracore.mobile"
            ],
            deviceName: "iPhone",
            systemName: "iOS",
            systemVersion: "26.5",
            organizationEngineStatus: OrganizationEngineStatus(
                preferredMode: .externalModel,
                effectiveMode: .localPlaceholder,
                hasSavedModelKey: true,
                hasAcceptedExternalProcessing: false,
                modelProvider: ModelProviderConfiguration(
                    providerName: "Private Provider",
                    baseURLString: "https://api.private-provider.example/v1",
                    model: "private-model"
                )
            )
        )

        XCTAssertTrue(text.contains("ClaraCore 0.1.0 (7)"))
        XCTAssertTrue(text.contains("Bundle ID: com.claracore.mobile"))
        XCTAssertTrue(text.contains("Device: iPhone"))
        XCTAssertTrue(text.contains("OS: iOS 26.5"))
        XCTAssertTrue(text.contains("Organization engine preferred mode: 外部模型"))
        XCTAssertTrue(text.contains("Organization engine effective mode: local rules"))
        XCTAssertTrue(text.contains("External model activation complete: no"))
        XCTAssertTrue(text.contains("External model missing requirements: 已确认外部处理说明"))
        XCTAssertTrue(text.contains("does not include API keys"))
        XCTAssertTrue(text.contains("provider names, Base URLs, model names, or model provider configuration"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("bearer "))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("sk-"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("api key:"))
        XCTAssertFalse(text.contains("Private Provider"))
        XCTAssertFalse(text.contains("api.private-provider.example"))
        XCTAssertFalse(text.contains("private-model"))
    }

    func testPresentsInvalidModelProviderBaseURLError() {
        let message = ClaraErrorPresenter.message(for: ModelProviderClient.ClientError.invalidBaseURL)

        XCTAssertEqual(message, "模型 Base URL 无效。请使用完整的 https:// 地址。")
    }

    func testProviderHTTPErrorDetailsAreRedactedAndBounded() {
        let fakeBearer = "secret-token-value-1234567890"
        let fakeKey = "sk-" + "secret-value-1234567890"
        let body = """
        {"error":"bad request",
        "authorization":"Bearer \(fakeBearer)",
        "api_key":"\(fakeKey)",
        "detail":"\(String(repeating: "x", count: 220))"}
        """

        let modelListMessage = ClaraErrorPresenter.message(for: ModelProviderClient.ClientError.httpStatus(400, body))
        let reflectionMessage = ClaraErrorPresenter.message(for: OpenAICompatibleReflectionService.ServiceError.httpStatus(400, body))

        for message in [modelListMessage, reflectionMessage] {
            XCTAssertFalse(message.contains(fakeBearer))
            XCTAssertFalse(message.contains(fakeKey))
            XCTAssertTrue(message.contains("Bearer [redacted]"))
            XCTAssertTrue(message.contains("sk-[redacted]"))
            XCTAssertLessThanOrEqual(message.count, 210)
        }
    }

    func testProviderHTTPErrorUsesGenericMessageWhenBodyIsBlank() {
        XCTAssertEqual(
            ClaraErrorPresenter.message(for: ModelProviderClient.ClientError.httpStatus(418, " \n\t ")),
            "模型列表请求失败：HTTP 418。"
        )
        XCTAssertEqual(
            ClaraErrorPresenter.message(for: OpenAICompatibleReflectionService.ServiceError.httpStatus(418, "")),
            "默认整理模型请求失败：HTTP 418。"
        )
    }

    func testModelProviderConfigurationDefaultsToDeepSeekPreset() {
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: "model-config-default-\(UUID().uuidString)"))
        defaults.removeObject(forKey: ModelProviderConfiguration.userDefaultsKey)

        let configuration = ModelProviderConfigurationStore.load(userDefaults: defaults)

        XCTAssertEqual(configuration.providerName, "DeepSeek")
        XCTAssertEqual(configuration.baseURLString, "https://api.deepseek.com")
        XCTAssertEqual(configuration.model, "deepseek-v4-pro")
    }

    func testModelProviderConfigurationPersistsOpenAICompatibleEndpoint() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "model-config-save-\(UUID().uuidString)"))
        let configuration = ModelProviderConfiguration(
            providerName: "OpenAI",
            baseURLString: "https://api.openai.com/v1/",
            model: "gpt-4.1"
        )

        try ModelProviderConfigurationStore.save(configuration, userDefaults: defaults)
        let loaded = ModelProviderConfigurationStore.load(userDefaults: defaults)

        XCTAssertEqual(loaded.providerName, "OpenAI")
        XCTAssertEqual(loaded.baseURLString, "https://api.openai.com/v1")
        XCTAssertEqual(loaded.model, "gpt-4.1")
    }

    func testModelProviderConfigurationRequiresHTTPSBaseURLWithHost() {
        let missingScheme = ModelProviderConfiguration(
            providerName: "Provider",
            baseURLString: "api.example.com/v1",
            model: "model-a"
        )
        let insecure = ModelProviderConfiguration(
            providerName: "Provider",
            baseURLString: "http://api.example.com/v1",
            model: "model-a"
        )
        let valid = ModelProviderConfiguration(
            providerName: "Provider",
            baseURLString: "https://api.example.com/v1",
            model: "model-a"
        )

        XCTAssertNil(missingScheme.baseURL)
        XCTAssertNil(insecure.baseURL)
        XCTAssertEqual(valid.baseURL?.absoluteString, "https://api.example.com/v1")
    }

    func testOrganizationEngineModeDefaultsToLocalRules() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "engine-mode-default-\(UUID().uuidString)"))
        defaults.removeObject(forKey: OrganizationEngineMode.userDefaultsKey)

        XCTAssertEqual(OrganizationEngineModeStore.load(userDefaults: defaults), .localRules)
    }

    func testOrganizationEngineModePersistsExternalModel() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "engine-mode-save-\(UUID().uuidString)"))

        OrganizationEngineModeStore.save(.externalModel, userDefaults: defaults)

        XCTAssertEqual(OrganizationEngineModeStore.load(userDefaults: defaults), .externalModel)
    }

    func testExternalModelProcessingConsentMigratesLegacyAIKey() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "external-model-consent-migration-\(UUID().uuidString)"))
        defaults.set(true, forKey: "thirdPartyAIProcessingConsentAccepted")

        XCTAssertTrue(ExternalModelProcessingConsentStore.isAccepted(userDefaults: defaults))
        XCTAssertTrue(defaults.bool(forKey: ExternalModelProcessingConsentStore.userDefaultsKey))
    }

    func testExternalModelProcessingConsentResetClearsCurrentAndLegacyKeys() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "external-model-consent-reset-\(UUID().uuidString)"))
        defaults.set(true, forKey: ExternalModelProcessingConsentStore.userDefaultsKey)
        defaults.set(true, forKey: "thirdPartyAIProcessingConsentAccepted")

        ExternalModelProcessingConsentStore.reset(userDefaults: defaults)

        XCTAssertNil(defaults.object(forKey: ExternalModelProcessingConsentStore.userDefaultsKey))
        XCTAssertNil(defaults.object(forKey: "thirdPartyAIProcessingConsentAccepted"))
        XCTAssertFalse(ExternalModelProcessingConsentStore.isAccepted(userDefaults: defaults))
    }

    func testExternalModelStatusRequiresEveryActivationCondition() {
        let status = OrganizationEngineStatus(
            preferredMode: .externalModel,
            effectiveMode: .localPlaceholder,
            hasSavedModelKey: true,
            hasAcceptedExternalProcessing: false,
            modelProvider: ModelProviderConfiguration(
                providerName: "DeepSeek",
                baseURLString: "https://api.deepseek.com",
                model: "deepseek-v4-pro"
            )
        )

        XCTAssertFalse(status.isExternalModelEnabled)
        XCTAssertFalse(status.areExternalModelActivationConditionsMet)
        XCTAssertEqual(status.statusPillTitle, "正在使用本机规则")
        XCTAssertEqual(status.effectiveTitle, "当前生效：本机规则")
        XCTAssertEqual(status.activationProgressTitle, "启用条件：3/4 已完成")
        XCTAssertEqual(status.activationDecisionTitle, "未启用：仍走本机规则")
        XCTAssertEqual(status.activationDecisionSummary, "选择外部模型不等于启用；只有下面 4 项全部完成，才会把整理切到外部模型。")
        XCTAssertEqual(status.unmetRequirementTitles, ["已确认外部处理说明"])
        XCTAssertEqual(status.unmetRequirementsSummary, "还差：已确认外部处理说明")
        XCTAssertEqual(status.importSummary, "外部模型还没有启用，本次导入仍会使用本机规则。")
        XCTAssertEqual(status.activationRuleSummary, "你只是选择了外部模型；还差 已确认外部处理说明。未全部完成前，本次整理仍走本机规则。")
        XCTAssertTrue(status.shouldShowImportSettingsAction)
        XCTAssertEqual(status.importSettingsActionTitle, "补全启用条件")
    }

    func testExternalModelStatusShowsEnabledWhenEveryConditionIsMet() {
        let status = OrganizationEngineStatus(
            preferredMode: .externalModel,
            effectiveMode: .remoteModel,
            hasSavedModelKey: true,
            hasAcceptedExternalProcessing: true,
            modelProvider: ModelProviderConfiguration(
                providerName: "DeepSeek",
                baseURLString: "https://api.deepseek.com",
                model: "deepseek-v4-pro"
            )
        )

        XCTAssertTrue(status.isExternalModelEnabled)
        XCTAssertTrue(status.areExternalModelActivationConditionsMet)
        XCTAssertEqual(status.statusPillTitle, "已启用外部模型")
        XCTAssertEqual(status.effectiveTitle, "当前生效：外部模型")
        XCTAssertEqual(status.activationProgressTitle, "启用条件：4/4 已完成")
        XCTAssertEqual(status.activationDecisionTitle, "已启用：外部模型")
        XCTAssertEqual(status.activationDecisionSummary, "4 项启用条件都已完成。下一次导入整理会使用外部模型。")
        XCTAssertNil(status.unmetRequirementsSummary)
        XCTAssertEqual(status.importSummary, "本次导入会使用 DeepSeek 的 deepseek-v4-pro 整理。")
        XCTAssertFalse(status.shouldShowImportSettingsAction)
    }

    func testExternalModelStatusSeparatesActivationConditionsFromEffectiveRuntimeMode() {
        let status = OrganizationEngineStatus(
            preferredMode: .externalModel,
            effectiveMode: .localPlaceholder,
            hasSavedModelKey: true,
            hasAcceptedExternalProcessing: true,
            modelProvider: ModelProviderConfiguration(
                providerName: "DeepSeek",
                baseURLString: "https://api.deepseek.com",
                model: "deepseek-v4-pro"
            )
        )

        XCTAssertTrue(status.areExternalModelActivationConditionsMet)
        XCTAssertFalse(status.isExternalModelEnabled)
        XCTAssertEqual(status.effectiveTitle, "当前生效：本机规则")
        XCTAssertEqual(status.activationProgressTitle, "启用条件：4/4 已完成")
        XCTAssertEqual(status.activationDecisionTitle, "配置完成：等待生效")
        XCTAssertEqual(status.activationDecisionSummary, "4 项启用条件都已完成。设置保存后会刷新整理引擎，导入页会显示本次实际使用机制。")
        XCTAssertEqual(status.activationRuleSummary, "外部模型 4 项启用条件已完成。设置保存后会刷新整理引擎，导入页会显示本次实际使用机制。")
        XCTAssertEqual(status.importSummary, "外部模型还没有启用，本次导入仍会使用本机规则。")
    }

    func testExternalModelStatusDoesNotTreatUnsavedDraftConfigurationAsEffective() {
        let status = OrganizationEngineStatus(
            preferredMode: .externalModel,
            effectiveMode: .remoteModel,
            hasSavedModelKey: true,
            hasAcceptedExternalProcessing: true,
            modelProvider: ModelProviderConfiguration(
                providerName: "Saved Provider",
                baseURLString: "",
                model: ""
            ),
            hasUnsavedModelConfigurationChanges: true
        )

        XCTAssertFalse(status.isExternalModelEnabled)
        XCTAssertFalse(status.areExternalModelActivationConditionsMet)
        XCTAssertEqual(status.activationProgressTitle, "启用条件：3/4 已完成")
        XCTAssertEqual(status.activationDecisionTitle, "未启用：仍走本机规则")
        XCTAssertEqual(status.activationDecisionSummary, "有未保存的模型配置改动。当前启用状态仍按上次保存的配置计算。")
        XCTAssertEqual(status.unmetRequirementTitles, ["已保存 Base URL 和模型"])
        XCTAssertEqual(status.unmetRequirementsSummary, "还差：已保存 Base URL 和模型")
        XCTAssertEqual(status.unsavedConfigurationSummary, "有未保存的模型配置改动。先点“保存配置”，启用条件才会按新 Base URL 和模型重新计算。")
        XCTAssertEqual(status.importSummary, "外部模型还没有启用，本次导入仍会使用本机规则。")
    }

    func testLocalEngineStatusShowsRulebookVersionAndPrivacyBoundary() {
        let status = OrganizationEngineStatus(
            preferredMode: .localRules,
            effectiveMode: .localPlaceholder,
            hasSavedModelKey: false,
            hasAcceptedExternalProcessing: false,
            modelProvider: .deepSeekDefault
        )

        XCTAssertEqual(status.activationRuleSummary, "本机规则 local-v1 已生效。导入内容不会发送给模型提供方。")
        XCTAssertEqual(status.importSummary, "本次导入会使用 本机规则 local-v1，内容不会发送给模型提供方。")
        XCTAssertEqual(status.detail, "下一次导入会直接使用 本机规则 local-v1。导入内容不会发送给模型提供方。")
        XCTAssertTrue(status.shouldShowImportSettingsAction)
        XCTAssertEqual(status.importSettingsActionTitle, "切换整理方式")
    }

    func testReflectionConfigurationModeLabelsDiscloseActualRuntimeMechanism() {
        XCTAssertEqual(ReflectionConfiguration.Mode.localPlaceholder.title, "本机规则")
        XCTAssertEqual(ReflectionConfiguration.Mode.localPlaceholder.organizingTitle, "本机规则整理")
        XCTAssertEqual(ReflectionConfiguration.Mode.localPlaceholder.organizingStatusTitle, "本机规则整理中")
        XCTAssertEqual(ReflectionConfiguration.Mode.localPlaceholder.segmentProgressPrivacyDetail, "内容保留在本机")

        XCTAssertEqual(ReflectionConfiguration.Mode.remoteModel.title, "外部模型")
        XCTAssertEqual(ReflectionConfiguration.Mode.remoteModel.organizingTitle, "外部模型整理")
        XCTAssertEqual(ReflectionConfiguration.Mode.remoteModel.organizingStatusTitle, "外部模型整理中")
        XCTAssertEqual(ReflectionConfiguration.Mode.remoteModel.segmentProgressPrivacyDetail, "内容会发送到已配置的模型提供方")
    }

    func testLiveDependenciesKeepLocalRulesWhenExternalModelIsOnlySelected() throws {
        let defaults = try makeIsolatedDefaults()
        OrganizationEngineModeStore.save(.externalModel, userDefaults: defaults)
        try ModelProviderConfigurationStore.save(
            ModelProviderConfiguration(
                providerName: "Review Provider",
                baseURLString: "https://api.review-provider.example/v1",
                model: "review-model"
            ),
            userDefaults: defaults
        )

        let dependencies = try AppDependencies.live(
            apiKeyStore: TestAPIKeyStore(key: nil),
            userDefaults: defaults,
            databasePath: ":memory:"
        )

        XCTAssertTrue(dependencies.reflectionService is RuleBasedReflectionService)
        XCTAssertEqual(dependencies.reflectionConfiguration.preferredEngineMode, .externalModel)
        XCTAssertEqual(dependencies.reflectionConfiguration.mode, .localPlaceholder)
        XCTAssertFalse(dependencies.reflectionConfiguration.hasSavedModelKey)
        XCTAssertFalse(dependencies.reflectionConfiguration.hasAcceptedExternalProcessing)
    }

    func testLiveDependenciesEnableRemoteModelOnlyAfterAllActivationConditionsAreMet() throws {
        let defaults = try makeIsolatedDefaults()
        OrganizationEngineModeStore.save(.externalModel, userDefaults: defaults)
        defaults.set(true, forKey: ExternalModelProcessingConsentStore.userDefaultsKey)
        try ModelProviderConfigurationStore.save(
            ModelProviderConfiguration(
                providerName: "Review Provider",
                baseURLString: "https://api.review-provider.example/v1",
                model: "review-model"
            ),
            userDefaults: defaults
        )

        let dependencies = try AppDependencies.live(
            apiKeyStore: TestAPIKeyStore(key: "test-key"),
            userDefaults: defaults,
            databasePath: ":memory:"
        )

        XCTAssertTrue(dependencies.reflectionService is OpenAICompatibleReflectionService)
        XCTAssertEqual(dependencies.reflectionConfiguration.preferredEngineMode, .externalModel)
        XCTAssertEqual(dependencies.reflectionConfiguration.mode, .remoteModel)
        XCTAssertTrue(dependencies.reflectionConfiguration.hasSavedModelKey)
        XCTAssertTrue(dependencies.reflectionConfiguration.hasAcceptedExternalProcessing)
        XCTAssertEqual(dependencies.reflectionConfiguration.modelProvider?.trimmedProviderName, "Review Provider")
        XCTAssertEqual(dependencies.reflectionConfiguration.modelProvider?.baseURLString, "https://api.review-provider.example/v1")
        XCTAssertEqual(dependencies.reflectionConfiguration.modelProvider?.trimmedModel, "review-model")
    }

    private func makeIsolatedDefaults() throws -> UserDefaults {
        let suiteName = "app-dependencies-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct TestAPIKeyStore: APIKeyStore {
    var key: String?

    func read(service: APIKeyService) throws -> String? {
        key
    }

    func save(_ value: String, service: APIKeyService) throws {}

    func delete(service: APIKeyService) throws {}
}
