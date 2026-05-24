// SessionRepository.swift — actor-isolated wrapper over GRDB Database that
// owns all sessions+mistakes reads/writes.
//
// All access through this type so concurrency rules are explicit:
// reads can interleave, writes serialize, and the SwiftUI side never
// touches a DatabaseQueue directly.

import Foundation
import GRDB
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "SessionRepo")

actor SessionRepository {
    private let database: Database

    init(database: Database) {
        self.database = database
    }

    /// Persist one correction: the source text, the model's output, and the
    /// per-mistake breakdown. Returns the new session id.
    @discardableResult
    func save(
        rawText: String,
        result: CorrectionResult,
        sourceApp: String?,
        model: String?,
        latencyMs: Int?
    ) async throws -> Int64 {
        try await database.queue.write { db in
            var session = Session(
                id: nil,
                timestamp: Date(),
                sourceApp: sourceApp,
                rawText: rawText,
                correctedText: result.correctedText,
                llmProvider: "openrouter",
                model: model,
                latencyMs: latencyMs
            )
            try session.insert(db)
            guard let sessionId = session.id else {
                throw RepositoryError.insertFailed
            }

            for m in result.mistakes {
                var dbMistake = Mistake(
                    id: nil,
                    sessionId: sessionId,
                    originalPhrase: m.original,
                    fixedPhrase: m.fixed,
                    category: m.category.rawValue,
                    rule: m.rule,
                    explanation: m.explanation
                )
                try dbMistake.insert(db)
            }
            log.info("Saved session #\(sessionId, privacy: .public) with \(result.mistakes.count, privacy: .public) mistakes")
            return sessionId
        }
    }

    /// Latest sessions, newest first.
    func recentSessions(limit: Int = 100) async throws -> [Session] {
        try await database.queue.read { db in
            try Session
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Sessions matching a free-text query (simple LIKE on raw + corrected).
    /// FTS5 search will replace this in the next stage.
    func search(_ query: String, limit: Int = 100) async throws -> [Session] {
        let pattern = "%\(query)%"
        return try await database.queue.read { db in
            try Session
                .filter(Column("corrected_text").like(pattern) || Column("raw_text").like(pattern))
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// All mistakes for a session, in insertion order.
    func mistakes(forSession sessionId: Int64) async throws -> [Mistake] {
        try await database.queue.read { db in
            try Mistake
                .filter(Column("session_id") == sessionId)
                .order(Column("id"))
                .fetchAll(db)
        }
    }

    /// Total session count — useful for empty-state checks.
    func totalSessionCount() async throws -> Int {
        try await database.queue.read { db in
            try Session.fetchCount(db)
        }
    }

    enum RepositoryError: Error {
        case insertFailed
    }
}
