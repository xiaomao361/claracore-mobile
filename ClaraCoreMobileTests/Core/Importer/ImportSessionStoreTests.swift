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

    func testDeleteArchivedSessionPreservesCommittedMemoriesAndContinuityLines() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        let inboxStore = InboxStore(database: database)
        let sessionStore = ImportSessionStore(database: database)
        let memoriaStore = MemoriaStore(database: database)
        let continuityStore = ContinuityStore(database: database)
        let committer = DigestCommitter(memoriaStore: memoriaStore, continuityStore: continuityStore)
        let capture = RawCapture(
            source: .manual,
            rawContent: "用户决定保留原文删除和整理结果删除的边界。",
            sourceApp: "Manual",
            contextCardId: "role-preserve"
        )
        let item = try inboxStore.enqueue(capture)
        let session = try sessionStore.create(from: item.rawCapture(), title: "Preserve Fixture")
        let provenance = ReflectionProvenance(
            sessionId: session.id,
            segmentId: "segment-1",
            characterRange: 0..<capture.rawContent.count
        )
        let digest = DigestResult(
            sessionId: session.id,
            summary: "原文删除边界",
            candidateMemories: [
                CandidateMemory(
                    kind: .decision,
                    content: "用户决定删除原文 Archive 不应删除已提交记忆。",
                    confidence: 0.93,
                    tags: ["archive"],
                    provenance: provenance
                )
            ],
            candidateSharedLineUpdates: [
                CandidateSharedLineUpdate(
                    title: "原文删除边界",
                    lastPosition: "已确认删除原文 Archive 只移除源材料。",
                    nextStep: "继续保留已提交整理结果。",
                    stateSummary: "Archive 删除和整理结果删除是两个独立动作。",
                    confidence: 0.9,
                    provenance: provenance
                )
            ],
            conflicts: []
        )
        let committed = try committer.commit(digest, contextCardId: "role-preserve")
        try inboxStore.updateCommitResult(
            id: item.id,
            memoryIds: committed.memories.map(\.id),
            lineIds: committed.continuityLines.map(\.id)
        )
        try inboxStore.updateStatus(id: item.id, status: .committed)

        try sessionStore.deleteArchivedSession(id: session.id)

        XCTAssertNil(try sessionStore.archivedSession(id: session.id))
        let memories = try memoriaStore.recall(query: "Archive", limit: 10, contextCardId: "role-preserve")
        let lines = try continuityStore.active(contextCardId: "role-preserve")
        XCTAssertEqual(memories.map(\.content), ["用户决定删除原文 Archive 不应删除已提交记忆。"])
        XCTAssertEqual(memories.first?.lineId, committed.continuityLines.first?.id)
        XCTAssertEqual(lines.map(\.id), committed.continuityLines.map(\.id))
        XCTAssertEqual(lines.first?.lastPosition, "已确认删除原文 Archive 只移除源材料。")
    }
}
