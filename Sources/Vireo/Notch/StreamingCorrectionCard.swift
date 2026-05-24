// StreamingCorrectionCard.swift — the in-progress card shown while
// OpenRouter streams the corrected text. Same outer chrome as
// CorrectionCard, but the body is just the partial corrected sentence
// being typed in, with a subtle pulsing caret at the end.
//
// No Replace / Copy buttons yet — the result isn't final. A single
// Cancel button lets the user abort the network call early.

import SwiftUI

struct StreamingCorrectionCard: View {
    let partial: String
    let onCancel: () -> Void

    @State private var caretOpacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            sentenceView
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 560, alignment: .leading)
        .vireoGlassCard(cornerRadius: 22)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .onAppear { pulseCaret() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .foregroundStyle(Color.Vireo.correction)
                .imageScale(.medium)
            Text("Correcting…")
                .font(.Vireo.cardHeadline)
            Spacer()
            ProgressView()
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var sentenceView: some View {
        // Render the partial text + a soft caret. If we haven't seen
        // any partial yet, show an em-dash placeholder so the card has
        // visual presence.
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(partial.isEmpty ? " " : partial)
                .font(.Vireo.correctedSentence)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text("▍")
                .font(.Vireo.correctedSentence)
                .foregroundStyle(Color.Vireo.correction)
                .opacity(caretOpacity)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: onCancel) {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .keyboardShortcut(.cancelAction)
        }
    }

    private func pulseCaret() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            caretOpacity = 0.25
        }
    }
}
