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

    func testPresentsNetworkOfflineError() {
        let message = ClaraErrorPresenter.message(for: URLError(.notConnectedToInternet))

        XCTAssertEqual(message, "网络不可用。请检查网络连接后重试。")
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
        XCTAssertEqual(status.statusPillTitle, "正在使用本机规则")
        XCTAssertEqual(status.effectiveTitle, "当前生效：本机规则")
        XCTAssertEqual(status.activationProgressTitle, "启用条件：3/4 已完成")
        XCTAssertEqual(status.unmetRequirementTitles, ["已确认外部处理说明"])
        XCTAssertEqual(status.importSummary, "外部模型还没有启用，本次导入仍会使用本机规则。")
        XCTAssertEqual(status.activationRuleSummary, "你只是选择了外部模型；还差 已确认外部处理说明。未全部完成前，本次整理仍走本机规则。")
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
        XCTAssertEqual(status.statusPillTitle, "已启用外部模型")
        XCTAssertEqual(status.effectiveTitle, "当前生效：外部模型")
        XCTAssertEqual(status.activationProgressTitle, "启用条件：4/4 已完成")
        XCTAssertEqual(status.importSummary, "本次导入会使用 DeepSeek 的 deepseek-v4-pro 整理。")
    }
}
