// ExpandedRouter.swift — switches the notch's expanded content between the
// hover popover and the correction card based on NotchModel.display.

import SwiftUI

struct ExpandedRouter: View {
    @ObservedObject var model: NotchModel
    let presenter: NotchPresenter

    var body: some View {
        Group {
            switch model.display {
            case .idle:
                Color.clear.frame(width: 1, height: 1)
            case .popover:
                NotchPopover(settings: presenter.settings, presenter: presenter)
                    .transition(.blurReplace.combined(with: .scale(0.96)))
            case .correction(let result):
                CorrectionCard(result: result)
                    .transition(.blurReplace.combined(with: .scale(0.96)))
            }
        }
        .animation(.smooth(duration: 0.32, extraBounce: 0.12), value: displayKey)
    }

    /// Equatable witness for `model.display` so SwiftUI's animation modifier
    /// has something to compare on transitions.
    private var displayKey: String {
        switch model.display {
        case .idle: return "idle"
        case .popover: return "popover"
        case .correction: return "correction"
        }
    }
}
