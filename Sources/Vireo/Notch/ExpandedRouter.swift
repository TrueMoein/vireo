// ExpandedRouter.swift — switches the notch's expanded content based on
// NotchModel.display.

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
            case .busy(let label):
                BusyCard(label: label)
                    .transition(.blurReplace.combined(with: .scale(0.96)))
            case .message(let message):
                MessageCard(message: message)
                    .transition(.blurReplace.combined(with: .scale(0.96)))
            }
        }
        .animation(.smooth(duration: 0.32, extraBounce: 0.12), value: displayKey)
    }

    private var displayKey: String {
        switch model.display {
        case .idle: return "idle"
        case .popover: return "popover"
        case .correction: return "correction"
        case .busy: return "busy"
        case .message: return "message"
        }
    }
}
