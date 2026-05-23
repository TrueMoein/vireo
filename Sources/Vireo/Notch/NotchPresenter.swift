// NotchPresenter.swift — owns the persistent DynamicNotch and drives its
// state machine.
//
// Resting: compact mode with CompactBirdIcon in the trailing slot.
// Hover enter (after ~150 ms): expand into NotchPopover.
// Hover leave (after ~200 ms): collapse back to compact.
// Correction arrives: expand into CorrectionCard, auto-dismiss after 12 s.
// Hover does not disturb a correction display.

import AppKit
import Combine
import DynamicNotchKit
import SwiftUI

@MainActor
final class NotchPresenter: ObservableObject {
    let model = NotchModel()
    let settings: SettingsModel

    static let hoverEnterDelay: Duration = .milliseconds(150)
    static let hoverLeaveDelay: Duration = .milliseconds(200)
    static let correctionAutoHideAfter: Duration = .seconds(12)

    private var notch: DynamicNotch<ExpandedRouter, EmptyView, CompactBirdIcon>?
    private var hoverObserver: AnyCancellable?
    private var correctionHideTask: Task<Void, Never>?

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

        // Reach compact state on the preferred screen as soon as the run loop
        // tick gives us NSScreen.screens populated.
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
    }

    /// Push a correction into the notch. Expands into CorrectionCard, then
    /// auto-dismisses back to .idle after the timeout.
    func showCorrection(_ result: CorrectionResult) async {
        correctionHideTask?.cancel()
        if notch == nil { start() }
        model.display = .correction(result)
        await notch?.expand(on: Self.preferredScreen)

        correctionHideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.correctionAutoHideAfter)
            guard !Task.isCancelled, let self else { return }
            await self.dismissToIdle()
        }
    }

    /// Return to the resting compact state.
    func dismissToIdle() async {
        correctionHideTask?.cancel()
        model.display = .idle
        await notch?.compact(on: Self.preferredScreen)
    }

    private func handleHover(_ hovering: Bool) async {
        // Hover doesn't disturb correction displays.
        if model.display.isCorrection { return }

        if hovering {
            guard model.display.isIdle else { return }
            try? await Task.sleep(for: Self.hoverEnterDelay)
            // Re-check both intent and physical hover after the debounce.
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
