import XCTest
@testable import ClaraCoreMobile

final class ImportSessionPreparerTests: XCTestCase {
    func testPrepareCreatesSessionSegmentsWithoutRemovingInboxItem() throws {
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

        let item = try inboxStore.enqueue(
            RawCapture(
                source: .url,
                rawContent: "First segment text. Second segment text.",
                sourceApp: "DeepSeek",
                sourceThreadId: "share-1",
                contextCardId: "role-1",
                metadata: ["title": "Shared Conversation"]
            )
        )

        let prepared = try preparer.prepare(item: item)
        let storedSegments = try sessionStore.segments(sessionId: prepared.session.id)

        XCTAssertEqual(prepared.session.title, "Shared Conversation")
        XCTAssertEqual(prepared.session.sourceApp, "DeepSeek")
        XCTAssertEqual(prepared.session.contextCardId, "role-1")
        XCTAssertGreaterThanOrEqual(prepared.segments.count, 2)
        XCTAssertEqual(storedSegments.map(\.id), prepared.segments.map(\.id))
        XCTAssertEqual(storedSegments.map(\.sequence), prepared.segments.map(\.sequence))
        XCTAssertEqual(storedSegments.map(\.contentHash), prepared.segments.map(\.contentHash))
        XCTAssertEqual(try inboxStore.pending().map(\.id), [item.id])
    }
}
