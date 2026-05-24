// Database.swift — GRDB connection pool + migrations + FTS5 setup.
//
// Schema (v1):
//   session: id, timestamp, source_app, raw_text, corrected_text,
//            llm_provider, model, latency_ms
//   mistake: id, session_id, original_phrase, fixed_phrase, category,
//            rule, explanation (FK → session.id ON DELETE CASCADE)
//   session_fts: FTS5 virtual table mirroring session.{raw,corrected}_text
//                via content-table sync triggers
//
// Path: ~/Library/Application Support/Vireo/vireo.sqlite

import Foundation
import GRDB
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "Database")

final class Database: Sendable {
    let queue: DatabaseQueue

    init() throws {
        let url = try Self.defaultDatabaseURL()
        var config = Configuration()
        config.label = "co.vireo.db"
        // Foreign keys are on by default in GRDB but be explicit so cascade
        // deletes from session → mistake actually fire.
        config.foreignKeysEnabled = true

        let queue = try DatabaseQueue(path: url.path, configuration: config)
        try Self.migrator.migrate(queue)
        self.queue = queue
        log.info("Database opened at \(url.path, privacy: .public)")
    }

    private static func defaultDatabaseURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let vireoDir = appSupport.appendingPathComponent("Vireo", isDirectory: true)
        try fm.createDirectory(at: vireoDir, withIntermediateDirectories: true)
        return vireoDir.appendingPathComponent("vireo.sqlite")
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "session") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .double).notNull().indexed()
                t.column("source_app", .text)
                t.column("raw_text", .text).notNull()
                t.column("corrected_text", .text).notNull()
                t.column("llm_provider", .text)
                t.column("model", .text)
                t.column("latency_ms", .integer)
            }

            try db.create(table: "mistake") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("session_id", .integer)
                    .notNull()
                    .indexed()
                    .references("session", onDelete: .cascade)
                t.column("original_phrase", .text).notNull()
                t.column("fixed_phrase", .text).notNull()
                t.column("category", .text).notNull().indexed()
                t.column("rule", .text).notNull()
                t.column("explanation", .text).notNull()
            }

            try db.create(virtualTable: "session_fts", using: FTS5()) { t in
                t.synchronize(withTable: "session")
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("raw_text")
                t.column("corrected_text")
            }
        }

        migrator.registerMigration("v2_weakness_items") { db in
            try db.create(table: "weakness_item") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("category", .text).notNull().indexed()
                t.column("rule", .text).notNull()
                t.column("occurrence_count", .integer).notNull().defaults(to: 1)
                t.column("first_seen", .double).notNull()
                t.column("last_seen", .double).notNull()
                // state: 0 = watching (under threshold), 1 = active (in review), 2 = mastered.
                t.column("state", .integer).notNull().defaults(to: 0).indexed()
                // SM-2-inspired scheduler fields (FSRS-6 swap is a v2 refinement
                // once swift-fsrs exposes its scheduling API publicly).
                t.column("ease", .double).notNull().defaults(to: 2.5)
                t.column("interval_days", .double).notNull().defaults(to: 0)
                t.column("due_at", .double)
                t.column("last_reviewed", .double)
                t.column("review_count", .integer).notNull().defaults(to: 0)
                t.column("lapse_count", .integer).notNull().defaults(to: 0)
            }
            try db.create(
                indexOn: "weakness_item",
                columns: ["category", "rule"],
                options: [.unique]
            )
        }

        migrator.registerMigration("v3_session_style") { db in
            try db.alter(table: "session") { t in
                // Stores `CorrectionStyle.id.uuidString` so History rows
                // can show which style produced each correction. Nullable
                // because pre-v3 rows were written without one.
                t.add(column: "style_id", .text)
            }
        }

        return migrator
    }
}
