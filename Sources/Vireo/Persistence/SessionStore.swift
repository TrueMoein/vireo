// SessionStore.swift — @MainActor ObservableObject bridge between SwiftUI
// and the SessionRepository actor. Holds the current History tab state.

import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "co.vireo", category: "SessionStore")

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var patterns: [CategoryPattern] = []
    @Published private(set) var weaknessSummary: WeaknessSummary = WeaknessSummary(active: 0, watching: 0, mastered: 0, dueNow: 0)
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var totalCount: Int = 0

    let repository: SessionRepository?
    let weaknessTracker: WeaknessTracker?
    /// True when the database failed to open at app launch; tabs can use
    /// this to show a clean error state instead of an empty list.
    let unavailable: Bool

    init(repository: SessionRepository?, weaknessTracker: WeaknessTracker? = nil) {
        self.repository = repository
        self.weaknessTracker = weaknessTracker
        self.unavailable = repository == nil
    }

    /// Refresh the session list + total count + weakness patterns. If
    /// `search` is empty, returns the most recent.
    func reload(search: String = "") async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = search.isEmpty
                ? try await repository.recentSessions()
                : try await repository.search(search)
            totalCount = try await repository.totalSessionCount()
            patterns = try await repository.categoryPatterns()
            weaknessSummary = try await repository.weaknessSummary()
        } catch {
            log.error("reload failed: \(error.localizedDescription, privacy: .public)")
            sessions = []
        }
    }

    /// Refresh only the patterns + weakness summary (PatternsTab appearance).
    func reloadPatterns() async {
        guard let repository else { return }
        do {
            patterns = try await repository.categoryPatterns()
            weaknessSummary = try await repository.weaknessSummary()
        } catch {
            log.error("reloadPatterns failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func mistakes(for session: Session) async -> [Mistake] {
        guard let repository, let id = session.id else { return [] }
        do {
            return try await repository.mistakes(forSession: id)
        } catch {
            log.error("mistakes(forSession:) failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
