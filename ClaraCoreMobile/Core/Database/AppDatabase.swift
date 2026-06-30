import Foundation
import GRDB

struct AppDatabase {
    let dbQueue: DatabaseQueue

    init(path: String? = nil) throws {
        let databasePath = try path ?? Self.defaultDatabasePath()
        dbQueue = try DatabaseQueue(path: databasePath)
        try Self.migrator.migrate(dbQueue)
    }

    private static func defaultDatabasePath() throws -> String {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("ClaraCoreMobile", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("claracore.sqlite").path
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createMemoria") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                tags TEXT NOT NULL DEFAULT '[]',
                is_private INTEGER NOT NULL DEFAULT 0,
                is_archived INTEGER NOT NULL DEFAULT 0,
                source_agent TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
                content,
                tags,
                content='memories',
                content_rowid='rowid'
            );

            CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
                INSERT INTO memories_fts(rowid, content, tags)
                VALUES (new.rowid, new.content, new.tags);
            END;

            CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
                INSERT INTO memories_fts(memories_fts, rowid, content, tags)
                VALUES ('delete', old.rowid, old.content, old.tags);
            END;

            CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
                INSERT INTO memories_fts(memories_fts, rowid, content, tags)
                VALUES ('delete', old.rowid, old.content, old.tags);
                INSERT INTO memories_fts(rowid, content, tags)
                VALUES (new.rowid, new.content, new.tags);
            END;
            """)
        }

        migrator.registerMigration("createInbox") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS inbox (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                raw_content TEXT NOT NULL,
                metadata TEXT NOT NULL DEFAULT '{}',
                status TEXT NOT NULL DEFAULT 'pending',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_inbox_status_created_at
            ON inbox(status, created_at DESC);
            """)
        }

        migrator.registerMigration("addInboxSourceTracking") { db in
            try db.execute(sql: """
            ALTER TABLE inbox ADD COLUMN source_app TEXT;
            ALTER TABLE inbox ADD COLUMN source_thread_id TEXT;
            ALTER TABLE inbox ADD COLUMN content_hash TEXT NOT NULL DEFAULT '';

            CREATE INDEX IF NOT EXISTS idx_inbox_content_hash
            ON inbox(content_hash);

            CREATE INDEX IF NOT EXISTS idx_inbox_source_thread
            ON inbox(source, source_app, source_thread_id, created_at DESC);
            """)
        }

        migrator.registerMigration("createImportSessions") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS import_sessions (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                source_app TEXT,
                source_thread_id TEXT,
                title TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS capture_segments (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                sequence INTEGER NOT NULL,
                content TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                range_start INTEGER NOT NULL,
                range_end INTEGER NOT NULL,
                token_estimate INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (session_id) REFERENCES import_sessions(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_capture_segments_session_sequence
            ON capture_segments(session_id, sequence);

            CREATE INDEX IF NOT EXISTS idx_capture_segments_content_hash
            ON capture_segments(content_hash);
            """)
        }

        migrator.registerMigration("createContinuityLines") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS continuity_lines (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                last_position TEXT NOT NULL,
                next_step TEXT,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_continuity_lines_status_updated_at
            ON continuity_lines(status, updated_at DESC);
            """)
        }

        migrator.registerMigration("createContextCards") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS context_cards (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                agent_profile TEXT NOT NULL,
                user_profile TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_context_cards_updated_at
            ON context_cards(updated_at DESC);
            """)
        }

        migrator.registerMigration("addMemoryLineId") { db in
            try db.execute(sql: """
            ALTER TABLE memories ADD COLUMN line_id TEXT;

            CREATE INDEX IF NOT EXISTS idx_memories_line_id_updated_at
            ON memories(line_id, updated_at DESC);
            """)
        }

        migrator.registerMigration("addContextCardBindings") { db in
            try db.execute(sql: """
            ALTER TABLE memories ADD COLUMN context_card_id TEXT;
            ALTER TABLE continuity_lines ADD COLUMN context_card_id TEXT;
            ALTER TABLE inbox ADD COLUMN context_card_id TEXT;
            ALTER TABLE import_sessions ADD COLUMN context_card_id TEXT;

            CREATE INDEX IF NOT EXISTS idx_memories_context_card_updated_at
            ON memories(context_card_id, updated_at DESC);

            CREATE INDEX IF NOT EXISTS idx_continuity_context_card_updated_at
            ON continuity_lines(context_card_id, updated_at DESC);

            CREATE INDEX IF NOT EXISTS idx_inbox_context_card_status_created_at
            ON inbox(context_card_id, status, created_at DESC);

            CREATE INDEX IF NOT EXISTS idx_import_sessions_context_card_updated_at
            ON import_sessions(context_card_id, updated_at DESC);
            """)
        }

        migrator.registerMigration("addContinuityRichState") { db in
            try db.execute(sql: """
            ALTER TABLE continuity_lines ADD COLUMN state_summary TEXT NOT NULL DEFAULT '';
            ALTER TABLE continuity_lines ADD COLUMN current_interpretation TEXT NOT NULL DEFAULT '';
            ALTER TABLE continuity_lines ADD COLUMN interpretation_status TEXT NOT NULL DEFAULT 'active';
            ALTER TABLE continuity_lines ADD COLUMN emotional_arc TEXT NOT NULL DEFAULT '[]';
            ALTER TABLE continuity_lines ADD COLUMN affective_trace TEXT NOT NULL DEFAULT '[]';
            ALTER TABLE continuity_lines ADD COLUMN reality_line TEXT NOT NULL DEFAULT '';
            ALTER TABLE continuity_lines ADD COLUMN boundary_notes TEXT NOT NULL DEFAULT '';
            ALTER TABLE continuity_lines ADD COLUMN misread_risks TEXT NOT NULL DEFAULT '';

            ALTER TABLE memories ADD COLUMN confidence REAL NOT NULL DEFAULT 1.0;
            ALTER TABLE memories ADD COLUMN importance REAL NOT NULL DEFAULT 0.0;
            """)
        }

        return migrator
    }
}
