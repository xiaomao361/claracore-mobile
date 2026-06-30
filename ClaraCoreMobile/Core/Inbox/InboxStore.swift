import Foundation
import GRDB

final class InboxStore {
    private let database: AppDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let dateFormatter = ISO8601DateFormatter()

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func enqueue(_ capture: RawCapture) throws -> InboxItem {
        let now = Date()
        let item = InboxItem(
            id: capture.id,
            source: capture.source,
            sourceApp: capture.sourceApp,
            sourceThreadId: capture.sourceThreadId,
            contextCardId: capture.contextCardId,
            contentHash: capture.contentHash,
            rawContent: capture.rawContent,
            metadata: capture.metadata,
            status: .pending,
            createdAt: capture.createdAt,
            updatedAt: now
        )

        let metadataJSON = try String(data: encoder.encode(capture.metadata), encoding: .utf8) ?? "{}"

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO inbox (
                    id, source, source_app, source_thread_id, context_card_id, content_hash,
                    raw_content, metadata, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    item.id,
                    item.source.rawValue,
                    item.sourceApp,
                    item.sourceThreadId,
                    item.contextCardId,
                    item.contentHash,
                    item.rawContent,
                    metadataJSON,
                    item.status.rawValue,
                    dateFormatter.string(from: item.createdAt),
                    dateFormatter.string(from: item.updatedAt)
                ]
            )
        }

        return item
    }

    func pending(limit: Int = 50) throws -> [InboxItem] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM inbox
                WHERE status = ?
                ORDER BY created_at DESC
                LIMIT ?
                """,
                arguments: [InboxItem.Status.pending.rawValue, limit]
            )

            return rows.map(item(from:))
        }
    }

    func existing(contentHash: String, sourceApp: String?, sourceThreadId: String?) throws -> InboxItem? {
        try database.dbQueue.read { db in
            let row: Row?
            if let sourceApp, let sourceThreadId {
                row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT *
                    FROM inbox
                    WHERE content_hash = ?
                       OR (source_app = ? AND source_thread_id = ?)
                    ORDER BY created_at DESC
                    LIMIT 1
                    """,
                    arguments: [contentHash, sourceApp, sourceThreadId]
                )
            } else {
                row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT *
                    FROM inbox
                    WHERE content_hash = ?
                    ORDER BY created_at DESC
                    LIMIT 1
                    """,
                    arguments: [contentHash]
                )
            }

            return row.map(item(from:))
        }
    }

    func updateStatus(id: String, status: InboxItem.Status) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE inbox SET status = ?, updated_at = ? WHERE id = ?",
                arguments: [status.rawValue, dateFormatter.string(from: Date()), id]
            )
        }
    }

    func updateCommitResult(id: String, memoryIds: [String], lineIds: [String]) throws {
        try database.dbQueue.write { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT metadata FROM inbox WHERE id = ?", arguments: [id]) else {
                return
            }
            let metadataJSON: String = row["metadata"]
            let metadataData = metadataJSON.data(using: .utf8) ?? Data()
            var metadata = (try? decoder.decode([String: String].self, from: metadataData)) ?? [:]
            metadata["committed_memory_ids"] = memoryIds.joined(separator: ",")
            metadata["committed_line_ids"] = lineIds.joined(separator: ",")
            let updatedMetadataJSON = try String(data: encoder.encode(metadata), encoding: .utf8) ?? "{}"

            try db.execute(
                sql: "UPDATE inbox SET metadata = ?, updated_at = ? WHERE id = ?",
                arguments: [updatedMetadataJSON, dateFormatter.string(from: Date()), id]
            )
        }
    }

    private func item(from row: Row) -> InboxItem {
        let sourceValue: String = row["source"]
        let metadataJSON: String = row["metadata"]
        let statusValue: String = row["status"]
        let createdAtString: String = row["created_at"]
        let updatedAtString: String = row["updated_at"]

        let metadataData = metadataJSON.data(using: .utf8) ?? Data()
        let metadata = (try? decoder.decode([String: String].self, from: metadataData)) ?? [:]

        return InboxItem(
            id: row["id"],
            source: RawCapture.Source(rawValue: sourceValue) ?? .manual,
            sourceApp: row["source_app"],
            sourceThreadId: row["source_thread_id"],
            contextCardId: row["context_card_id"],
            contentHash: row["content_hash"],
            rawContent: row["raw_content"],
            metadata: metadata,
            status: InboxItem.Status(rawValue: statusValue) ?? .pending,
            createdAt: dateFormatter.date(from: createdAtString) ?? Date(),
            updatedAt: dateFormatter.date(from: updatedAtString) ?? Date()
        )
    }
}
