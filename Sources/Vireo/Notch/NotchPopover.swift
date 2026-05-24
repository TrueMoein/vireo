// NotchPopover.swift — the rich popover surface when the user hovers the
// bird. This is now the primary day-to-day interaction, not a button menu.
//
// Sections (from top, all optional / conditional):
//   1. Header: bird + Vireo wordmark + live status pill
//   2. Coach card: due count + Start review CTA (or "All caught up")
//   3. Recent card: last 3 corrections with time + source app
//   4. Patterns card: top 3 frequent patterns
//   5. Footer: subtle Settings + Quit icon buttons
//
// Empty / setup states render their own affordances (e.g., "Add your
// OpenRouter key" links). Settings opens via SettingsLink. The main
// window (for full History / Patterns browsing) is reachable through
// the "Show all" links in each card.

import AppKit
import SwiftUI

struct NotchPopover: View {
    @ObservedObject var settings: SettingsModel
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var permission: AccessibilityPermission
    let presenter: NotchPresenter

    @Environment(\.openWindow) private var openWindow

    private let cardWidth: CGFloat = 460

    var body: some View {
        VStack(spacing: 12) {
            header
            if needsSetup {
                setupCard
            } else {
                coachCard
                if !sessionStore.sessions.isEmpty {
                    recentCard
                }
                if !sessionStore.patterns.isEmpty {
                    patternsCard
                }
            }
            footer
        }
        .padding(16)
        .frame(width: cardWidth, alignment: .leading)
        .vireoGlassCard(cornerRadius: 22)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .onAppear {
            Task { await sessionStore.reload() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
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
            statusPill
        }
    }

    private var statusPill: some View {
        let (label, color, icon): (String, Color, String) = {
            if !settings.hasAPIKey {
                return ("Add key", Color.Vireo.warning, "exclamationmark.triangle.fill")
            }
            if !permission.isGranted {
                return ("Accessibility", Color.Vireo.warning, "lock.shield.fill")
            }
            return ("Ready", Color.Vireo.correction, "checkmark.circle.fill")
        }()
        return Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var needsSetup: Bool {
        !settings.hasAPIKey || !permission.isGranted
    }

    // MARK: - Setup card

    private var setupCard: some View {
        sectionCard(title: "Get set up", tint: Color.Vireo.warning) {
            VStack(alignment: .leading, spacing: 10) {
                if !settings.hasAPIKey {
                    setupRow(
                        icon: "key.fill",
                        title: "Add your OpenRouter API key",
                        subtitle: "Vireo uses your key to power corrections."
                    )
                }
                if !permission.isGranted {
                    setupRow(
                        icon: "lock.shield.fill",
                        title: "Grant Accessibility permission",
                        subtitle: "So Vireo can read selected text and paste back."
                    )
                }
                openSettingsLink
            }
        }
    }

    private func setupRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.Vireo.warning)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var openSettingsLink: some View {
        SettingsLink {
            HStack(spacing: 4) {
                Text("Open Settings")
                Image(systemName: "arrow.up.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.Vireo.correction)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .simultaneousGesture(
            TapGesture().onEnded {
                Task { @MainActor in
                    await presenter.dismissToIdle()
                    try? await Task.sleep(for: .milliseconds(80))
                    bringWindowForward(matching: "settings")
                }
            }
        )
    }

    // MARK: - Coach card

    private var coachCard: some View {
        let summary = sessionStore.weaknessSummary
        return sectionCard(title: "Coach") {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    if summary.dueNow > 0 {
                        Text("\(summary.dueNow) due")
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.Vireo.accent)
                            .monospacedDigit()
                        Text("Review now to lock in the rules.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if summary.active > 0 {
                        Text("All caught up")
                            .font(.callout.weight(.medium))
                        Text("\(summary.active) active · \(summary.watching) watching")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if summary.watching > 0 {
                        Text("\(summary.watching) watching")
                            .font(.callout.weight(.medium))
                        Text("Patterns become active after 3 recurrences.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No patterns yet")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Keep using Vireo — patterns appear as you write.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if summary.dueNow > 0 {
                    Button {
                        Task { @MainActor in
                            await presenter.dismissToIdle()
                            openWindow(id: "vireo-main")
                            try? await Task.sleep(for: .milliseconds(80))
                            bringWindowForward(matching: "vireo-main")
                        }
                    } label: {
                        Label("Review", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Vireo.correction)
                    .controlSize(.regular)
                }
            }
        }
    }

    // MARK: - Recent card

    private var recentCard: some View {
        let recent = Array(sessionStore.sessions.prefix(3))
        return sectionCard(title: "Recent", trailing: AnyView(showAllButton)) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(recent) { session in
                    recentRow(session)
                }
            }
        }
    }

    private func recentRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(session.timestamp, style: .relative)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let app = session.sourceApp {
                    Text("· \(app)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(session.correctedText)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Patterns card

    private var patternsCard: some View {
        let top = Array(sessionStore.patterns.prefix(3))
        return sectionCard(title: "Top patterns", trailing: AnyView(showAllButton)) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(top) { pattern in
                    patternRow(pattern)
                }
            }
        }
    }

    private func patternRow(_ pattern: CategoryPattern) -> some View {
        HStack(spacing: 10) {
            Image(systemName: categoryIcon(for: pattern.category))
                .foregroundStyle(Color.Vireo.correction)
                .frame(width: 18)
            Text(prettifiedCategory(pattern.category))
                .font(.callout)
            Spacer()
            Text("\(pattern.totalCount)×")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Show all → opens main window

    private var showAllButton: some View {
        Button {
            Task { @MainActor in
                await presenter.dismissToIdle()
                openWindow(id: "vireo-main")
                try? await Task.sleep(for: .milliseconds(80))
                bringWindowForward(matching: "vireo-main")
            }
        } label: {
            HStack(spacing: 2) {
                Text("Show all")
                Image(systemName: "arrow.up.right")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.Vireo.correction)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                TapGesture().onEnded {
                    Task { @MainActor in
                        await presenter.dismissToIdle()
                        try? await Task.sleep(for: .milliseconds(80))
                        bringWindowForward(matching: "settings")
                    }
                }
            )
            .help("Settings ⌘,")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit Vireo ⌘Q")
        }
        .padding(.top, 2)
    }

    // MARK: - Section card chrome

    private func sectionCard<Content: View>(
        title: String,
        tint: Color = .secondary,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint == .secondary ? .secondary : tint)
                    .textCase(.uppercase)
                Spacer()
                if let trailing { trailing }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

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

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "article": return "textformat.abc"
        case "tense": return "clock"
        case "preposition": return "arrow.left.arrow.right"
        case "agreement": return "equal.circle"
        case "word_order": return "arrow.up.arrow.down"
        case "vocab": return "character.book.closed"
        case "spelling": return "abc"
        case "punctuation": return "quote.opening"
        case "l1_interference": return "globe"
        default: return "questionmark.circle"
        }
    }

    private func prettifiedCategory(_ raw: String) -> String {
        switch raw {
        case "article": return "Articles"
        case "tense": return "Tense"
        case "preposition": return "Prepositions"
        case "agreement": return "Agreement"
        case "word_order": return "Word order"
        case "vocab": return "Vocabulary"
        case "spelling": return "Spelling"
        case "punctuation": return "Punctuation"
        case "l1_interference": return "Persian → English"
        case "other": return "Other"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
