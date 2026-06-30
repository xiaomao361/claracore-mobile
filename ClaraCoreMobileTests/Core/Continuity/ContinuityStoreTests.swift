import XCTest
@testable import ClaraCoreMobile

final class ContinuityStoreTests: XCTestCase {
    func testCreateThenListActiveLine() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContinuityStore(database: AppDatabase(path: databaseURL.path))

        let line = try store.create(
            title: "ClaraCore Mobile",
            lastPosition: "正在打通导入整理流程。",
            nextStep: "提交候选记忆和共同线。"
        )

        let active = try store.active()

        XCTAssertEqual(active.first?.id, line.id)
        XCTAssertEqual(active.first?.title, "ClaraCore Mobile")
        XCTAssertEqual(active.first?.lastPosition, "正在打通导入整理流程。")
        XCTAssertEqual(active.first?.nextStep, "提交候选记忆和共同线。")
    }

    func testArchiveRemovesLineFromActiveList() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContinuityStore(database: AppDatabase(path: databaseURL.path))
        let line = try store.create(title: "旧线", lastPosition: "已完成。", nextStep: nil)

        try store.archive(id: line.id)

        XCTAssertTrue(try store.active().isEmpty)
    }

    func testUpdateChangesActiveLineContent() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContinuityStore(database: AppDatabase(path: databaseURL.path))
        let line = try store.create(title: "旧线", lastPosition: "旧位置", nextStep: nil)

        try store.update(id: line.id, title: "新线", lastPosition: "新位置", nextStep: "下一步")

        let updated = try XCTUnwrap(store.active().first)
        XCTAssertEqual(updated.id, line.id)
        XCTAssertEqual(updated.title, "新线")
        XCTAssertEqual(updated.lastPosition, "新位置")
        XCTAssertEqual(updated.nextStep, "下一步")
    }

    func testMilestoneStepsParseNumberedAndBulletedLines() {
        let line = ContinuityLine(
            id: "line-1",
            title: "ClaraCore Mobile",
            lastPosition: """
            1. 已完成 DeepSeek 分享链接导入
            2、已完成真实整理入库
            - 正在调整记忆和共同线模型
            """,
            nextStep: nil,
            status: .active,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(
            line.milestoneSteps,
            [
                "已完成 DeepSeek 分享链接导入",
                "已完成真实整理入库",
                "正在调整记忆和共同线模型"
            ]
        )
        XCTAssertEqual(line.milestoneProgressTitle, "当前里程 3")
    }
}
