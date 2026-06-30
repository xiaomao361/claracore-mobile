import XCTest
@testable import ClaraCoreMobile

final class ClaraErrorPresenterTests: XCTestCase {
    func testPresentsDeepSeekMissingKeyError() {
        let message = ClaraErrorPresenter.message(for: DeepSeekReflectionService.ServiceError.missingAPIKey)

        XCTAssertEqual(message, "默认整理模型 API Key 未配置。请先在设置里保存 Key。")
    }

    func testPresentsDeepSeekUnauthorizedError() {
        let message = ClaraErrorPresenter.message(for: DeepSeekReflectionService.ServiceError.httpStatus(401, ""))

        XCTAssertEqual(message, "默认整理模型 Key 无效或没有权限。请检查 Key 后重试。")
    }

    func testPresentsNetworkOfflineError() {
        let message = ClaraErrorPresenter.message(for: URLError(.notConnectedToInternet))

        XCTAssertEqual(message, "网络不可用。请检查网络连接后重试。")
    }
}
