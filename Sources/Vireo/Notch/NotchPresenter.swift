// NotchPresenter.swift — owns the persistent DynamicNotch and drives its
// state machine.
//
// Resting: compact mode with CompactBirdIcon in the trailing slot.
// Hover enter (after ~150 ms): expand into NotchPopover.
// Hover leave (after ~200 ms): collapse back to compact.
// Correction / busy / message: expand into the corresponding card. Hover
// transitions are suppressed for those states.

import AppKit
import Combine
import DynamicNotchKit
import OSLog
import SwiftUI

private let log = Logger(subsystem: "co.vireo", category: "NotchPresenter")

@MainActor
final class NotchPresenter: ObservableObject {
    let model = NotchModel()
    let settings: SettingsModel
    /// Wired by AppDelegate after both objects exist (they hold weak ↔ strong
    /// references). Used by CorrectionCard's action buttons.
    weak var coordinator: AppCoordinator?
    /// Wired by AppDelegate. Used by NotchPopover to render rich content
    /// (recent corrections, patterns, coach state).
    weak var sessionStore: SessionStore?
    weak var permission: AccessibilityPermission?

    static let hoverEnterDelay: Duration = .milliseconds(150)
    static let hoverLeaveDelay: Duration = .milliseconds(200)
    static let correctionAutoHideAfter: Duration = .seconds(12)
    static let messageAutoHideAfter: Duration = .seconds(6)
    static let firstLaunchAutoHideAfter: Duration = .seconds(4)

    private static let firstLaunchDefaultsKey = "co.vireo.hasShownFirstLaunch"

    private var notch: DynamicNotch<ExpandedRouter, EmptyView, CompactBirdIcon>?
    private var hoverObserver: AnyCancellable?
    private var activationObservers: Set<AnyCancellable> = []
    private var autoHideTask: Task<Void, Never>?

    init(settings: SettingsModel) {
        self.settings = settings
    }

    /// Bring up the persistent compact widget. Idempotent.
    func start() {
        guard notch == nil else { return }

        let model = self.model
        let presenter = self

        notch = DynamicNotch(
            hoverBehavior: .all,
            style: .auto,
            expanded: { ExpandedRouter(model: model, presenter: presenter) },
            compactLeading: { EmptyView() },
            compactTrailing: { CompactBirdIcon() }
        )

        Task { [weak self] in
            await self?.notch?.compact(on: Self.preferredScreen)
        }

        hoverObserver = notch?.$isHovering
            .removeDuplicates()
            .sink { [weak self] hovering in
                Task { @MainActor in
                    await self?.handleHover(hovering)
                }
            }

        installActivationObservers()
    }

    /// Re-assert the notch panel's z-order. Call this after any action that
    /// activates a different window (Settings, main, onboarding), after
    /// `NSApp.activate(ignoringOtherApps:)`, or after a System Settings
    /// round-trip (e.g., the AX-grant flow). The panel sits at
    /// `.screenSaver` level, but macOS occasionally displaces it when an
    /// `.accessory` app cycles activation state — re-ordering it front
    /// restores it without changing levels or recreating the panel.
    func reassertPanelVisibility() {
        guard let window = notch?.windowController?.window else {
            log.info("reassertPanelVisibility: no panel — re-creating")
            // The whole DynamicNotch lost its window. Bounce through hide
            // so the next compact() builds a fresh one.
            Task { [weak self] in
                guard let self else { return }
                await self.notch?.hide()
                try? await Task.sleep(for: .milliseconds(280))
                await self.notch?.compact(on: Self.preferredScreen)
            }
            return
        }
        if !window.isVisible {
            log.info("reassertPanelVisibility: panel was hidden — restoring")
        }
        window.orderFrontRegardless()
    }

