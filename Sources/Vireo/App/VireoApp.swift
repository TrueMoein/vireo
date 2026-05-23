// VireoApp.swift — @main App entry, owns the MenuBarExtra + Settings scenes
// and the shared NotchPresenter.

import SwiftUI

@main
struct VireoApp: App {
    @StateObject private var settings = SettingsModel()
    @StateObject private var notchPresenter = NotchPresenter()

    var body: some Scene {
        MenuBarExtra("Vireo", systemImage: "bird") {
            MenubarPopover()
                .environmentObject(settings)
                .environmentObject(notchPresenter)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(notchPresenter)
        }
    }
}
