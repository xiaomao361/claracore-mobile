import Foundation
import GRDB

final class ImportSessionStore {
    private let database: AppDatabase
    private let dateFormatter = ISO8601DateFormatter()

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func create(from capture: RawCapture, title: String) throws -> ImportSession {
        let now = Date()
        let session = ImportSession(
            source: capture.source,
            sourceApp: capture.sourceApp,
            sourceThreadId: capture.sourceThreadId,
            contextCardId: capture.contextCardId,
            title: title,
            createdAt: now,
            updatedAt: now
        )

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO import_sessions (
                    id, source, source_app, source_thread_id, context_card_id, title, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    session.id,
                    session.source.rawValue,
                    session.sourceApp,
                    session.sourceThreadId,
                    session.contextCardId,
                    session.title,
                    session.status.rawValue,
                    dateFormatter.string(from: session.createdAt),
                    dateFormatter.string(from: session.updatedAt)
                ]
            )
        }

        return session
    }

    func addSegments(_ segments: [CaptureSegment]) throws {
        try database.dbQueue.write { db in
            for segment in segments {
                try db.execute(
                    sql: """
                    INSERT INTO capture_segments (
                        id, session_id, sequence, content, content_hash,
                        range_start, range_end, token_estimate, status, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        segment.id,
                        segment.sessionId,
                        segment.sequence,
                        segment.content,
                        segment.contentHash,
                        segment.characterRange.lowerBound,
                        segment.characterRange.upperBound,
                        segment.tokenEstimate,
                        segment.status.rawValue,
                        dateFormatter.string(from: segment.createdAt)
                    ]
                )
            }
        }
    }

    func segments(sessionId: String) throws -> [CaptureSegment] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM capture_segments
                WHERE session_id = ?
                ORDER BY sequence ASC
                """,
                arguments: [sessionId]
            )

            return rows.map(segment(from:))
        }
    }

    func updateStatus(sessionId: String, status: ImportSession.Status) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE import_sessions SET status = ?, updated_at = ? WHERE id = ?",
                arguments: [status.rawValue, dateFormatter.string(from: Date()), sessionId]
            )
        }
    }

    private func segment(from row: Row) -> CaptureSegment {
        let createdAtString: String = row["created_at"]
        let rangeStart: Int = row["range_start"]
        let rangeEnd: Int = row["range_end"]
        let statusValue: String = row["status"]

        return CaptureSegment(
            id: row["id"],
            sessionId: row["session_id"],
            sequence: row["sequence"],
            content: row["content"],
            characterRange: rangeStart..<rangeEnd,
            status: CaptureSegment.Status(rawValue: statusValue) ?? .pending,
            createdAt: dateFormatter.date(from: createdAtString) ?? Date()
        )
    }
}
