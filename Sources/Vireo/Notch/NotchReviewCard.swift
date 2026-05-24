// NotchReviewCard.swift — single-drill review card shown ambiently in the
// notch when the user is idle and has due weakness items.
//
// Layout is intentionally compact (one drill at a time, no queue chrome):
//   • Category banner + dismiss X
//   • Rule line
//   • Drill blank + TextField (or revealed sentence + guess result + context)
//   • 4 rating buttons (Again / Hard / Good / Easy)
//
// After rating, the card asks the coordinator to advance — IdleCoach is
// the policy owner; this view just emits intent.

import SwiftUI

struct NotchReviewCard: View {
    let payload: NotchReviewPayload
    let drillGenerator: DrillGenerator
    let onRate: (Grade) -> Void
    let onDismiss: () -> Void

    @State private var drill: Drill?
    @State private var drillError: String?
    @State private var revealed: Bool = false
    @State private var guess: String = ""
    @FocusState private var guessFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ruleLine
            drillSection
            if shouldShowRatings {
                ratingsRow
            }
        }
        .padding(14)
        .frame(width: 460, alignment: .leading)
        .vireoGlassCard(cornerRadius: 22)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .task { await loadDrill() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: categoryIcon(for: payload.item.category))
                .font(.callout)
                .foregroundStyle(Color.Vireo.correction)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text("Quick review")
                    .font(.system(.callout, design: .serif).weight(.medium))
                Text(prettifiedCategory(payload.item.category))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
    }

    // MARK: - Rule + drill

    private var ruleLine: some View {
        Text(payload.item.rule)
            .font(.callout)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var drillSection: some View {
        if let drill {
            drillCard(drill)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.smooth(duration: 0.22), value: revealed)
        } else if drillError != nil {
            fallbackExample
        } else {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Generating a practice sentence…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func drillCard(_ drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if revealed {
                Text(buildHighlightedSentence(drill: drill))
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                guessResultRow(drill: drill)

                Text(drill.context)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(drill.blank)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                TextField("Type your answer or skip", text: $guess)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .focused($guessFocused)
                    .onSubmit { reveal() }

                HStack(spacing: 6) {
                    Button {
                        reveal()
                    } label: {
                        Label(guess.isEmpty ? "Reveal" : "Check", systemImage: "eye.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Vireo.correction)
                    .controlSize(.small)
                    .keyboardShortcut(.return)

                    if !guess.isEmpty {
                        Button("Clear") { guess = "" }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { guessFocused = true }
    }

    @ViewBuilder
    private var fallbackExample: some View {
        if let example = payload.example {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(example.originalPhrase)
                        .strikethrough()
                        .foregroundStyle(Color.Vireo.mistake)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(example.fixedPhrase)
                        .foregroundStyle(Color.Vireo.correction)
                        .bold()
                }
                .font(.system(.caption, design: .monospaced))
                Text(example.explanation)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Text("Couldn't load a drill or example.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ratings

    private var shouldShowRatings: Bool {
        revealed || (drill == nil && drillError != nil)
    }

    private var ratingsRow: some View {
        HStack(spacing: 6) {
            ratingButton(.again, label: "Again", tint: Color.Vireo.mistake)
            ratingButton(.hard, label: "Hard", tint: Color.Vireo.warning)
            ratingButton(.good, label: "Good", tint: Color.Vireo.correction)
            ratingButton(.easy, label: "Easy", tint: Color.Vireo.correctionHighlight)
        }
    }

    private func ratingButton(_ grade: Grade, label: String, tint: Color) -> some View {
        Button {
            onRate(grade)
        } label: {
            Text(label)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.small)
    }

    // MARK: - Logic helpers

    private func loadDrill() async {
        guard drill == nil, drillError == nil else { return }
        do {
            drill = try await drillGenerator.drill(
                for: payload.item.id ?? 0,
                rule: payload.item.rule,
                example: payload.example
            )
        } catch {
            drillError = error.localizedDescription
        }
    }

    private func reveal() {
        withAnimation(.smooth(duration: 0.22)) { revealed = true }
    }

    @ViewBuilder
    private func guessResultRow(drill: Drill) -> some View {
        let normalize: (String) -> String = {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let trimmed = guess.trimmingCharacters(in: .whitespacesAndNewlines)
        let correct = !trimmed.isEmpty && normalize(trimmed) == normalize(drill.answer)
        let skipped = trimmed.isEmpty

        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if skipped {
                Text("Skipped")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text("\u{201C}\(trimmed)\u{201D}")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(correct ? Color.Vireo.correction : Color.Vireo.mistake)
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(correct ? Color.Vireo.correction : Color.Vireo.mistake)
                if !correct {
                    Text("· \u{201C}\(drill.answer)\u{201D}")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.Vireo.correction)
                }
            }
            Spacer()
        }
    }

    private func buildHighlightedSentence(drill: Drill) -> AttributedString {
        let placeholder = "___"
        var result = AttributedString(drill.blank)
        if let range = result.range(of: placeholder) {
            var replacement = AttributedString(drill.answer)
            replacement.foregroundColor = Color.Vireo.correction
            replacement.inlinePresentationIntent = .stronglyEmphasized
            result.replaceSubrange(range, with: replacement)
        }
        return result
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
        case "other": return "Other"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
