// ReviewSessionView.swift — sheet UI for one review run with LLM-generated
// fill-in-the-blank drills.
//
// Each card:
//   1. Shows the rule + an LLM-generated drill sentence with ___ blank.
//   2. User mentally recalls the answer, clicks "Reveal answer".
//   3. Reveal shows the answer + context + the four rating buttons.
//   4. Rating advances to next item (or completion view).
//
// If drill generation fails (no API key, network error, JSON parse fail),
// the card falls back to showing the user's recent mistake on this rule
// and skips the reveal step — straight to rating.

import SwiftUI

struct ReviewSessionView: View {
    @StateObject private var session: ReviewSession
    @EnvironmentObject private var drillGenerator: DrillGenerator
    @Environment(\.dismiss) private var dismiss

    init(tracker: WeaknessTracker, repository: SessionRepository, store: SessionStore) {
        _session = StateObject(wrappedValue: ReviewSession(
            tracker: tracker,
            repository: repository,
            store: store
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 640, height: 600)
        .background(.regularMaterial)
        .task { await session.start() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "bird.fill")
                .foregroundStyle(Color.Vireo.correction)
            Text(headerTitle)
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerTitle: String {
        if session.isComplete { return "Review complete" }
        if session.totalCount == 0 { return "Review" }
        return "Review · \(session.currentNumber) of \(session.totalCount)"
    }

    @ViewBuilder
    private var content: some View {
        if session.isLoading {
            VStack { Spacer(); ProgressView(); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.isComplete {
            completionView
        } else if let current = session.current {
            ReviewCard(
                item: current.weakness,
                example: current.example,
                drillGenerator: drillGenerator,
                onRate: { grade in await session.rate(grade) }
            )
            .id(current.id)
        } else {
            VStack {
                Spacer()
                Text("Nothing due right now")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 46))
                .foregroundStyle(Color.Vireo.correction)
            Text(session.totalCount == 0 ? "No items due" : "All caught up")
                .font(.title2)
                .fontWeight(.semibold)
            if session.totalCount > 0 {
                let counts = session.ratingsTally
                Text("Reviewed \(session.totalCount) item\(session.totalCount == 1 ? "" : "s")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    tallyChip("Again", count: counts[.again] ?? 0, tint: Color.Vireo.mistake)
                    tallyChip("Hard", count: counts[.hard] ?? 0, tint: Color.Vireo.warning)
                    tallyChip("Good", count: counts[.good] ?? 0, tint: Color.Vireo.correction)
                    tallyChip("Easy", count: counts[.easy] ?? 0, tint: Color.Vireo.correctionHighlight)
                }
                .padding(.top, 4)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Color.Vireo.correction)
                .controlSize(.large)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tallyChip(_ label: String, count: Int, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(count > 0 ? tint : Color.secondary.opacity(0.5))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - ReviewCard (one item)

private struct ReviewCard: View {
    let item: WeaknessItem
    let example: Mistake?
    let drillGenerator: DrillGenerator
    let onRate: (Grade) async -> Void

    @State private var drill: Drill?
    @State private var drillError: String?
    @State private var revealed: Bool = false
    @State private var guess: String = ""
    @FocusState private var guessFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                categoryBanner(item.category)
                ruleSection
                Divider()
                drillSection
                if shouldShowRatings {
                    Divider()
                    ratingsRow
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .task { await loadDrill() }
    }

    private func loadDrill() async {
        guard drill == nil, drillError == nil else { return }
        do {
            drill = try await drillGenerator.drill(
                for: item.id ?? 0,
                rule: item.rule,
                example: example
            )
        } catch {
            drillError = error.localizedDescription
        }
    }

    private var ruleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rule")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(item.rule)
                .font(.system(.title3, design: .serif).weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var drillSection: some View {
        if let drill {
            drillCard(drill)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.smooth(duration: 0.25), value: revealed)
        } else if drillError != nil {
            fallbackExample
        } else {
            loadingDrill
        }
    }

    private var loadingDrill: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Generating a practice sentence…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var fallbackExample: some View {
        if let example {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your recent mistake")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .center, spacing: 8) {
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
                .font(.system(.callout, design: .monospaced))
                Text(example.explanation)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                if let drillError {
                    Text("Couldn't generate a fresh drill: \(drillError)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        } else {
            Text("No example available.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func drillCard(_ drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Practice")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if revealed {
                Text(buildHighlightedSentence(drill: drill))
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                guessResultRow(drill: drill)

                Text(drill.context)
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            } else {
                Text(drill.blank)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                TextField("Type your answer or skip", text: $guess)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .focused($guessFocused)
                    .onSubmit { reveal() }
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Button {
                        reveal()
                    } label: {
                        Label(guess.isEmpty ? "Reveal answer" : "Check", systemImage: "eye.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Vireo.correction)
                    .controlSize(.regular)
                    .keyboardShortcut(.return)

                    if !guess.isEmpty {
                        Button("Clear") { guess = "" }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { guessFocused = true }
    }

    private func reveal() {
        withAnimation(.smooth(duration: 0.22)) {
            revealed = true
        }
    }

    @ViewBuilder
    private func guessResultRow(drill: Drill) -> some View {
        let normalize: (String) -> String = {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let trimmedGuess = guess.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = !trimmedGuess.isEmpty && normalize(trimmedGuess) == normalize(drill.answer)
        let isSkipped = trimmedGuess.isEmpty

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Your guess")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if isSkipped {
                Text("(skipped)")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text("\u{201C}\(trimmedGuess)\u{201D}")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(isCorrect ? Color.Vireo.correction : Color.Vireo.mistake)
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isCorrect ? Color.Vireo.correction : Color.Vireo.mistake)
                if !isCorrect {
                    Text("· correct: ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text("\u{201C}\(drill.answer)\u{201D}")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Color.Vireo.correction)
                }
            }
            Spacer()
        }
    }

    /// Replace `___` in the drill's blank with the highlighted answer.
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

    private var shouldShowRatings: Bool {
        revealed || drill == nil  // drill nil = fallback, ratings always shown
    }

    private var ratingsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How well do you remember this rule?")
                .font(.callout.bold())
            HStack(spacing: 8) {
                ratingButton(.again, label: "Again", subLabel: "Forgot", tint: Color.Vireo.mistake)
                ratingButton(.hard, label: "Hard", subLabel: "Struggled", tint: Color.Vireo.warning)
                ratingButton(.good, label: "Good", subLabel: "Got it", tint: Color.Vireo.correction)
                ratingButton(.easy, label: "Easy", subLabel: "Instant", tint: Color.Vireo.correctionHighlight)
            }
        }
    }

    private func ratingButton(_ grade: Grade, label: String, subLabel: String, tint: Color) -> some View {
        Button {
            Task { await onRate(grade) }
        } label: {
            VStack(spacing: 2) {
                Text(label).font(.callout.bold())
                Text(subLabel).font(.caption2).opacity(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }

    private func categoryBanner(_ raw: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: categoryIcon(for: raw))
                .foregroundStyle(Color.Vireo.correction)
            Text(prettifiedCategory(raw))
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
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
        case "agreement": return "Subject-verb agreement"
        case "word_order": return "Word order"
        case "vocab": return "Vocabulary"
        case "spelling": return "Spelling"
        case "punctuation": return "Punctuation"
        case "l1_interference": return "Persian → English (L1)"
        case "other": return "Other"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
