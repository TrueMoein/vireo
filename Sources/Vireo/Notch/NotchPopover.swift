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
            SettingsLink {
                popoverRowLabel(systemImage: "gear", label: "Settings", shortcut: "⌘,")
            }
            .buttonStyle(NotchActionButtonStyle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    Task { await presenter.dismissToIdle() }
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

    private func popoverRowLabel(
        systemImage: String,
        label: String,
        shortcut: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(shortcut)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
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
