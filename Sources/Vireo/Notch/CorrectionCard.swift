// CorrectionCard.swift — what the notch shows when a correction is ready.
//
// Uses the DesignSystem tokens (Color.Vireo, Font.Vireo, Animation.Vireo)
// and the vireoGlassCard material modifier for the signature look.

import SwiftUI

struct CorrectionCard: View {
    let result: CorrectionResult
    let styleStore: CorrectionStyleStore?
    let onReplace: () -> Void
    let onCopy: () -> Void
    let onDismiss: () -> Void
    /// Called when the user picks a different style from the chip menu.
    /// Coordinator routes this to `correct(text:styleID:)`.
    let onRecorrect: (UUID) -> Void

    @State private var copyConfirmation = false
    @State private var showOriginal = true

    private var hasOriginal: Bool {
        !result.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && result.originalText != result.correctedText
    }

    private var resolvedStyle: CorrectionStyle? {
        guard let id = result.styleID else { return nil }
        return styleStore?.resolve(id: id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let style = resolvedStyle, let store = styleStore {
                styleChipRow(active: style, store: store)
            }

            sentenceView

            if !result.mistakes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(result.mistakes.indices, id: \.self) { i in
                        mistakeRow(result.mistakes[i])
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            Divider()
            actionsRow
        }
        .padding(20)
        .frame(width: 560, alignment: .leading)
        .vireoGlassCard(cornerRadius: 22)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    /// Chip showing the style used to produce this correction. Clicking
    /// reveals a menu of all styles; picking a different one fires
    /// onRecorrect(_:) which re-runs the same text through the chosen
    /// style and replaces the visible card.
    private func styleChipRow(active: CorrectionStyle, store: CorrectionStyleStore) -> some View {
        HStack {
            Menu {
                ForEach(store.allStyles) { style in
                    Button {
                        if style.id != active.id {
                            onRecorrect(style.id)
                        }
                    } label: {
                        if style.id == active.id {
                            Label(style.name, systemImage: "checkmark")
                        } else {
                            Label(style.name, systemImage: style.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: active.icon)
                        .imageScale(.small)
                    Text(active.name)
                        .font(.caption.weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .opacity(0.7)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(Color.Vireo.correction)
                .background(Color.Vireo.correction.opacity(0.10))
                .clipShape(Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
            .help("Re-run this text with a different style")
            Spacer()
        }
    }

    /// Either an inline word-diff (when we have the original text and
    /// it differs from the correction) or the plain corrected sentence.
    /// The toggle lets the user flip to plain corrected text for a clean
    /// copy-paste view.
    @ViewBuilder
    private var sentenceView: some View {
        if hasOriginal && showOriginal {
            Text(diffAttributed)
                .font(.Vireo.correctedSentence)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .animation(.smooth(duration: 0.22), value: showOriginal)
        } else {
            Text(result.correctedText)
                .font(.Vireo.correctedSentence)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .animation(.smooth(duration: 0.22), value: showOriginal)
        }
    }

    private var diffAttributed: AttributedString {
        SentenceDiff.render(
            SentenceDiff.compute(
                original: result.originalText,
                corrected: result.correctedText
            )
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .foregroundStyle(Color.Vireo.correction)
                .imageScale(.medium)
            Text("Correction")
                .font(.Vireo.cardHeadline)
            Spacer()
            if hasOriginal {
                Button {
                    showOriginal.toggle()
                } label: {
                    Label(showOriginal ? "Just corrected" : "Show diff",
                          systemImage: showOriginal ? "text.alignleft" : "arrow.left.arrow.right")
                        .labelStyle(.titleAndIcon)
                        .font(.Vireo.categoryChip)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(showOriginal
                      ? "Hide the diff and show just the corrected sentence"
                      : "Show the original sentence with edits inline")
            }
            if !result.mistakes.isEmpty {
                Text("\(result.mistakes.count) fix\(result.mistakes.count == 1 ? "" : "es")")
                    .font(.Vireo.categoryChip)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func mistakeRow(_ m: CorrectionResult.Mistake) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(m.original)
                    .strikethrough()
                    .foregroundStyle(Color.Vireo.mistake)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(m.fixed)
                    .foregroundStyle(Color.Vireo.correction)
                    .bold()
            }
            .font(.Vireo.mistakeMono)
            .textSelection(.enabled)

            Text(m.category.rawValue + " · " + m.rule)
                .font(.Vireo.categoryChip)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(m.explanation)
                .font(.Vireo.detail)
                .foregroundStyle(.primary.opacity(0.85))
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button(action: onReplace) {
                Label("Replace", systemImage: "arrow.uturn.left.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Vireo.correction)
            .controlSize(.regular)

            Button(action: handleCopy) {
                Group {
                    if copyConfirmation {
                        Label("Copied", systemImage: "checkmark")
                    } else {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .animation(.Vireo.microInteraction, value: copyConfirmation)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(width: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Dismiss")
        }
    }

    private func handleCopy() {
        onCopy()
        copyConfirmation = true
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            copyConfirmation = false
        }
    }
}
