// NotchModel.swift — source of truth for what the notch is currently showing.
//
// Three mutually-exclusive display states:
//   - .idle      → compact mode, only the trailing bird icon is visible
//   - .popover   → hover-expanded, shows status + Settings + Quit actions
//   - .correction(result) → expanded card with the LLM correction

import Foundation
import SwiftUI

@MainActor
final class NotchModel: ObservableObject {
    @Published var display: Display = .idle

    enum Display {
        case idle
        case popover
        case correction(CorrectionResult)

        var isIdle: Bool { if case .idle = self { return true } else { return false } }
        var isPopover: Bool { if case .popover = self { return true } else { return false } }
        var isCorrection: Bool { if case .correction = self { return true } else { return false } }
    }
}
