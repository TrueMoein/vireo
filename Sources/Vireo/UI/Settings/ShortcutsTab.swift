// ShortcutsTab.swift — Settings tab for the global hotkey + capture-surface
// toggles.

import KeyboardShortcuts
import SwiftUI

struct ShortcutsTab: View {
    @EnvironmentObject var hoverButton: HoverButtonController

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Correct selection")
                        Text("Select text anywhere, then press this combination to send it through the model.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .correctSelection)
                }
            }

            Section("Hover button") {
                Toggle(isOn: Binding(
                    get: { hoverButton.isEnabled },
                    set: { hoverButton.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show floating button on text selection")
                        Text("When you select text in any app, a small Vireo bird blooms next to your cursor — click it instead of using the hotkey. Works best in native apps (Notes, Mail, etc.); some Electron apps don't expose selection.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}
