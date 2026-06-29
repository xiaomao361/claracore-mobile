import XCTest
@testable import ClaraCoreMobile

final class ReflectionRunnerTests: XCTestCase {
    func testRunReflectsSegmentsAndBuildsDigest() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let inboxStore = InboxStore(database: database)
        let sessionStore = ImportSessionStore(database: database)
        let preparer = ImportSessionPreparer(
            inboxStore: inboxStore,
            sessionStore: sessionStore,
            segmenter: FixedSizeCaptureSegmenter(maxCharacters: 24, overlapCharacters: 4)
        )
        let runner = ReflectionRunner(
            sessionStore: sessionStore,
            reflectionService: RuleBasedReflectionService()
        )

        let item = try inboxStore.enqueue(
            RawCapture(
                source: .manual,
                rawContent: "第一段内容。\n第二段内容，继续处理。",
                metadata: ["title": "测试导入"]
            )
        )
        let prepared = try preparer.prepare(item: item)

        let result = try await runner.run(prepared: prepared)

        XCTAssertEqual(result.session.id, prepared.session.id)
        XCTAssertEqual(result.drafts.count, prepared.segments.count)
        XCTAssertEqual(result.digest.sessionId, prepared.session.id)
        XCTAssertTrue(result.digest.summary.contains("第一段内容"))
    }
}
