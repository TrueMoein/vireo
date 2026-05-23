// CorrectionCard.swift — what the notch shows when a correction is ready.
//
// Phase 1 minimum: corrected sentence in New York serif, mistakes list with
// strikethrough → fix + category + rule + explanation, and three actions —
// Replace (paste corrected text back into the source app), Copy, Dismiss.
// Polish (matched-geometry pill ↔ card morph, signature motion, full Liquid
// Glass treatment) lands in Phase 3.

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
                .font(.system(.title3, design: .serif))
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if !result.mistakes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(result.mistakes.indices, id: \.self) { i in
                        mistakeRow(result.mistakes[i])
                    }
                }
            }

            Divider()
            actionsRow
        }
        .padding(20)
        .frame(width: 560, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .foregroundStyle(.tint)
                .imageScale(.medium)
            Text("Correction")
                .font(.headline)
            Spacer()
            if !result.mistakes.isEmpty {
                Text("\(result.mistakes.count) fix\(result.mistakes.count == 1 ? "" : "es")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func mistakeRow(_ m: CorrectionResult.Mistake) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(m.original)
                    .strikethrough()
                    .foregroundStyle(Color(red: 0.851, green: 0.467, blue: 0.341)) // coral
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(m.fixed)
                    .foregroundStyle(Color(red: 0.482, green: 0.659, blue: 0.537)) // sage
                    .bold()
            }
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)

            Text(m.category.rawValue + " · " + m.rule)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(m.explanation)
                .font(.caption)
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
            .tint(Color(red: 0.482, green: 0.659, blue: 0.537)) // sage
            .controlSize(.regular)

            Button(action: handleCopy) {
                if copyConfirmation {
                    Label("Copied", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                } else {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .animation(.smooth(duration: 0.2), value: copyConfirmation)

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
