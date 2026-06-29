import Foundation
import GRDB

final class MemoriaStore {
    private let database: AppDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let dateFormatter = ISO8601DateFormatter()

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func store(
        content: String,
        tags: [String],
        isPrivate: Bool,
        sourceAgent: String? = "mobile",
        lineId: String? = nil
    ) throws -> Memory {
        let now = Date()
        let memory = Memory(
            id: UUID().uuidString,
            content: content,
            tags: tags,
            isPrivate: isPrivate,
            isArchived: false,
            sourceAgent: sourceAgent,
            lineId: lineId,
            createdAt: now,
            updatedAt: now
        )

        let tagsJSON = try String(data: encoder.encode(tags), encoding: .utf8) ?? "[]"
        let createdAt = dateFormatter.string(from: now)

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO memories (
                    id, content, tags, is_private, is_archived, source_agent, line_id, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    memory.id,
                    memory.content,
                    tagsJSON,
                    memory.isPrivate ? 1 : 0,
                    memory.isArchived ? 1 : 0,
                    memory.sourceAgent,
                    memory.lineId,
                    createdAt,
                    createdAt
                ]
            )
        }

        return memory
    }

    func recall(query: String, limit: Int) throws -> [Memory] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let matchExpression = ftsMatchExpression(for: trimmed)

        return try database.dbQueue.read { db in
            let ftsRows = try Row.fetchAll(
                db,
                sql: """
                SELECT memories.*
                FROM memories
                JOIN memories_fts ON memories.rowid = memories_fts.rowid
                WHERE memories_fts MATCH ?
                  AND memories.is_archived = 0
                ORDER BY bm25(memories_fts)
                LIMIT ?
                """,
                arguments: [matchExpression, limit]
            )

            if !ftsRows.isEmpty {
                return try ftsRows.map(memory(from:))
            }

            let fallbackTerms = fallbackSearchTerms(for: trimmed)
            let fallbackConditions = fallbackTerms
                .flatMap { _ in ["content LIKE ?", "tags LIKE ?"] }
                .joined(separator: " OR ")
            let fallbackArguments = fallbackTerms.flatMap { term in
                ["%\(term)%", "%\(term)%"]
            }

            let fallbackRows = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM memories
                WHERE is_archived = 0
                  AND (\(fallbackConditions))
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                arguments: StatementArguments(fallbackArguments + [limit])
            )

            return try fallbackRows.map(memory(from:))
        }
    }

    func recent(limit: Int = 20) throws -> [Memory] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM memories
                WHERE is_archived = 0
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                arguments: [limit]
            )

            return try rows.map(memory(from:))
        }
    }

    func related(toLineId lineId: String, limit: Int = 20) throws -> [Memory] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM memories
                WHERE is_archived = 0
                  AND line_id = ?
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                arguments: [lineId, limit]
            )

            return try rows.map(memory(from:))
        }
    }

    func get(id: String) throws -> Memory? {
        try database.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM memories WHERE id = ?", arguments: [id]) else {
                return nil
            }
            return try memory(from: row)
        }
    }

    func update(id: String, content: String, tags: [String], isPrivate: Bool) throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let tagsJSON = try String(data: encoder.encode(tags), encoding: .utf8) ?? "[]"
        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE memories
                SET content = ?, tags = ?, is_private = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    trimmed,
                    tagsJSON,
                    isPrivate ? 1 : 0,
                    dateFormatter.string(from: Date()),
                    id
                ]
            )
        }
    }

    func delete(id: String) throws {
        try database.dbQueue.write { db in
            try db.execute(sql: "UPDATE memories SET is_archived = 1, updated_at = ? WHERE id = ?", arguments: [
                dateFormatter.string(from: Date()),
                id
            ])
        }
    }

    func restore(id: String) throws {
        try database.dbQueue.write { db in
            try db.execute(sql: "UPDATE memories SET is_archived = 0, updated_at = ? WHERE id = ?", arguments: [
                dateFormatter.string(from: Date()),
                id
            ])
        }
    }

    private func memory(from row: Row) throws -> Memory {
        let tagsJSON: String = row["tags"]
        let createdAtString: String = row["created_at"]
        let updatedAtString: String = row["updated_at"]
        let isPrivate: Int64 = row["is_private"]
        let isArchived: Int64 = row["is_archived"]

        let tagsData = tagsJSON.data(using: .utf8) ?? Data()
        let tags = (try? decoder.decode([String].self, from: tagsData)) ?? []
        let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        let updatedAt = dateFormatter.date(from: updatedAtString) ?? createdAt

        return Memory(
            id: row["id"],
            content: row["content"],
            tags: tags,
            isPrivate: isPrivate != 0,
            isArchived: isArchived != 0,
            sourceAgent: row["source_agent"],
            lineId: row["line_id"],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func ftsMatchExpression(for query: String) -> String {
        query
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            .joined(separator: " OR ")
    }

    private func fallbackSearchTerms(for query: String) -> [String] {
        var terms: [String] = []

        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2, !terms.contains(trimmed) else { return }
            terms.append(trimmed)
        }

        append(query)

        if let regex = try? NSRegularExpression(pattern: #"[A-Za-z0-9_+-]{2,}"#) {
            let range = NSRange(query.startIndex..<query.endIndex, in: query)
            regex.matches(in: query, range: range).forEach { match in
                guard let swiftRange = Range(match.range, in: query) else { return }
                append(String(query[swiftRange]))
            }
        }

        query
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .forEach(append)

        return terms.isEmpty ? [query] : terms
    }
}
