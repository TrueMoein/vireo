// VireoApp.swift — @main App entry, owns the MenuBarExtra scene + notch presenter.

import SwiftUI

@main
struct VireoApp: App {
    var body: some Scene {
        MenuBarExtra("Vireo", systemImage: "bird") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vireo")
                    .font(.headline)
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
