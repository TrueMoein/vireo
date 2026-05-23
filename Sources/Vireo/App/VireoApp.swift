// VireoApp.swift — @main App entry, owns the MenuBarExtra + Settings scenes.

import SwiftUI

@main
struct VireoApp: App {
    @StateObject private var settings = SettingsModel()

    var body: some Scene {
        MenuBarExtra("Vireo", systemImage: "bird") {
            MenubarPopover()
                .environmentObject(settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}
