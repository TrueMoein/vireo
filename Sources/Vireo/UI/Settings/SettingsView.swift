// SettingsView.swift — three-tab Settings window. Per-field auto-save, no
// global Save button. Each tab is its own focused view (ProviderTab,
// ShortcutsTab, AccessTab) so the user isn't scrolling through unrelated
// controls.

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

            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "command") }

            AccessTab()
                .tabItem { Label("Access", systemImage: "lock.shield") }
        }
        .frame(width: 580, height: 540)
    }
}
