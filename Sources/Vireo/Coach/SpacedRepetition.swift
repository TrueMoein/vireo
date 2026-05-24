// SpacedRepetition.swift — simple SM-2-inspired scheduler.
//
// Why not swift-fsrs: its `repeat` / `next` / `reschedule` methods are
// `internal`-scoped; only tests in the same module can call them with
// `@testable import FSRS`. Rather than fork the library or write
// `@testable` into a release target, we ship our own clean SM-2 variant.
// It's well-understood, easy to verify, and the algorithm choice is hidden
// behind a thin protocol so we can swap to FSRS-6 later if its API opens up.
//
// Ratings:
//   .again — forgot completely → reset interval, ease -= 0.2, lapses += 1
//   .hard  — got it but struggled → ease -= 0.15, interval *= 1.2 (min 1)
//   .good  — recalled normally → interval *= ease
//   .easy  — recalled effortlessly → ease += 0.15, interval *= ease * 1.3
//
// Ease is clamped to [1.3, 3.0]. Initial ease 2.5, initial interval 1 day.

import Foundation

enum Grade: Sendable, Hashable {
    case again
    case hard
    case good
    case easy
}

enum SpacedRepetition {
    /// Initialize a fresh card. Used when a weakness gets promoted to .active
    /// for the first time. Initial dueAt = now so newly-promoted items
    /// immediately surface in the review queue; subsequent intervals are
    /// computed by `apply` based on the user's rating.
    static func initialState(now: Date = Date()) -> (ease: Double, intervalDays: Double, dueAt: Date) {
        return (ease: 2.5, intervalDays: 0, dueAt: now)
    }

    /// Apply a rating to existing scheduler state and return the new state +
    /// next due date.
    static func apply(
        grade: Grade,
        ease currentEase: Double,
        intervalDays currentInterval: Double,
        lapses currentLapses: Int,
        now: Date = Date()
    ) -> (ease: Double, intervalDays: Double, dueAt: Date, lapses: Int) {
        var ease = currentEase
        var interval = currentInterval
        var lapses = currentLapses

        switch grade {
        case .again:
            ease -= 0.2
            interval = 1
            lapses += 1
        case .hard:
            ease -= 0.15
            interval = max(interval * 1.2, 1)
        case .good:
            interval = max(interval * ease, 1)
        case .easy:
            ease += 0.15
            interval = max(interval * ease * 1.3, 1)
        }

        ease = min(max(ease, 1.3), 3.0)

        return (
            ease: ease,
            intervalDays: interval,
            dueAt: now.addingTimeInterval(interval * 86_400),
            lapses: lapses
        )
    }
}
