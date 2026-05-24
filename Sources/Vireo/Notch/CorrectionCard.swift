// CorrectionCard.swift — what the notch shows when a correction is ready.
//
// Uses the DesignSystem tokens (Color.Vireo, Font.Vireo, Animation.Vireo)
// and the vireoGlassCard material modifier for the signature look.

import SwiftUI

struct CorrectionCard: View {
    let result: CorrectionResult
    let onReplace: () -> Void
    let onCopy: () -> Void
    let onDismiss: () -> Void

    @State private var copyConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(result.correctedText)
                .font(.Vireo.correctedSentence)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

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

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .foregroundStyle(Color.Vireo.correction)
                .imageScale(.medium)
            Text("Correction")
                .font(.Vireo.cardHeadline)
            Spacer()
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
