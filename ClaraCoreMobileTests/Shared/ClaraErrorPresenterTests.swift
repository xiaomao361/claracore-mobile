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
}
