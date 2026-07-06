import XCTest
@testable import ClaraCoreMobile

final class RecallContextPackageTests: XCTestCase {
    func testBuildsRoleContinuationContext() {
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
            tags: ["product", "fact"],
            isPrivate: false,
            isArchived: false,
            sourceAgent: "mobile-reflection",
            lineId: "line-1",
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

        XCTAssertTrue(package.formattedText.contains("请接着这段关系和这条共同线继续"))
        XCTAssertTrue(package.formattedText.contains("你现在的角色："))
        XCTAssertTrue(package.formattedText.contains("你正在面对的用户："))
        XCTAssertTrue(package.formattedText.contains("我们正在延续："))
        XCTAssertTrue(package.formattedText.contains("ClaraCore Mobile"))
        XCTAssertTrue(package.formattedText.contains("现在停在："))
        XCTAssertTrue(package.formattedText.contains("- 正在打通整理到提交。"))
        XCTAssertTrue(package.formattedText.contains("需要记住的事实："))
        XCTAssertTrue(package.formattedText.contains("- 事实： 第一版主要针对国内用户。"))
        XCTAssertTrue(package.formattedText.contains("第一版主要针对国内用户。"))
        XCTAssertTrue(package.formattedText.contains("不要补成正式报告"))
    }

    func testFormattedTextExcludesModelProviderConfigurationAndRawArchiveByDefault() {
        let line = ContinuityLine(
            id: "line-1",
            title: "继续产品定位",
            lastPosition: "正在确认本地工具边界。",
            nextStep: "复制最小上下文给外部对话应用。",
            status: .active,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let card = ContextCard(
            id: "card-1",
            title: "默认角色卡",
            agentProfile: "你延续上下文，只围绕用户给出的共同线继续。",
            userProfile: "用户只需要共同线和勾选记忆。",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let memory = Memory(
            id: "memory-1",
            content: "用户希望复制包只包含可见上下文。",
            tags: ["preference"],
            isPrivate: false,
            isArchived: false,
            sourceAgent: "mobile-reflection",
            lineId: "line-1",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let package = RecallContextBuilder().build(
            contextCard: card,
            line: line,
            memories: [memory],
            request: "按当前共同线继续。"
        )

        XCTAssertTrue(package.formattedText.contains("用户希望复制包只包含可见上下文。"))
        XCTAssertTrue(package.formattedText.contains("按当前共同线继续。"))
        XCTAssertFalse(package.formattedText.contains("API Key"))
        XCTAssertFalse(package.formattedText.contains("Base URL"))
        XCTAssertFalse(package.formattedText.contains("Authorization"))
        XCTAssertFalse(package.formattedText.contains("模型配置"))
        XCTAssertFalse(package.formattedText.contains("原文 Archive"))
        XCTAssertFalse(package.formattedText.contains("rawContent"))
    }

    func testBlankRecallRequestFallsBackToDefaultContinuationInstruction() {
        let package = RecallContextBuilder().build(
            contextCard: makeContextCard(),
            line: makeLine(),
            memories: [],
            request: " \n\t "
        )

        XCTAssertTrue(package.formattedText.contains("这次请这样继续：\n\(RecallContextBuilder.defaultRequest)"))
    }

    func testRecallRequestIsTrimmedBeforeCopying() {
        let package = RecallContextBuilder().build(
            contextCard: makeContextCard(),
            line: makeLine(),
            memories: [],
            request: " \n  请直接接着当前共同线继续。  \n"
        )

        XCTAssertTrue(package.formattedText.contains("这次请这样继续：\n请直接接着当前共同线继续。"))
        XCTAssertFalse(package.formattedText.contains("  请直接接着当前共同线继续。  "))
    }

    private func makeLine() -> ContinuityLine {
        ContinuityLine(
            id: "line-1",
            title: "回召复制",
            lastPosition: "正在验证复制包。",
            nextStep: "粘贴到外部对话应用。",
            status: .active,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeContextCard() -> ContextCard {
        ContextCard(
            id: "card-1",
            title: "默认角色卡",
            agentProfile: "你延续上下文。",
            userProfile: "用户希望自然继续。",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
