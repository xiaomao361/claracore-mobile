import XCTest
@testable import ClaraCoreMobile

final class InboxStoreTests: XCTestCase {
    func testEnqueueThenListPendingCapture() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try InboxStore(database: AppDatabase(path: databaseURL.path))
        let capture = RawCapture(
            source: .clipboard,
            rawContent: "A useful mobile capture waiting for review.",
            sourceApp: "ChatGPT",
            sourceThreadId: "chatgpt-thread-1",
            contextCardId: "role-1",
            metadata: ["app": "ChatGPT"]
        )

        let item = try store.enqueue(capture)
        let pending = try store.pending()

        XCTAssertEqual(pending.first?.id, item.id)
        XCTAssertEqual(pending.first?.source, .clipboard)
        XCTAssertEqual(pending.first?.sourceApp, "ChatGPT")
        XCTAssertEqual(pending.first?.sourceThreadId, "chatgpt-thread-1")
        XCTAssertEqual(pending.first?.contextCardId, "role-1")
        XCTAssertEqual(pending.first?.contentHash, RawCapture.hash("A useful mobile capture waiting for review."))
        XCTAssertEqual(pending.first?.metadata["app"], "ChatGPT")
    }

    func testContentHashNormalizesOuterWhitespace() {
        XCTAssertEqual(
            RawCapture.hash("  Same capture text.\n"),
            RawCapture.hash("Same capture text.")
        )
    }

    func testUpdateStatusRemovesCaptureFromPendingList() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try InboxStore(database: AppDatabase(path: databaseURL.path))
        let item = try store.enqueue(RawCapture(source: .manual, rawContent: "Discard me."))

        try store.updateStatus(id: item.id, status: .discarded)

        XCTAssertTrue(try store.pending().isEmpty)
    }

    func testUpdateCommitResultPersistsResultIdsForDuplicateRecovery() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try InboxStore(database: AppDatabase(path: databaseURL.path))
        let item = try store.enqueue(
            RawCapture(
                source: .share,
                rawContent: "Same imported conversation.",
                sourceApp: "DeepSeek",
                sourceThreadId: "share-1"
            )
        )

        try store.updateCommitResult(id: item.id, memoryIds: ["memory-1", "memory-2"], lineIds: ["line-1"])

        let existing = try XCTUnwrap(store.existing(
            contentHash: item.contentHash,
            sourceApp: item.sourceApp,
            sourceThreadId: item.sourceThreadId
        ))
        XCTAssertEqual(existing.metadata["committed_memory_ids"], "memory-1,memory-2")
        XCTAssertEqual(existing.metadata["committed_line_ids"], "line-1")
    }
}
