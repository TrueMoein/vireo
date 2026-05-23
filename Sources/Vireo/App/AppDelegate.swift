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
        self.settings = settings
        self.notchPresenter = presenter
        self.coordinator = AppCoordinator(settings: settings, notch: presenter)
        self.permission = AccessibilityPermission()
        super.init()
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
