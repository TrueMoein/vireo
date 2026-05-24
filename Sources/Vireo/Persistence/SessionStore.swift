// SessionStore.swift — @MainActor ObservableObject bridge between SwiftUI
// and the SessionRepository actor. Holds the current History tab state.

import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "co.vireo", category: "SessionStore")

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var totalCount: Int = 0

    let repository: SessionRepository?
    /// True when the database failed to open at app launch; History tab
    /// can use this to show a clean error state instead of an empty list.
    let unavailable: Bool

    init(repository: SessionRepository?) {
        self.repository = repository
        self.unavailable = repository == nil
    }

    /// Refresh the list. If `search` is empty, returns the most recent.
    /// Otherwise filters via SessionRepository.search.
    func reload(search: String = "") async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = search.isEmpty
                ? try await repository.recentSessions()
                : try await repository.search(search)
            totalCount = try await repository.totalSessionCount()
        } catch {
            log.error("reload failed: \(error.localizedDescription, privacy: .public)")
            sessions = []
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
