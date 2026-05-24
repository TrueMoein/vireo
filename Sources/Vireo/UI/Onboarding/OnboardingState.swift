// OnboardingState.swift — state machine for the 4-step first-launch wizard.

import Foundation
import SwiftUI

@MainActor
final class OnboardingState: ObservableObject {
    @Published var step: Step = .welcome

    let settings: SettingsModel
    let permission: AccessibilityPermission
    let styleStore: CorrectionStyleStore

    static let defaultsKey = "co.vireo.hasOnboarded"

    init(settings: SettingsModel, permission: AccessibilityPermission, styleStore: CorrectionStyleStore) {
        self.settings = settings
        self.permission = permission
        self.styleStore = styleStore
    }

    enum Step: Int, CaseIterable, Hashable {
        case welcome = 0
        case apiKey
        case accessibility
        case style
        case ready

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .apiKey: return "API key"
            case .accessibility: return "Permission"
            case .style: return "Style"
            case .ready: return "Ready"
            }
        }
    }

    var canGoBack: Bool { step.rawValue > 0 }
    var canGoNext: Bool { step.rawValue < Step.allCases.count - 1 }
    var isLastStep: Bool { step == Step.allCases.last }

    func next() {
        guard let new = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(.smooth(duration: 0.3)) {
            step = new
        }
    }

    func back() {
        guard let new = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(.smooth(duration: 0.3)) {
            step = new
        }
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: Self.defaultsKey)
    }

    static func hasOnboarded() -> Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

extension Notification.Name {
    /// Posted by Settings → Access → "Re-run onboarding…" to ask the
    /// OnboardingWindowController to bring the wizard back up.
    static let vireoShowOnboarding = Notification.Name("co.vireo.showOnboarding")
}
