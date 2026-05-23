// HoverButtonController.swift — orchestrates the PopClip-style hover button.
//
// Strategy (v0.1): a 200 ms polling loop reads AXSelectedText on the
// system-wide focused element. On transitions empty↔non-empty, we show or
// hide HoverButtonWindow at NSEvent.mouseLocation. Skips when Vireo is
// frontmost (so clicking the bird in Settings doesn't trigger us) and when
// AX is not granted. CPU cost: ~5 AX reads/sec, all on main actor.
//
// Upgrade path (v0.2): swap polling for AXObserver on
// kAXSelectedTextChangedNotification + kAXFocusedUIElementChangedNotification,
// re-targeted when the focused app or focused element changes. Polling lets
// us ship the feature without the C-callback / Sendable plumbing now.

import AppKit
import ApplicationServices
import Combine
import SwiftUI

@MainActor
final class HoverButtonController: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private static let enabledDefaultsKey = "co.vireo.hoverButtonEnabled"
    private static let pollInterval: Duration = .milliseconds(200)

    private let coordinator: AppCoordinator
    private let focus: FocusObserver
    private let button = HoverButtonWindow()

    private var pollingTask: Task<Void, Never>?
    private var focusCancellable: AnyCancellable?
    private var lastSelection: String = ""

    init(coordinator: AppCoordinator, focus: FocusObserver) {
        self.coordinator = coordinator
        self.focus = focus
        self.isEnabled = UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true

        button.onClick = { [weak self] in
            self?.handleClick()
        }

        focusCancellable = focus.$frontmostApp
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.lastSelection = ""
                    self?.button.hide()
                }
            }

        startPolling()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if !enabled {
            button.hide()
            lastSelection = ""
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled, let self else { return }
                self.poll()
            }
        }
    }

    private func poll() {
        guard isEnabled else { return }
        guard AXIsProcessTrusted() else { return }
        // Don't show on top of Vireo's own windows (Settings, etc.).
        let frontBundle = focus.frontmostApp?.bundleIdentifier
        if frontBundle == Bundle.main.bundleIdentifier { return }

        let current = readSelection() ?? ""
        guard current != lastSelection else { return }
        lastSelection = current

        if current.isEmpty {
            button.hide()
        } else {
            button.show(at: NSEvent.mouseLocation)
        }
    }

    private func readSelection() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success, let focused else { return nil }

        var selected: AnyObject?
        guard AXUIElementCopyAttributeValue(
            unsafeDowncast(focused, to: AXUIElement.self),
            kAXSelectedTextAttribute as CFString,
            &selected
        ) == .success, let text = selected as? String else { return nil }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleClick() {
        button.hide()
        lastSelection = ""
        Task {
            await coordinator.correctSelection()
        }
    }
}
