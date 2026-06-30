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

    func testActiveSupportsPagination() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContinuityStore(database: AppDatabase(path: databaseURL.path))

        for index in 0..<5 {
            _ = try store.create(title: "线 \(index)", lastPosition: "位置 \(index)", nextStep: nil)
        }

        let firstPage = try store.active(limit: 2, offset: 0)
        let secondPage = try store.active(limit: 2, offset: 2)
        let thirdPage = try store.active(limit: 2, offset: 4)

        XCTAssertEqual(firstPage.count, 2)
        XCTAssertEqual(secondPage.count, 2)
        XCTAssertEqual(thirdPage.count, 1)
        XCTAssertTrue(Set(firstPage.map(\.id)).isDisjoint(with: Set(secondPage.map(\.id))))
        XCTAssertTrue(Set((firstPage + secondPage).map(\.id)).isDisjoint(with: Set(thirdPage.map(\.id))))
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

    func testDeleteRemovesLineFromStore() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let store = ContinuityStore(database: database)
        let memoriaStore = MemoriaStore(database: database)
        let line = try store.create(title: "要删除的线", lastPosition: "临时状态", nextStep: nil)
        let memory = try memoriaStore.store(
            content: "这条记忆原本绑定共同线",
            tags: ["line"],
            isPrivate: false,
            lineId: line.id
        )

        try store.delete(id: line.id)

        XCTAssertTrue(try store.active().isEmpty)
        XCTAssertNil(try memoriaStore.get(id: memory.id)?.lineId)
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

    func testCreateCompactsLongMilestoneTrail() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let store = try ContinuityStore(database: AppDatabase(path: databaseURL.path))
        let longPosition = (1...12)
            .map { "\($0). 节点 \($0)" }
            .joined(separator: "\n")

        let line = try store.create(title: "长线", lastPosition: longPosition, nextStep: nil)
        let stored = try XCTUnwrap(store.get(id: line.id))

        XCTAssertTrue(stored.lastPosition.hasPrefix("较早 4 个节点已压缩。"))
        XCTAssertFalse(stored.lastPosition.contains("1. 节点 1\n"))
        XCTAssertTrue(stored.lastPosition.contains("节点 12"))
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
        XCTAssertEqual(line.completedMilestoneSteps, [
            "已完成 DeepSeek 分享链接导入",
            "已完成真实整理入库"
        ])
        XCTAssertEqual(line.currentMilestone, "正在调整记忆和共同线模型")
        XCTAssertEqual(line.journeyProgressTitle, "已过 2 站")
    }
}
