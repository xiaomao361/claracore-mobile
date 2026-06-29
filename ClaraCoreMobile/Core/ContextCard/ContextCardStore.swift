import Foundation
import GRDB

final class ContextCardStore {
    static let defaultCardID = "default-context-card"
    static let defaultTitle = "默认角色卡"
    static let defaultAgentProfile = "你是一个帮助用户延续跨应用对话上下文的助手。"
    static let defaultUserProfile = "用户希望你基于共同线和事实记忆继续，不要假设未提供的信息；如果信息不足，先指出缺口。"

    private let database: AppDatabase
    private let dateFormatter = ISO8601DateFormatter()

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func defaultCard() throws -> ContextCard {
        if let existing = try get(id: Self.defaultCardID) {
            return existing
        }

        return try create(
            id: Self.defaultCardID,
            title: Self.defaultTitle,
            agentProfile: Self.defaultAgentProfile,
            userProfile: Self.defaultUserProfile
        )
    }

    func get(id: String) throws -> ContextCard? {
        try database.dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM context_cards WHERE id = ?", arguments: [id]) else {
                return nil
            }
            return card(from: row)
        }
    }

    func update(id: String, title: String, agentProfile: String, userProfile: String) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAgentProfile = agentProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserProfile = userProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedAgentProfile.isEmpty, !trimmedUserProfile.isEmpty else { return }

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE context_cards
                SET title = ?, agent_profile = ?, user_profile = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    trimmedTitle,
                    trimmedAgentProfile,
                    trimmedUserProfile,
                    dateFormatter.string(from: Date()),
                    id
                ]
            )
        }
    }

    private func create(id: String, title: String, agentProfile: String, userProfile: String) throws -> ContextCard {
        let now = Date()
        let card = ContextCard(
            id: id,
            title: title,
            agentProfile: agentProfile,
            userProfile: userProfile,
            createdAt: now,
            updatedAt: now
        )

        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO context_cards (
                    id, title, agent_profile, user_profile, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    card.id,
                    card.title,
                    card.agentProfile,
                    card.userProfile,
                    dateFormatter.string(from: card.createdAt),
                    dateFormatter.string(from: card.updatedAt)
                ]
            )
        }

        return card
    }

    private func card(from row: Row) -> ContextCard {
        let createdAtString: String = row["created_at"]
        let updatedAtString: String = row["updated_at"]

        return ContextCard(
            id: row["id"],
            title: row["title"],
            agentProfile: row["agent_profile"],
            userProfile: row["user_profile"],
            createdAt: dateFormatter.date(from: createdAtString) ?? Date(),
            updatedAt: dateFormatter.date(from: updatedAtString) ?? Date()
        )
    }
}
