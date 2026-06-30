import XCTest
@testable import ClaraCoreMobile

final class MemoriaStoreTests: XCTestCase {
    func testStoreThenRecallReturnsStoredMemory() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))

        let memory = try store.store(
            content: "ClaraCore mobile capture should become searchable memory.",
            tags: ["mobile", "capture"],
            isPrivate: false
        )

        let results = try store.recall(query: "searchable", limit: 10)

        XCTAssertEqual(results.first?.id, memory.id)
        XCTAssertEqual(results.first?.tags, ["mobile", "capture"])
    }

    func testRecentReturnsStoredMemories() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))

        let first = try store.store(content: "第一条事实记忆", tags: ["one"], isPrivate: false)
        let second = try store.store(content: "第二条事实记忆", tags: ["two"], isPrivate: false)

        let recent = try store.recent(limit: 10)

        XCTAssertEqual(Set(recent.map(\.id)), Set([first.id, second.id]))
    }

    func testRelatedToLineReturnsOnlyBoundMemories() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))
        let bound = try store.store(content: "绑定到共同线的事实", tags: ["line"], isPrivate: false, lineId: "line-1")
        _ = try store.store(content: "另一条事实", tags: ["other"], isPrivate: false, lineId: "line-2")
        _ = try store.store(content: "未绑定事实", tags: ["loose"], isPrivate: false)

        let related = try store.related(toLineId: "line-1", limit: 10)

        XCTAssertEqual(related.map(\.id), [bound.id])
        XCTAssertEqual(related.first?.lineId, "line-1")
    }

    func testUpdateRefreshesMemoryAndSearchIndex() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))
        let memory = try store.store(content: "旧项目事实", tags: ["old"], isPrivate: false)

        try store.update(id: memory.id, content: "新项目事实可以被检索", tags: ["new", "project"], isPrivate: true)

        let updated = try XCTUnwrap(store.get(id: memory.id))
        XCTAssertEqual(updated.content, "新项目事实可以被检索")
        XCTAssertEqual(updated.tags, ["new", "project"])
        XCTAssertTrue(updated.isPrivate)
        XCTAssertNil(updated.lineId)
        XCTAssertEqual(try store.recall(query: "检索", limit: 10).first?.id, memory.id)
    }

    func testRecallFallsBackToMixedChineseAndLatinKeywords() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))
        let memory = try store.store(
            content: "DeepSeek App封闭环境限制：无网络权限、无文件权限。",
            tags: ["DeepSeek限制"],
            isPrivate: false
        )

        let results = try store.recall(query: "DeepSeek数据导出方案讨论 比较截图OCR和分享链接", limit: 5)

        XCTAssertEqual(results.first?.id, memory.id)
    }

    func testDeleteRemovesMemoryFromStoreRecentAndRecall() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))
        let memory = try store.store(content: "应该被隐藏的事实", tags: ["archive"], isPrivate: false)

        try store.delete(id: memory.id)

        XCTAssertTrue(try store.recent(limit: 10).isEmpty)
        XCTAssertTrue(try store.recall(query: "隐藏", limit: 10).isEmpty)
        XCTAssertNil(try store.get(id: memory.id))
    }

    func testRecallCanBeScopedByContextCard() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))
        _ = try store.store(
            content: "用户决定 ClaraCore Mobile 用工作角色继续。",
            tags: ["role"],
            isPrivate: false,
            contextCardId: "work-role"
        )
        _ = try store.store(
            content: "用户决定 ClaraCore Mobile 用生活角色继续。",
            tags: ["role"],
            isPrivate: false,
            contextCardId: "life-role"
        )

        let workResults = try store.recall(query: "ClaraCore Mobile 继续", limit: 10, contextCardId: "work-role")

        XCTAssertEqual(workResults.map(\.contextCardId), ["work-role"])
        XCTAssertEqual(workResults.first?.content, "用户决定 ClaraCore Mobile 用工作角色继续。")
    }
}
