import Foundation
import GRDB

final class ImportSessionStore {
    private let database: AppDatabase
    private let dateFormatter = ISO8601DateFormatter()
    private let decoder = JSONDecoder()

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func create(from capture: RawCapture, title: String) throws -> ImportSession {
        let now = Date()
        let session = ImportSession(
            id: capture.id,
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

    func archive(limit: Int = 30, offset: Int = 0, contextCardId: String? = nil) throws -> [ArchivedImportSession] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    s.*,
                    i.raw_content,
                    i.content_hash,
                    i.metadata,
                    COUNT(c.id) AS segment_count,
                    (
                        SELECT GROUP_CONCAT(ordered_segments.content, '')
                        FROM (
                            SELECT content
                            FROM capture_segments
                            WHERE session_id = s.id
                            ORDER BY sequence ASC
                        ) ordered_segments
                    ) AS segment_content
                FROM import_sessions s
                LEFT JOIN inbox i ON i.id = s.id
                LEFT JOIN capture_segments c ON c.session_id = s.id
                WHERE (? IS NULL OR s.context_card_id = ?)
                GROUP BY s.id
                ORDER BY s.created_at DESC
                LIMIT ? OFFSET ?
                """,
                arguments: [contextCardId, contextCardId, limit, offset]
            )

            return rows.map(archivedSession(from:))
        }
    }

    func searchArchive(query: String, limit: Int = 30, contextCardId: String? = nil) throws -> [ArchivedImportSession] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try archive(limit: limit, contextCardId: contextCardId)
        }

        return try database.dbQueue.read { db in
            let pattern = "%\(trimmed)%"
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    s.*,
                    i.raw_content,
                    i.content_hash,
                    i.metadata,
                    COUNT(c.id) AS segment_count,
                    (
                        SELECT GROUP_CONCAT(ordered_segments.content, '')
                        FROM (
                            SELECT content
                            FROM capture_segments
                            WHERE session_id = s.id
                            ORDER BY sequence ASC
                        ) ordered_segments
                    ) AS segment_content
                FROM import_sessions s
                LEFT JOIN inbox i ON i.id = s.id
                LEFT JOIN capture_segments c ON c.session_id = s.id
                WHERE (? IS NULL OR s.context_card_id = ?)
                  AND (
                    s.title LIKE ?
                    OR s.source_app LIKE ?
                    OR s.source_thread_id LIKE ?
                    OR i.raw_content LIKE ?
                  )
                GROUP BY s.id
                ORDER BY s.created_at DESC
                LIMIT ?
                """,
                arguments: [contextCardId, contextCardId, pattern, pattern, pattern, pattern, limit]
            )

            return rows.map(archivedSession(from:))
        }
    }

    func archivedSession(id: String) throws -> ArchivedImportSession? {
        try database.dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    s.*,
                    i.raw_content,
                    i.content_hash,
                    i.metadata,
                    COUNT(c.id) AS segment_count,
                    (
                        SELECT GROUP_CONCAT(ordered_segments.content, '')
                        FROM (
                            SELECT content
                            FROM capture_segments
                            WHERE session_id = s.id
                            ORDER BY sequence ASC
                        ) ordered_segments
                    ) AS segment_content
                FROM import_sessions s
                LEFT JOIN inbox i ON i.id = s.id
                LEFT JOIN capture_segments c ON c.session_id = s.id
                WHERE s.id = ?
                GROUP BY s.id
                LIMIT 1
                """,
                arguments: [id]
            )

            return row.map(archivedSession(from:))
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

    private func session(from row: Row) -> ImportSession {
        let sourceValue: String = row["source"]
        let statusValue: String = row["status"]
        let createdAtString: String = row["created_at"]
        let updatedAtString: String = row["updated_at"]

        return ImportSession(
            id: row["id"],
            source: RawCapture.Source(rawValue: sourceValue) ?? .manual,
            sourceApp: row["source_app"],
            sourceThreadId: row["source_thread_id"],
            contextCardId: row["context_card_id"],
            title: row["title"],
            status: ImportSession.Status(rawValue: statusValue) ?? .importing,
            createdAt: dateFormatter.date(from: createdAtString) ?? Date(),
            updatedAt: dateFormatter.date(from: updatedAtString) ?? Date()
        )
    }

    private func archivedSession(from row: Row) -> ArchivedImportSession {
        let metadataJSON: String? = row["metadata"]
        let metadataData = metadataJSON?.data(using: .utf8) ?? Data()
        let metadata = (try? decoder.decode([String: String].self, from: metadataData)) ?? [:]
        let rawContent: String? = row["raw_content"]
        let segmentContent: String? = row["segment_content"]

        return ArchivedImportSession(
            session: session(from: row),
            rawContent: rawContent ?? segmentContent ?? "",
            contentHash: row["content_hash"],
            segmentCount: row["segment_count"],
            committedMemoryIds: splitMetadataIDs(metadata["committed_memory_ids"]),
            committedLineIds: splitMetadataIDs(metadata["committed_line_ids"])
        )
    }

    private func splitMetadataIDs(_ value: String?) -> [String] {
        value?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }
}
