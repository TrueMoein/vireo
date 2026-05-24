// OnboardingWindowController.swift — minimal NSWindow wrapper around
// OnboardingWindowView so AppDelegate can show it directly on first
// launch without juggling SwiftUI's openWindow environment value.

import AppKit
import Combine
import SwiftUI

@MainActor
final class OnboardingWindowController {
    let settings: SettingsModel
    let permission: AccessibilityPermission

    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    init(settings: SettingsModel, permission: AccessibilityPermission) {
        self.settings = settings
        self.permission = permission
        // Listen for re-run requests from Settings → Access → Re-run onboarding.
        cancellable = NotificationCenter.default
            .publisher(for: .vireoShowOnboarding)
            .sink { [weak self] _ in
                Task { @MainActor in self?.show() }
            }
    }

    func showIfNeeded() {
        guard !OnboardingState.hasOnboarded() else { return }
        show()
    }

    func show() {
        if window == nil {
            window = makeWindow()
        }
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.center()
    }

    private func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let root = OnboardingWindowView(
            settings: settings,
            permission: permission,
            onComplete: { [weak self] in
                self?.close()
            }
        )
        let host = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to Vireo"
        window.setContentSize(NSSize(width: 580, height: 500))
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
