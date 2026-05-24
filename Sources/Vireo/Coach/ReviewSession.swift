// ReviewSession.swift — state machine for a single review run.
//
// Loads all due weakness items + an example mistake for each, advances
// through them one at a time as the user rates each, then triggers a
// store reload so the Patterns + History tabs reflect the new schedules.

import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "co.vireo", category: "ReviewSession")

@MainActor
final class ReviewSession: ObservableObject {
    @Published private(set) var queue: [Item] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isComplete: Bool = false
    @Published private(set) var ratingsTally: [Grade: Int] = [:]

    let tracker: WeaknessTracker
    let repository: SessionRepository
    let store: SessionStore

    struct Item: Identifiable, Sendable, Hashable {
        let weakness: WeaknessItem
        let example: Mistake?
        var id: Int64 { weakness.id ?? 0 }
    }

    init(tracker: WeaknessTracker, repository: SessionRepository, store: SessionStore) {
        self.tracker = tracker
        self.repository = repository
        self.store = store
    }

    func start() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let due = try await repository.dueWeaknessItems()
            var loaded: [Item] = []
            for item in due {
                let example = try? await repository.latestMistake(
                    category: item.category,
                    rule: item.rule
                )
                loaded.append(Item(weakness: item, example: example))
            }
            queue = loaded
            currentIndex = 0
            ratingsTally = [:]
            isComplete = loaded.isEmpty
        } catch {
            log.error("start failed: \(error.localizedDescription, privacy: .public)")
            queue = []
            isComplete = true
        }
    }

    var current: Item? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var totalCount: Int { queue.count }
    var currentNumber: Int { currentIndex + 1 }

    func rate(_ grade: Grade) async {
        guard let current, let id = current.weakness.id else { return }
        do {
            try await tracker.rate(itemId: id, grade: grade)
            ratingsTally[grade, default: 0] += 1
        } catch {
            log.error("rate failed: \(error.localizedDescription, privacy: .public)")
        }
        if currentIndex + 1 >= queue.count {
            isComplete = true
            await store.reload()
        } else {
            currentIndex += 1
        }
    }
}
