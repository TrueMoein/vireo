// WeaknessTracker.swift — incremental tracker that consumes correction
// results and updates the weakness_item table.
//
// For each mistake in a correction:
//   1. Find-or-insert weakness_item by (category, rule).
//   2. Increment occurrence_count, update last_seen.
//   3. If count crosses the promotion threshold, promote to .active and
//      initialize scheduler state (ease, interval, due_at).

import Foundation
import GRDB
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "WeaknessTracker")

actor WeaknessTracker {
    private let database: Database

    init(database: Database) {
        self.database = database
    }

    /// Process all mistakes from a correction result, updating or inserting
    /// weakness items as needed. Idempotent per call: callers should pass
    /// each result exactly once.
    func ingest(result: CorrectionResult) async throws {
        guard !result.mistakes.isEmpty else { return }
        try await database.queue.write { db in
            for m in result.mistakes {
                try Self.upsert(
                    db: db,
                    category: m.category.rawValue,
                    rule: m.rule
                )
            }
        }
    }

    /// Apply a user rating to one weakness item — updates the SM-2-style
    /// scheduler state and persists.
    func rate(itemId: Int64, grade: Grade, now: Date = Date()) async throws {
        try await database.queue.write { db in
            guard var item = try WeaknessItem.fetchOne(db, key: itemId) else { return }
            let result = SpacedRepetition.apply(
                grade: grade,
                ease: item.ease,
                intervalDays: item.intervalDays,
                lapses: item.lapseCount,
                now: now
            )
            item.ease = result.ease
            item.intervalDays = result.intervalDays
            item.dueAt = result.dueAt
            item.lapseCount = result.lapses
            item.lastReviewed = now
            item.reviewCount += 1
            try item.update(db)
            log.info("Rated #\(itemId, privacy: .public) → next due in \(result.intervalDays, privacy: .public)d")
        }
    }

    /// Update (or insert) one weakness item. Promotes from .watching to
    /// .active when the occurrence count crosses the threshold.
    private static func upsert(db: GRDB.Database, category: String, rule: String) throws {
        let now = Date()

        let existing = try WeaknessItem
            .filter(Column("category") == category && Column("rule") == rule)
            .fetchOne(db)

        if var item = existing {
            item.occurrenceCount += 1
            item.lastSeen = now

            // Promote if we just crossed the threshold and are still .watching.
            if item.state == .watching, item.occurrenceCount >= WeaknessItem.promotionThreshold {
                item.state = .active
                let s = SpacedRepetition.initialState(now: now)
                item.ease = s.ease
                item.intervalDays = s.intervalDays
                item.dueAt = s.dueAt
                log.info("Promoted weakness: \(category, privacy: .public) · \(rule.prefix(60), privacy: .public)")
            }
            try item.update(db)
        } else {
            var item = WeaknessItem(
                id: nil,
                category: category,
                rule: rule,
                occurrenceCount: 1,
                firstSeen: now,
                lastSeen: now,
                state: .watching,
                ease: 2.5,
                intervalDays: 0,
                dueAt: nil,
                lastReviewed: nil,
                reviewCount: 0,
                lapseCount: 0
            )
            try item.insert(db)
        }
    }
}
