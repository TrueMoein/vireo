// VireoApp.swift — @main App entry. The notch widget is the primary surface
// (owned by AppDelegate); the only SwiftUI Scene is the Settings window,
// reachable from the notch popover.

import SwiftUI

@main
struct VireoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.notchPresenter)
        }
    }
}
