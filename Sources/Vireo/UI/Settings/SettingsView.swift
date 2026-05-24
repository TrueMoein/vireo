// SettingsView.swift — Settings is configuration ONLY (Provider, Shortcuts,
// Access). History / Patterns / Reviews live in the dedicated main window
// (MainWindowView), opened via the notch popover's "Open Vireo" entry.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var notchPresenter: NotchPresenter
    @EnvironmentObject var permission: AccessibilityPermission
    @EnvironmentObject var hoverButton: HoverButtonController

    var body: some View {
        TabView {
            ProviderTab()
                .tabItem { Label("Provider", systemImage: "sparkles") }

            StylesTab()
                .tabItem { Label("Styles", systemImage: "wand.and.stars") }

            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "command") }

            AccessTab()
                .tabItem { Label("Access", systemImage: "lock.shield") }

            DiagnosticsView()
                .tabItem { Label("Diagnostics", systemImage: "stethoscope") }
        }
        .frame(width: 580, height: 620)
    }
}
