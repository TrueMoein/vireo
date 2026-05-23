// MenubarPopover.swift — what shows when the user clicks the bird in the menubar.
//
// Phase 1: status line + open Settings + quit. Real content (recent
// corrections, weakness summary, daily streak) lands in Phase 5.

import SwiftUI

struct MenubarPopover: View {
    @EnvironmentObject var settings: SettingsModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bird")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("Vireo")
                    .font(.headline)
            }

            if settings.hasAPIKey {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Label("Add your OpenRouter key in Settings", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings…", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Vireo", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(16)
        .frame(width: 260)
    }
}
