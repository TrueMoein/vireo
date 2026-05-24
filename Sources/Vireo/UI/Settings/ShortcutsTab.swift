// ShortcutsTab.swift — Settings tab for the global hotkey + capture-surface
// toggles.

import KeyboardShortcuts
import SwiftUI

struct ShortcutsTab: View {
    @EnvironmentObject var hoverButton: HoverButtonController
    @EnvironmentObject var idleCoach: IdleCoach
    @EnvironmentObject var doubleShift: ShiftDoubleTapMonitor
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor

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

            Section("Double-tap Right-Shift") {
                Toggle(isOn: Binding(
                    get: { doubleShift.isEnabled },
                    set: { doubleShift.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trigger a correction by double-tapping Right-Shift")
                        Text("A second hotkey path that doesn't need three fingers. Two presses of the Right-Shift key within 300 ms acts the same as ⌥⇧Space. Requires Accessibility.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

            Section("Clipboard") {
                Toggle(isOn: Binding(
                    get: { clipboardMonitor.isEnabled },
                    set: { clipboardMonitor.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-correct when I copy English text")
                        Text("Vireo watches the clipboard and runs the active style on sentence-shaped English copies. Replace puts the corrected text back on the clipboard so your next paste uses it. Strict filter: detected English, not code/URL, 12–2000 chars, 10s cooldown between runs.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section("Ambient coach") {
                Toggle(isOn: Binding(
                    get: { idleCoach.isEnabled },
                    set: { idleCoach.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Slide a drill into the notch when I'm idle")
                        Text("After ~30s of inactivity, if a weakness pattern is due, the notch quietly presents a single fill-in-the-blank drill. At most once every 30 minutes.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    Text("Try one now")
                    Spacer()
                    Button("Show a drill in the notch") {
                        Task { await idleCoach.triggerNow() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }
}
