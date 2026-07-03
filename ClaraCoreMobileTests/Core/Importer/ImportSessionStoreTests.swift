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

    func testArchiveListsOriginalRawContentAndCommitMetadata() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let inboxStore = InboxStore(database: database)
        let store = ImportSessionStore(database: database)
        let capture = RawCapture(
            source: .share,
            rawContent: "Original conversation text about ClaraCore archive.",
            sourceApp: "ChatGPT",
            sourceThreadId: "thread-archive",
            contextCardId: "role-archive",
            metadata: ["title": "Archive Fixture"]
        )

        let item = try inboxStore.enqueue(capture)
        let session = try store.create(from: item.rawCapture(), title: "Archive Fixture")
        let segments = FixedSizeCaptureSegmenter(maxCharacters: 16, overlapCharacters: 0)
            .segment(capture: capture, sessionId: session.id)

        try store.addSegments(segments)
        try inboxStore.updateCommitResult(id: item.id, memoryIds: ["memory-1", "memory-2"], lineIds: ["line-1"])
        try inboxStore.updateStatus(id: item.id, status: .committed)

        let archived = try store.archive(contextCardId: "role-archive")

        XCTAssertEqual(archived.count, 1)
        XCTAssertEqual(archived.first?.id, session.id)
        XCTAssertEqual(archived.first?.rawContent, capture.rawContent)
        XCTAssertEqual(archived.first?.segmentCount, segments.count)
        XCTAssertEqual(archived.first?.committedMemoryIds, ["memory-1", "memory-2"])
        XCTAssertEqual(archived.first?.committedLineIds, ["line-1"])
        XCTAssertEqual(try store.archive(contextCardId: "other-role").count, 0)
    }

    func testSearchArchiveMatchesRawContentAndSource() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let inboxStore = InboxStore(database: database)
        let store = ImportSessionStore(database: database)
        let first = RawCapture(
            source: .manual,
            rawContent: "A long exchange about local-first memory.",
            sourceApp: "Claude",
            contextCardId: "role-1"
        )
        let second = RawCapture(
            source: .manual,
            rawContent: "Unrelated note.",
            sourceApp: "DeepSeek",
            contextCardId: "role-1"
        )

        let firstItem = try inboxStore.enqueue(first)
        let secondItem = try inboxStore.enqueue(second)
        _ = try store.create(from: firstItem.rawCapture(), title: "Memory Discussion")
        _ = try store.create(from: secondItem.rawCapture(), title: "Other")

        let contentMatches = try store.searchArchive(query: "local-first", contextCardId: "role-1")
        let sourceMatches = try store.searchArchive(query: "DeepSeek", contextCardId: "role-1")

        XCTAssertEqual(contentMatches.map(\.rawContent), [first.rawContent])
        XCTAssertEqual(sourceMatches.map(\.rawContent), [second.rawContent])
    }

    func testArchiveFallsBackToOrderedSegmentsWhenInboxRawContentIsMissing() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let store = ImportSessionStore(database: database)
        let capture = RawCapture(
            id: "legacy-capture",
            source: .manual,
            rawContent: "Part one. Part two.",
            contextCardId: "role-legacy"
        )

        let session = try store.create(from: capture, title: "Legacy")
        try database.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM inbox WHERE id = ?", arguments: [session.id])
        }
        try store.addSegments([
            CaptureSegment(sessionId: session.id, sequence: 0, content: "Part one. ", characterRange: 0..<10),
            CaptureSegment(sessionId: session.id, sequence: 1, content: "Part two.", characterRange: 10..<19)
        ])

        let archived = try store.archive(contextCardId: "role-legacy")

        XCTAssertEqual(archived.first?.rawContent, "Part one. Part two.")
        XCTAssertEqual(archived.first?.segmentCount, 2)
    }

    func testDeleteArchivedSessionRemovesSourceArchiveAndSegments() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let inboxStore = InboxStore(database: database)
        let store = ImportSessionStore(database: database)
        let capture = RawCapture(
            source: .manual,
            rawContent: "Sensitive source text that should be removable.",
            sourceApp: "Manual",
            contextCardId: "role-delete"
        )

        let item = try inboxStore.enqueue(capture)
        let session = try store.create(from: item.rawCapture(), title: "Delete Fixture")
        let segments = FixedSizeCaptureSegmenter(maxCharacters: 12, overlapCharacters: 0)
            .segment(capture: capture, sessionId: session.id)
        try store.addSegments(segments)
        try inboxStore.updateStatus(id: item.id, status: .committed)

        XCTAssertEqual(try store.archive(contextCardId: "role-delete").count, 1)

        try store.deleteArchivedSession(id: session.id)

        XCTAssertNil(try store.archivedSession(id: session.id))
        XCTAssertEqual(try store.archive(contextCardId: "role-delete").count, 0)
        XCTAssertEqual(try store.segments(sessionId: session.id).count, 0)

        let inboxCount = try database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM inbox WHERE id = ?", arguments: [session.id]) ?? 0
        }
        XCTAssertEqual(inboxCount, 0)
    }
}
