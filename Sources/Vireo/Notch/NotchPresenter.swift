// NotchPresenter.swift — wraps DynamicNotchKit. Exposes show(_:)/hide() to
// the rest of the app. State machine for Phase 1: hidden → expandedCard →
// hidden after auto-hide timeout. Compact-pill mode + manual pin land in
// Phase 3 when we have time for the morph polish.

import AppKit
import DynamicNotchKit
import SwiftUI

@MainActor
final class NotchPresenter: ObservableObject {
    /// Source of truth for what's currently shown in the notch. CorrectionCard
    /// observes this via @ObservedObject.
    let model = NotchModel()

    /// Auto-hide expanded notch after this long. Phase 3 will introduce a
    /// pill state at ~4s and full hide at ~12s; for now we keep it simple.
    static let autoHideAfter: Duration = .seconds(12)

    private var notch: DynamicNotch<CorrectionCard, EmptyView, EmptyView>?
    private var autoHideTask: Task<Void, Never>?

    /// Show a correction. Creates the underlying DynamicNotch lazily on
    /// first call so we capture `model` after init.
    func show(_ result: CorrectionResult) async {
        model.currentResult = result
        autoHideTask?.cancel()

        if notch == nil {
            let capturedModel = model
            notch = DynamicNotch {
                CorrectionCard(model: capturedModel)
            }
        }

        await notch?.expand(on: Self.preferredScreen)

        autoHideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autoHideAfter)
            guard !Task.isCancelled, let self else { return }
            await self.hide()
        }
    }

    func hide() async {
        autoHideTask?.cancel()
        await notch?.hide()
        model.currentResult = nil
    }

    /// Prefer the built-in display (the one with the notch) when there are
    /// multiple screens. Fall back to whichever screen is "main" or the
    /// first one if nothing else works.
    private static var preferredScreen: NSScreen {
        // Inlined notch check — `NSScreen.hasNotch` from DynamicNotchKit is
        // internal-scoped, so we replicate the same condition publicly here.
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        if let main = NSScreen.main {
            return main
        }
        return NSScreen.screens[0]
    }
}

@MainActor
final class NotchModel: ObservableObject {
    @Published var currentResult: CorrectionResult?
}
