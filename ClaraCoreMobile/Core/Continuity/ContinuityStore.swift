import Foundation
import GRDB

final class ContinuityStore {
    private let database: AppDatabase
    private let dateFormatter = ISO8601DateFormatter()

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func create(title: String, lastPosition: String, nextStep: String?, contextCardId: String? = nil) throws -> ContinuityLine {
        let now = Date()
        let line = ContinuityLine(
            id: UUID().uuidString,
            title: title,
            lastPosition: lastPosition,
            nextStep: nextStep,
            contextCardId: contextCardId,
            status: .active,
            createdAt: now,
            updatedAt: now
        )

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO continuity_lines (
                    id, title, last_position, next_step, context_card_id, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    line.id,
                    line.title,
                    line.lastPosition,
                    line.nextStep,
                    line.contextCardId,
                    line.status.rawValue,
                    dateFormatter.string(from: line.createdAt),
                    dateFormatter.string(from: line.updatedAt)
                ]
            )
        }

        return line
    }

    func active(limit: Int = 50, contextCardId: String? = nil) throws -> [ContinuityLine] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM continuity_lines
                WHERE status = ?
                  AND (? IS NULL OR context_card_id = ?)
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                arguments: [ContinuityLine.Status.active.rawValue, contextCardId, contextCardId, limit]
            )

            return rows.map(line(from:))
        }
    }

    func update(id: String, title: String, lastPosition: String, nextStep: String?) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPosition = lastPosition.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNextStep = nextStep?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedPosition.isEmpty else { return }

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE continuity_lines
                SET title = ?, last_position = ?, next_step = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    trimmedTitle,
                    trimmedPosition,
                    trimmedNextStep?.isEmpty == true ? nil : trimmedNextStep,
                    dateFormatter.string(from: Date()),
                    id
                ]
            )
        }
    }

    func archive(id: String) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE continuity_lines SET status = ?, updated_at = ? WHERE id = ?",
                arguments: [
                    ContinuityLine.Status.archived.rawValue,
                    dateFormatter.string(from: Date()),
                    id
                ]
            )
        }
    }

    func delete(id: String) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE memories SET line_id = NULL, updated_at = ? WHERE line_id = ?",
                arguments: [dateFormatter.string(from: Date()), id]
            )
            try db.execute(sql: "DELETE FROM continuity_lines WHERE id = ?", arguments: [id])
        }
    }

    private func line(from row: Row) -> ContinuityLine {
        let statusValue: String = row["status"]
        let createdAtString: String = row["created_at"]
        let updatedAtString: String = row["updated_at"]

        return ContinuityLine(
            id: row["id"],
            title: row["title"],
            lastPosition: row["last_position"],
            nextStep: row["next_step"],
            contextCardId: row["context_card_id"],
            status: ContinuityLine.Status(rawValue: statusValue) ?? .active,
            createdAt: dateFormatter.date(from: createdAtString) ?? Date(),
            updatedAt: dateFormatter.date(from: updatedAtString) ?? Date()
        )
    }
}
