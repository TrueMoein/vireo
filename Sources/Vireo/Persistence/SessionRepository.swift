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
                latencyMs: latencyMs,
                styleId: result.styleID?.uuidString
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

    /// Delete one session. Cascades to its mistake rows via the FK in
    /// the v1 schema. No-op if the row is already gone.
    func deleteSession(id: Int64) async throws {
        try await database.queue.write { db in
            let count = try Session
                .filter(Column("id") == id)
                .deleteAll(db)
            log.info("Deleted session #\(id, privacy: .public) (\(count, privacy: .public) row\(count == 1 ? "" : "s"))")
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

    /// The most recent mistake matching this (category, rule) — used as
    /// the example in the review session card.
    func latestMistake(category: String, rule: String) async throws -> Mistake? {
        try await database.queue.read { db in
            try Mistake
                .filter(Column("category") == category && Column("rule") == rule)
                .order(Column("id").desc)
                .fetchOne(db)
        }
    }

    /// Total session count — useful for empty-state checks.
    func totalSessionCount() async throws -> Int {
        try await database.queue.read { db in
            try Session.fetchCount(db)
        }
    }

    /// Aggregate all logged mistakes into (category × rule) patterns,
    /// grouped by category and sorted by total count. This is the read
    /// model the Coach surfaces as "your most frequent patterns."
    func categoryPatterns(limit: Int = 100) async throws -> [CategoryPattern] {
        let rows = try await database.queue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT category, rule, COUNT(*) AS cnt
                FROM mistake
                GROUP BY category, rule
                ORDER BY cnt DESC
                LIMIT ?
            """, arguments: [limit])
        }

        var groups: [String: [RulePattern]] = [:]
        for row in rows {
            let category: String = row["category"]
            let rule: String = row["rule"]
            let count: Int = row["cnt"]
            groups[category, default: []].append(RulePattern(rule: rule, count: count))
        }

        return groups.map { (category, rules) in
            CategoryPattern(
                category: category,
                totalCount: rules.reduce(0) { $0 + $1.count },
                rules: rules.sorted { $0.count > $1.count }
            )
        }
        .sorted { $0.totalCount > $1.totalCount }
    }

    // MARK: - Weakness items

    /// All weakness items, grouped by state and sorted by recurrence.
    func weaknessItems() async throws -> [WeaknessItem] {
        try await database.queue.read { db in
            try WeaknessItem
                .order(Column("occurrence_count").desc, Column("last_seen").desc)
                .fetchAll(db)
        }
    }

    /// Active items whose due_at has passed.
    func dueWeaknessItems(now: Date = Date()) async throws -> [WeaknessItem] {
        try await database.queue.read { db in
            try WeaknessItem
                .filter(Column("state") == WeaknessState.active.rawValue)
                .filter(Column("due_at") != nil && Column("due_at") <= now.timeIntervalSinceReferenceDate)
                .order(Column("due_at"))
                .fetchAll(db)
        }
    }

    /// Counts for the Coach summary card: total active, due now, watching.
    func weaknessSummary(now: Date = Date()) async throws -> WeaknessSummary {
        try await database.queue.read { db in
            let active = try WeaknessItem
                .filter(Column("state") == WeaknessState.active.rawValue)
                .fetchCount(db)
            let watching = try WeaknessItem
                .filter(Column("state") == WeaknessState.watching.rawValue)
                .fetchCount(db)
            let mastered = try WeaknessItem
                .filter(Column("state") == WeaknessState.mastered.rawValue)
                .fetchCount(db)
            let due = try WeaknessItem
                .filter(Column("state") == WeaknessState.active.rawValue)
                .filter(Column("due_at") != nil && Column("due_at") <= now.timeIntervalSinceReferenceDate)
                .fetchCount(db)
            return WeaknessSummary(active: active, watching: watching, mastered: mastered, dueNow: due)
        }
    }

    enum RepositoryError: Error {
        case insertFailed
    }
}

/// Coach summary surfaced on the Patterns tab.
struct WeaknessSummary: Sendable, Hashable {
    let active: Int
    let watching: Int
    let mastered: Int
    let dueNow: Int
}

/// One mistake category with its recurring rules, ranked by recurrence.
struct CategoryPattern: Identifiable, Sendable, Hashable {
    var id: String { category }
    let category: String
    let totalCount: Int
    let rules: [RulePattern]
}

/// One specific rule the user keeps tripping on, with the number of times
/// it's been corrected.
struct RulePattern: Identifiable, Hashable, Sendable {
    let rule: String
    let count: Int
    var id: String { rule }
}
