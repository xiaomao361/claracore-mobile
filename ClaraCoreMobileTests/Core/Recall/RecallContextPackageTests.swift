import XCTest
@testable import ClaraCoreMobile

final class RecallContextPackageTests: XCTestCase {
    func testBuildsCopyableDeepSeekContext() {
        let line = ContinuityLine(
            id: "line-1",
            title: "ClaraCore Mobile",
            lastPosition: "正在打通整理到提交。",
            nextStep: "补回召复制流程。",
            status: .active,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let memory = Memory(
            id: "memory-1",
            content: "第一版主要针对国内用户。",
            tags: ["product"],
            isPrivate: false,
            isArchived: false,
            sourceAgent: "mobile-reflection",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let card = ContextCard(
            id: "card-1",
            title: "默认角色卡",
            agentProfile: "你是一个帮助用户延续跨应用对话上下文的助手。",
            userProfile: "用户希望你基于共同线和事实记忆继续。",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let package = RecallContextBuilder().build(contextCard: card, line: line, memories: [memory])

        XCTAssertTrue(package.formattedText.contains("# Agent"))
        XCTAssertTrue(package.formattedText.contains("# 用户"))
        XCTAssertTrue(package.formattedText.contains("# 共同线"))
        XCTAssertTrue(package.formattedText.contains("标题：ClaraCore Mobile"))
        XCTAssertTrue(package.formattedText.contains("# 相关事实记忆"))
        XCTAssertTrue(package.formattedText.contains("第一版主要针对国内用户。"))
        XCTAssertTrue(package.formattedText.contains("# 请求"))
    }
}
