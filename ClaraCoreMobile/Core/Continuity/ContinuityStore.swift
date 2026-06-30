import Foundation
import GRDB

final class ContinuityStore {
    private let database: AppDatabase
    private let dateFormatter = ISO8601DateFormatter()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func create(
        title: String,
        lastPosition: String,
        nextStep: String?,
        contextCardId: String? = nil,
        stateSummary: String = "",
        currentInterpretation: String = "",
        interpretationStatus: String = "active",
        emotionalArc: [String] = [],
        affectiveTrace: [AffectiveTraceNode] = [],
        realityLine: String = "",
        boundaryNotes: String = "",
        misreadRisks: String = ""
    ) throws -> ContinuityLine {
        let now = Date()
        let compactedLastPosition = compactedPosition(lastPosition)
        let line = ContinuityLine(
            id: UUID().uuidString,
            title: title,
            lastPosition: compactedLastPosition,
            nextStep: nextStep,
            contextCardId: contextCardId,
            stateSummary: stateSummary,
            currentInterpretation: currentInterpretation,
            interpretationStatus: interpretationStatus,
            emotionalArc: emotionalArc,
            affectiveTrace: affectiveTrace,
            realityLine: realityLine,
            boundaryNotes: boundaryNotes,
            misreadRisks: misreadRisks,
            status: .active,
            createdAt: now,
            updatedAt: now
        )
        let emotionalArcJSON = try jsonString(emotionalArc)
        let affectiveTraceJSON = try jsonString(affectiveTrace)

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO continuity_lines (
                    id, title, last_position, next_step, context_card_id,
                    state_summary, current_interpretation, interpretation_status,
                    emotional_arc, affective_trace, reality_line, boundary_notes, misread_risks,
                    status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    line.id,
                    line.title,
                    compactedLastPosition,
                    line.nextStep,
                    line.contextCardId,
                    line.stateSummary,
                    line.currentInterpretation,
                    line.interpretationStatus,
                    emotionalArcJSON,
                    affectiveTraceJSON,
                    line.realityLine,
                    line.boundaryNotes,
                    line.misreadRisks,
                    line.status.rawValue,
                    dateFormatter.string(from: line.createdAt),
                    dateFormatter.string(from: line.updatedAt)
                ]
            )
        }

        return line
    }

    func active(limit: Int = 50, offset: Int = 0, contextCardId: String? = nil) throws -> [ContinuityLine] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM continuity_lines
                WHERE status = ?
                  AND (? IS NULL OR context_card_id = ?)
                ORDER BY updated_at DESC, created_at DESC, id DESC
                LIMIT ? OFFSET ?
                """,
                arguments: [ContinuityLine.Status.active.rawValue, contextCardId, contextCardId, limit, offset]
            )

            return rows.map(line(from:))
        }
    }

    func get(id: String) throws -> ContinuityLine? {
        try database.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM continuity_lines WHERE id = ?", arguments: [id]) else {
                return nil
            }
            return line(from: row)
        }
    }

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        try String(data: encoder.encode(value), encoding: .utf8) ?? "[]"
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from value: String) -> T? {
        guard let data = value.data(using: .utf8) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func update(id: String, title: String, lastPosition: String, nextStep: String?) throws {
        try update(
            id: id,
            title: title,
            lastPosition: lastPosition,
            nextStep: nextStep,
            stateSummary: nil,
            currentInterpretation: nil,
            interpretationStatus: nil,
            emotionalArc: nil,
            affectiveTrace: nil,
            realityLine: nil,
            boundaryNotes: nil,
            misreadRisks: nil
        )
    }

    func update(
        id: String,
        title: String,
        lastPosition: String,
        nextStep: String?,
        stateSummary: String?,
        currentInterpretation: String?,
        interpretationStatus: String?,
        emotionalArc: [String]?,
        affectiveTrace: [AffectiveTraceNode]?,
        realityLine: String?,
        boundaryNotes: String?,
        misreadRisks: String?
    ) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPosition = compactedPosition(lastPosition)
        let trimmedNextStep = nextStep?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedPosition.isEmpty else { return }

        let emotionalArcJSON = try emotionalArc.map(jsonString)
        let affectiveTraceJSON = try affectiveTrace.map(jsonString)

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE continuity_lines
                SET title = ?,
                    last_position = ?,
                    next_step = ?,
                    state_summary = COALESCE(?, state_summary),
                    current_interpretation = COALESCE(?, current_interpretation),
                    interpretation_status = COALESCE(?, interpretation_status),
                    emotional_arc = COALESCE(?, emotional_arc),
                    affective_trace = COALESCE(?, affective_trace),
                    reality_line = COALESCE(?, reality_line),
                    boundary_notes = COALESCE(?, boundary_notes),
                    misread_risks = COALESCE(?, misread_risks),
                    updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    trimmedTitle,
                    trimmedPosition,
                    trimmedNextStep?.isEmpty == true ? nil : trimmedNextStep,
                    stateSummary,
                    currentInterpretation,
                    interpretationStatus,
                    emotionalArcJSON,
                    affectiveTraceJSON,
                    realityLine,
                    boundaryNotes,
                    misreadRisks,
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
            stateSummary: row["state_summary"],
            currentInterpretation: row["current_interpretation"],
            interpretationStatus: row["interpretation_status"],
            emotionalArc: decodeJSON([String].self, from: row["emotional_arc"]) ?? [],
            affectiveTrace: decodeJSON([AffectiveTraceNode].self, from: row["affective_trace"]) ?? [],
            realityLine: row["reality_line"],
            boundaryNotes: row["boundary_notes"],
            misreadRisks: row["misread_risks"],
            status: ContinuityLine.Status(rawValue: statusValue) ?? .active,
            createdAt: dateFormatter.date(from: createdAtString) ?? Date(),
            updatedAt: dateFormatter.date(from: updatedAtString) ?? Date()
        )
    }

    private func compactedPosition(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count > 8 {
            let kept = lines.suffix(8)
            return (["较早 \(lines.count - kept.count) 个节点已压缩。"] + kept).joined(separator: "\n")
        }

        if trimmed.count > 1_600 {
            let suffix = String(trimmed.suffix(1_400)).trimmingCharacters(in: .whitespacesAndNewlines)
            return "较早内容已压缩。\n\(suffix)"
        }

        return trimmed
    }
}
