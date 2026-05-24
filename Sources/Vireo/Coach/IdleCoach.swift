// IdleCoach.swift — ambient coach that surfaces one due drill into the
// notch when the user has been idle and has at least one weakness item
// scheduled for review.
//
// Policy:
//   • Poll every `pollInterval` (default 10s).
//   • Only show when idleTime ≥ `minIdleSeconds` (default 30s).
//   • Only show when the notch is currently idle/popover — never disturb
//     an in-progress correction, busy, message, or first-launch card.
//   • At most one card per `minPromptInterval` (default 30 minutes), so
//     dismissing/rating doesn't trigger another prompt immediately.
//   • Skip if API key is missing (drill can't generate).
//
// Idle time comes from `CGEventSourceSecondsSinceLastEventType`, which
// counts seconds since the last keyboard/mouse event. It's the standard
// macOS idle source and respects screen-locked / Do Not Disturb states
// implicitly (no events come through when locked).

import AppKit
import CoreGraphics
import Foundation
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "IdleCoach")

@MainActor
final class IdleCoach: ObservableObject {
    static let pollInterval: Duration = .seconds(10)
    static let minIdleSeconds: TimeInterval = 30
    static let minPromptInterval: TimeInterval = 30 * 60  // 30 minutes

    @Published private(set) var isEnabled: Bool

    private let settings: SettingsModel
    private let repository: SessionRepository?
    private let presenter: NotchPresenter
    private let model: NotchModel

    private var pollingTask: Task<Void, Never>?
    private var lastPromptedAt: Date = .distantPast

    private static let enabledDefaultsKey = "co.vireo.idleCoachEnabled"

    init(
        settings: SettingsModel,
        repository: SessionRepository?,
        presenter: NotchPresenter
    ) {
        self.settings = settings
        self.repository = repository
        self.presenter = presenter
        self.model = presenter.model
        self.isEnabled = UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true
    }

    func start() {
        guard pollingTask == nil, isEnabled else { return }
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled, let self else { return }
                await self.tick()
            }
        }
        log.info("IdleCoach started")
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if enabled {
            start()
        } else {
            stop()
        }
    }

    /// Force-show a notch review immediately, bypassing the idle gate and
    /// the rate-limit window. Used by the "Test now" button in Settings so
    /// the user can validate the feature without waiting.
    func triggerNow() async {
        guard let repo = repository else { return }
        do {
            let items = try await repo.dueWeaknessItems()
            guard let due = items.first else {
                await presenter.showMessage(.info(
                    "Nothing due to review",
                    detail: "Patterns become active after 3 recurrences. Make a few more corrections."
                ))
                return
            }
            let example = try? await repo.latestMistake(
                category: due.category,
                rule: due.rule
            )
            lastPromptedAt = Date()
            await presenter.showReview(NotchReviewPayload(item: due, example: example))
        } catch {
            log.error("triggerNow failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Called periodically. Returns early on every gating condition; only
    /// proceeds to fetch + show when all preconditions pass.
    private func tick() async {
        // 1) Notch must be in a non-busy state.
        guard model.display.isIdle || model.display.isPopover else { return }

        // 2) Must have an API key (drill generation needs it).
        guard settings.hasAPIKey else { return }

        // 3) Must have a repository to fetch due items.
        guard let repo = repository else { return }

        // 4) User must be idle long enough.
        guard userIdleSeconds() >= Self.minIdleSeconds else { return }

        // 5) Must be past the rate-limit window.
        guard Date().timeIntervalSince(lastPromptedAt) >= Self.minPromptInterval else { return }

        // 6) Must have a due item.
        let due: WeaknessItem
        do {
            let items = try await repo.dueWeaknessItems()
            guard let first = items.first else { return }
            due = first
        } catch {
            log.error("dueWeaknessItems failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        // 7) Fetch an example for the rule (may be nil if no mistake row).
        let example = try? await repo.latestMistake(
            category: due.category,
            rule: due.rule
        )

        lastPromptedAt = Date()
        log.info("Surfacing notch review for #\(due.id ?? 0, privacy: .public) (\(due.category, privacy: .public))")
        await presenter.showReview(NotchReviewPayload(item: due, example: example))
    }

    /// Seconds since the user last interacted with the system. We sample
    /// multiple event types (keyboard, mouse move, click, scroll) and take
    /// the minimum, since `CGEventType` in Swift doesn't expose the
    /// `kCGAnyInputEventType` sentinel as a regular case.
    private func userIdleSeconds() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        var minIdle: TimeInterval = .greatestFiniteMagnitude
        for t in types {
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: t)
            if idle < minIdle { minIdle = idle }
        }
        return minIdle
    }
}
