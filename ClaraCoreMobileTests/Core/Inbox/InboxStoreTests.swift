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
            metadata: ["app": "ChatGPT"]
        )

        let item = try store.enqueue(capture)
        let pending = try store.pending()

        XCTAssertEqual(pending.first?.id, item.id)
        XCTAssertEqual(pending.first?.source, .clipboard)
        XCTAssertEqual(pending.first?.sourceApp, "ChatGPT")
        XCTAssertEqual(pending.first?.sourceThreadId, "chatgpt-thread-1")
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
}
