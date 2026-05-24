// NotchPopover.swift — what slides down when the user hovers the bird.
//
// Compact glass card with: header (bird + serif "Vireo"), status row (model
// ready or "add key"), and two actions (Settings, Quit). Settings uses
// SettingsLink (macOS 14+) so the Settings scene opens cleanly without
// activation hops or deprecated NSApp.sendAction calls.

import AppKit
import SwiftUI

struct NotchPopover: View {
    @ObservedObject var settings: SettingsModel
    let presenter: NotchPresenter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusRow
            Divider()
            actionsList
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        .vireoGlassCard(cornerRadius: 20)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bird.fill")
                .font(.title2)
                .foregroundStyle(Color.Vireo.correction)
            VStack(alignment: .leading, spacing: 0) {
                Text("Vireo")
                    .font(.system(.title3, design: .serif).weight(.medium))
                Text("an English coach")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if settings.hasAPIKey {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.Vireo.correction)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready")
                        .font(.Vireo.statusLine)
                        .fontWeight(.medium)
                    Text(settings.model)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.Vireo.warning)
                Text("Add your OpenRouter key in Settings")
                    .font(.Vireo.statusLine)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var actionsList: some View {
        VStack(spacing: 4) {
            Button {
                Task { @MainActor in
                    await presenter.dismissToIdle()
                    openWindow(id: "vireo-main")
                    try? await Task.sleep(for: .milliseconds(80))
                    bringWindowForward(matching: "vireo-main")
                }
            } label: {
                popoverRowLabel(systemImage: "bird", label: "Open Vireo", shortcut: nil)
            }
            .buttonStyle(NotchActionButtonStyle())

            SettingsLink {
                popoverRowLabel(systemImage: "gear", label: "Settings", shortcut: "⌘,")
            }
            .buttonStyle(NotchActionButtonStyle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    Task { @MainActor in
                        await presenter.dismissToIdle()
                        try? await Task.sleep(for: .milliseconds(80))
                        bringWindowForward(matching: "settings")
                    }
                }
            )

            Button {
                NSApp.terminate(nil)
            } label: {
                popoverRowLabel(systemImage: "power", label: "Quit Vireo", shortcut: "⌘Q")
            }
            .buttonStyle(NotchActionButtonStyle())
        }
    }

    /// Activate Vireo and bring the first window whose identifier or title
    /// contains `needle` (case-insensitive) all the way to the front.
    /// Necessary for accessory apps whose windows would otherwise appear
    /// behind whichever app was frontmost.
    private func bringWindowForward(matching needle: String) {
        NSApp.activate(ignoringOtherApps: true)
        let n = needle.lowercased()
        for window in NSApp.windows {
            let wid = window.identifier?.rawValue.lowercased() ?? ""
            let title = window.title.lowercased()
            if wid.contains(n) || title.contains(n) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    private func popoverRowLabel(
        systemImage: String,
        label: String,
        shortcut: String?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            if let shortcut {
                Text(shortcut)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }
}

private struct NotchActionButtonStyle: ButtonStyle {
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(isHovered ? 0.08 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.Vireo.microInteraction, value: isHovered)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
