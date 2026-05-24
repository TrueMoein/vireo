// DiagnosticsView.swift — runtime status panel for support + OSS issue
// reports. Shows the live state of every subsystem so a user can paste
// a screenshot in a bug report and we can see immediately what's up.
//
// Surfaces:
//   • Build identity — bundle path, version, running-from-bundle flag.
//   • Accessibility — current trust state with a Refresh button.
//   • Hotkey, hover button, double-shift, idle coach, clipboard monitor —
//     each shows enabled/disabled + a one-line description.
//   • Active style + active model — what the next correction will use.
//   • Database path — for users wanting to back up history.

import AppKit
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var permission: AccessibilityPermission
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var hoverButton: HoverButtonController
    @EnvironmentObject var doubleShift: ShiftDoubleTapMonitor
    @EnvironmentObject var idleCoach: IdleCoach
    @EnvironmentObject var clipboardMonitor: ClipboardMonitor
    @EnvironmentObject var styleStore: CorrectionStyleStore

    var body: some View {
        Form {
            buildSection
            accessibilitySection
            captureSection
            outputSection
            storageSection
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .onAppear { permission.refresh() }
    }

    // MARK: - Build

    private var buildSection: some View {
        Section("Build") {
            row(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "—")
            row(label: "Version", value: bundleVersion)
            row(
                label: "Running from",
                value: permission.runningFromBundle ? "Vireo.app bundle" : "Loose binary (AX trust will not persist)",
                accent: permission.runningFromBundle ? Color.Vireo.correction : Color.Vireo.warning
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("Binary path")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(permission.runningBinaryPath)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        Section("Accessibility") {
            HStack(spacing: 10) {
                statusDot(ok: permission.isGranted)
                Text(permission.isGranted ? "Granted" : "Not granted")
                    .font(.callout.weight(.medium))
                Spacer()
                Button("Re-check") { permission.refresh() }
                    .controlSize(.small)
            }
            if !permission.isGranted {
                Text("Hotkey, hover button, double-shift, and selection capture all need this. Open Settings → Access to grant.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Capture surfaces

    private var captureSection: some View {
        Section("Capture surfaces") {
            captureRow(
                name: "Hotkey",
                enabled: true,
                detail: "⌥⇧Space — primary trigger. Always on; reassign in Settings → Shortcuts."
            )
            captureRow(
                name: "Hover button",
                enabled: hoverButton.isEnabled,
                detail: hoverButton.isEnabled
                    ? "Polling AX selection every 200ms while Vireo isn't frontmost."
                    : "Disabled in Settings → Shortcuts."
            )
            captureRow(
                name: "Double-tap Right-Shift",
                enabled: doubleShift.isEnabled,
                detail: doubleShift.isEnabled
                    ? "CGEventTap on .flagsChanged, key 60 only, 300ms window."
                    : "Disabled in Settings → Shortcuts."
            )
            captureRow(
                name: "Clipboard monitor",
                enabled: clipboardMonitor.isEnabled,
                detail: clipboardMonitor.isEnabled
                    ? "Auto-corrects sentence-shaped English copies, 10s cooldown."
                    : "Disabled by default. Enable in Settings → Shortcuts."
            )
            captureRow(
                name: "Ambient coach",
                enabled: idleCoach.isEnabled,
                detail: idleCoach.isEnabled
                    ? "Surfaces a due drill after 30s idle, max once per 30 minutes."
                    : "Disabled in Settings → Shortcuts."
            )
        }
    }

    private func captureRow(name: String, enabled: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            statusDot(ok: enabled)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    // MARK: - Output

    private var outputSection: some View {
        Section("Output") {
            let style = styleStore.activeStyle
            row(label: "Active style", value: style.name, accent: Color.Vireo.correction)
            row(label: "API key", value: settings.hasAPIKey ? "Set (Keychain)" : "Missing",
                accent: settings.hasAPIKey ? Color.Vireo.correction : Color.Vireo.warning)
            row(label: "Model", value: settings.model.isEmpty ? "—" : settings.model)
            row(label: "Streaming", value: settings.streamingEnabled ? "On" : "Off")
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section("Storage") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Database")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(databasePath)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: databasePath)])
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func row(label: String, value: String, accent: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.callout)
                .foregroundStyle(accent ?? .primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func statusDot(ok: Bool) -> some View {
        Circle()
            .fill(ok ? Color.Vireo.correction : Color.Vireo.warning)
            .frame(width: 8, height: 8)
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }

    private var bundleVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info["CFBundleVersion"] as? String) ?? "?"
        return "\(short) (\(build))"
    }

    private var databasePath: String {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return "—" }
        return appSupport.appendingPathComponent("Vireo/vireo.sqlite").path
    }
}
