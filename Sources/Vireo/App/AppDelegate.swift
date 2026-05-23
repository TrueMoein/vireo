// AppDelegate.swift — owns model lifetimes, starts the notch widget, and
// registers the global hotkey.

import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings: SettingsModel
    let notchPresenter: NotchPresenter
    let coordinator: AppCoordinator
    let permission: AccessibilityPermission

    override init() {
        let settings = SettingsModel()
        let presenter = NotchPresenter(settings: settings)
        let coordinator = AppCoordinator(settings: settings, notch: presenter)
        self.settings = settings
        self.notchPresenter = presenter
        self.coordinator = coordinator
        self.permission = AccessibilityPermission()
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
