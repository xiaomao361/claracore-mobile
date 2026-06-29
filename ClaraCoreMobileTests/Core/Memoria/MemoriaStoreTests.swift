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

    func testDeleteArchivesMemoryFromRecentAndRecall() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try MemoriaStore(database: AppDatabase(path: databaseURL.path))
        let memory = try store.store(content: "应该被隐藏的事实", tags: ["archive"], isPrivate: false)

        try store.delete(id: memory.id)

        XCTAssertTrue(try store.recent(limit: 10).isEmpty)
        XCTAssertTrue(try store.recall(query: "隐藏", limit: 10).isEmpty)
    }
}
