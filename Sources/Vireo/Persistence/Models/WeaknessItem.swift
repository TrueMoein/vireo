// WeaknessItem.swift — one tracked (category, rule) pattern with
// occurrence + spaced-repetition state.
//
// State machine:
//   .watching (default) — under threshold (count < 3), just counting
//   .active             — promoted; in the review queue with a due date
//   .mastered           — graduated out of active review

import Foundation
import GRDB

struct WeaknessItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: Int64?
    let category: String
    let rule: String
    var occurrenceCount: Int
    let firstSeen: Date
    var lastSeen: Date
    var state: WeaknessState
    /// SM-2-inspired ease factor. Default 2.5; clamped [1.3, 3.0].
    var ease: Double
    /// Current interval in days between reviews.
    var intervalDays: Double
    /// When the next review is due. Nil for .watching items.
    var dueAt: Date?
    /// When this item was last manually reviewed (rated). Nil if never.
    var lastReviewed: Date?
    /// Number of manual reviews completed.
    var reviewCount: Int
    /// Number of times the user has rated this .again (forgotten).
    var lapseCount: Int

    static let promotionThreshold = 3
}

enum WeaknessState: Int, Codable, Sendable, Hashable {
    case watching = 0
    case active = 1
    case mastered = 2
}

extension WeaknessItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "weakness_item"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