    /// Observe app-level events that historically displace the notch
    /// panel: app activation transitions and screen-parameter changes
    /// (e.g., when System Settings opens for the AX grant flow).
    ///
    /// We deliberately do NOT observe window-key transitions: the notch
    /// panel itself becomes key on hover, which would trigger spurious
    /// re-assertions mid-expand and make hover flicker (the panel
    /// resizes during the expand animation, and re-ordering during that
    /// animation breaks the `.onHover` region in DynamicNotchKit).
    ///
    /// We also guard each callback so we only re-assert when the notch
    /// is at rest (idle compact state) — never while the user is
    /// actively engaging with a popover / correction / review / etc.
    /// During those states the panel is by definition visible already,
    /// and re-ordering it would race the in-flight animation.
    private func installActivationObservers() {
        let nc = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSApplication.didChangeScreenParametersNotification,
        ]
        for name in names {
            nc.publisher(for: name)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        // Don't disturb the panel during active interaction.
                        guard self.model.display.isIdle else { return }
                        // Tiny delay to let the OS finish its own ordering.
                        try? await Task.sleep(for: .milliseconds(80))
                        // Re-check after the delay — user may have started
                        // hovering / opened a popover in the meantime.
                        guard self.model.display.isIdle else { return }
                        self.reassertPanelVisibility()
                    }
                }
                .store(in: &activationObservers)
        }
    }

    /// Push a correction into the notch. Stays expanded until the user
    /// explicitly dismisses (Replace / Copy / Dismiss) — no auto-hide
    /// timeout, because the user may still be reading the explanation.
    func showCorrection(_ result: CorrectionResult) async {
        autoHideTask?.cancel()
        if notch == nil { start() }
        model.display = .correction(result)
        await notch?.expand(on: Self.preferredScreen)
    }

    /// Show a busy/loading card. Does NOT auto-dismiss — the caller is
    /// expected to follow up with showCorrection or showMessage.
    func showBusy(_ label: String) async {
        autoHideTask?.cancel()
        if notch == nil { start() }
        model.display = .busy(label)
        await notch?.expand(on: Self.preferredScreen)
    }

    /// Show a transient message (info/warning/error). Auto-dismiss after
    /// `messageAutoHideAfter`.
    func showMessage(_ message: NotchMessage) async {
        autoHideTask?.cancel()
        if notch == nil { start() }
        model.display = .message(message)
        await notch?.expand(on: Self.preferredScreen)
        autoHideTask = scheduleAutoHide(after: Self.messageAutoHideAfter)
    }

    /// Show the first-launch wow moment if it hasn't been shown before.
    /// Sets the UserDefaults flag and schedules auto-dismiss.
    func showFirstLaunchIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: Self.firstLaunchDefaultsKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.firstLaunchDefaultsKey)
        await showFirstLaunch()
    }

    /// Force-show the first-launch moment (used by a Settings "show welcome
    /// again" button or for development testing).
    func showFirstLaunch() async {
        autoHideTask?.cancel()
        if notch == nil { start() }
        model.display = .firstLaunch
        await notch?.expand(on: Self.preferredScreen)
        autoHideTask = scheduleAutoHide(after: Self.firstLaunchAutoHideAfter)
    }

    /// Return to the resting compact state.
    func dismissToIdle() async {
        autoHideTask?.cancel()
        model.display = .idle
        await notch?.compact(on: Self.preferredScreen)
    }

    private func scheduleAutoHide(after duration: Duration) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            await self.dismissToIdle()
        }
    }

    private func handleHover(_ hovering: Bool) async {
        // Don't disturb busy/correction/message states.
        if model.display.locksHover { return }

        if hovering {
            guard model.display.isIdle else { return }
            try? await Task.sleep(for: Self.hoverEnterDelay)
            guard model.display.isIdle, notch?.isHovering == true else { return }
            model.display = .popover
            await notch?.expand(on: Self.preferredScreen)
        } else {
            guard model.display.isPopover else { return }
            try? await Task.sleep(for: Self.hoverLeaveDelay)
            guard model.display.isPopover, notch?.isHovering == false else { return }
            await dismissToIdle()
        }
    }

    private static var preferredScreen: NSScreen {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
