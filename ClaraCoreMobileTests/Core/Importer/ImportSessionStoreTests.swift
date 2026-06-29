import XCTest
@testable import ClaraCoreMobile

final class ImportSessionStoreTests: XCTestCase {
    func testCreateSessionAndPersistSegments() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let store = ImportSessionStore(database: database)
        let capture = RawCapture(
            source: .share,
            rawContent: "First long import.\nSecond line.",
            sourceApp: "Claude",
            sourceThreadId: "claude-thread-1"
        )

        let session = try store.create(from: capture, title: "Claude export")
        let segments = FixedSizeCaptureSegmenter(maxCharacters: 10, overlapCharacters: 0)
            .segment(capture: capture, sessionId: session.id)

        try store.addSegments(segments)
        let stored = try store.segments(sessionId: session.id)

        XCTAssertEqual(stored.count, segments.count)
        XCTAssertEqual(stored.first?.sequence, 0)
        XCTAssertEqual(stored.first?.contentHash, segments.first?.contentHash)
    }
}

