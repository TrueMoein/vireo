// ReviewSessionView.swift — sheet UI for one review run.
//
// Shows each due weakness item: rule, an example of the user's own recent
// mistake in this pattern, and four rating buttons (Again / Hard / Good /
// Easy) wired to the SM-2 scheduler. On completion shows a tally and a
// "Done" button.

import SwiftUI

struct ReviewSessionView: View {
    @StateObject private var session: ReviewSession
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
        .frame(width: 620, height: 560)
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
            reviewCard(item: current)
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

    private func reviewCard(item: ReviewSession.Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                categoryBanner(item.weakness.category)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Rule")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(item.weakness.rule)
                        .font(.system(.title3, design: .serif).weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let example = item.example {
                    Divider()
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
                    }
                }

                Divider()

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

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func ratingButton(_ grade: Grade, label: String, subLabel: String, tint: Color) -> some View {
        Button {
            Task { await session.rate(grade) }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.callout.bold())
                Text(subLabel)
                    .font(.caption2)
                    .opacity(0.85)
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
