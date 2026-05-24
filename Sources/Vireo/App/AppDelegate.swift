// AppDelegate.swift — owns model lifetimes, starts the notch widget, and
// registers the global hotkey + the PopClip-style hover button controller.

import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings: SettingsModel
    let notchPresenter: NotchPresenter
    let coordinator: AppCoordinator
    let permission: AccessibilityPermission
    let focusObserver: FocusObserver
    let hoverButton: HoverButtonController

    override init() {
        let settings = SettingsModel()
        let presenter = NotchPresenter(settings: settings)
        let coordinator = AppCoordinator(settings: settings, notch: presenter)
        let focusObserver = FocusObserver()
        let hoverButton = HoverButtonController(coordinator: coordinator, focus: focusObserver)

        self.settings = settings
        self.notchPresenter = presenter
        self.coordinator = coordinator
        self.permission = AccessibilityPermission()
        self.focusObserver = focusObserver
        self.hoverButton = hoverButton
        super.init()
        // Break the retain cycle: coordinator strongly holds presenter via
        // its notch field; presenter holds coordinator weakly for action
        // dispatch from CorrectionCard buttons.
        presenter.coordinator = coordinator
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        notchPresenter.start()
        registerHotkeys()

        // First-launch wow moment: after a brief settle delay so the notch
        // is fully positioned, slide down the MeshGradient + serif
        // welcome card. Only ever shown once per user.
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            await notchPresenter.showFirstLaunchIfNeeded()
        }
    }

    private func registerHotkeys() {
        let coordinator = self.coordinator
        KeyboardShortcuts.onKeyDown(for: .correctSelection) {
            Task { @MainActor in
                await coordinator.correctSelection()
            }
        }
    }
}
