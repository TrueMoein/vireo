// NotchModel.swift — source of truth for what the notch is currently showing.

import Foundation
import SwiftUI

@MainActor
final class NotchModel: ObservableObject {
    @Published var display: Display = .idle

    enum Display {
        case idle
        case popover
        case correction(CorrectionResult)
        case busy(String)
        case message(NotchMessage)
        case firstLaunch

        var isIdle: Bool { if case .idle = self { return true } else { return false } }
        var isPopover: Bool { if case .popover = self { return true } else { return false } }
        var isCorrection: Bool { if case .correction = self { return true } else { return false } }
        var isBusy: Bool { if case .busy = self { return true } else { return false } }
        var isMessage: Bool { if case .message = self { return true } else { return false } }
        var isFirstLaunch: Bool { if case .firstLaunch = self { return true } else { return false } }

        /// True for any state where hover-to-popover transitions should be
        /// suppressed (we don't want a hover to wipe out an in-progress
        /// correction, an error message, or the first-launch wow moment).
        var locksHover: Bool {
            switch self {
            case .correction, .busy, .message, .firstLaunch: return true
            case .idle, .popover: return false
            }
        }
    }
}

struct NotchMessage: Sendable {
    let icon: String
    let title: String
    let detail: String?
    let tone: Tone

    enum Tone: Sendable {
        case info, warning, error
    }

    static func info(_ title: String, detail: String? = nil) -> NotchMessage {
        .init(icon: "info.circle.fill", title: title, detail: detail, tone: .info)
    }

    static func warning(_ title: String, detail: String? = nil) -> NotchMessage {
        .init(icon: "exclamationmark.triangle.fill", title: title, detail: detail, tone: .warning)
    }

    static func error(_ detail: String) -> NotchMessage {
        .init(icon: "exclamationmark.octagon.fill", title: "Error", detail: detail, tone: .error)
    }
}
