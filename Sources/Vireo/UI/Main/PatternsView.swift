// PatternsTab.swift — Settings tab surfacing the user's recurring mistake
// patterns. Categories ranked by count, expandable to show the specific
// rules the model has called out repeatedly.

import SwiftUI

struct PatternsView: View {
    @EnvironmentObject var store: SessionStore
    @State private var expandedCategory: String?
    @State private var showReview = false

    var body: some View {
        VStack(spacing: 0) {
            if store.unavailable {
                unavailableState
            } else if store.patterns.isEmpty {
                emptyState
            } else {
                coachSummary
                Divider()
                patternsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { Task { await store.reloadPatterns() } }
    }

    private var coachSummary: some View {
        let s = store.weaknessSummary
        return HStack(spacing: 14) {
            summaryStat(label: "Active", value: s.active, color: Color.Vireo.correction)
            Divider().frame(height: 36)
            summaryStat(label: "Due now", value: s.dueNow, color: s.dueNow > 0 ? Color.Vireo.accent : .secondary)
            Divider().frame(height: 36)
            summaryStat(label: "Watching", value: s.watching, color: .secondary)
            Divider().frame(height: 36)
            summaryStat(label: "Mastered", value: s.mastered, color: .secondary)
            Spacer()
            Button {
                showReview = true
            } label: {
                Label("Start review", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Vireo.correction)
            .disabled(s.dueNow == 0)
            .help(s.dueNow == 0 ? "No items are due for review yet — keep using Vireo." : "Review \(s.dueNow) due item\(s.dueNow == 1 ? "" : "s")")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sheet(isPresented: $showReview) {
            if let tracker = store.weaknessTracker, let repo = store.repository {
                ReviewSessionView(tracker: tracker, repository: repo, store: store)
            } else {
                Text("Review unavailable — database isn't open.")
                    .padding()
            }
        }
    }

    private func summaryStat(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    // MARK: - States

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38))
                .foregroundStyle(Color.Vireo.warning)
            Text("Patterns unavailable")
                .font(.headline)
            Text("Vireo couldn't open its database at launch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.55))
            Text("No patterns yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Once you've made a few corrections, the categories and rules\nyou trip on most often will show up here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var introBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .foregroundStyle(Color.Vireo.correction)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your most frequent patterns")
                    .font(.headline)
                Text("Tap a category to see the specific rules. Use this to know what to focus on between sessions.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var patternsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.patterns) { pattern in
                    categoryRow(pattern)
                    Divider()
                }
            }
        }
    }

    private func categoryRow(_ pattern: CategoryPattern) -> some View {
        let isExpanded = expandedCategory == pattern.category
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isExpanded {
                    expandedCategory = nil
                } else {
                    expandedCategory = pattern.category
                }
            } label: {
                HStack(spacing: 12) {
                    categoryIcon(for: pattern.category)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prettifiedCategory(pattern.category))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(pattern.totalCount) mistake\(pattern.totalCount == 1 ? "" : "s") · \(pattern.rules.count) rule\(pattern.rules.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    countChip(pattern.totalCount)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pattern.rules) { rule in
                        ruleRow(rule, maxCount: pattern.rules.first?.count ?? 1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(isExpanded ? AnyShapeStyle(.primary.opacity(0.03)) : AnyShapeStyle(Color.clear))
    }

    private func ruleRow(_ rule: RulePattern, maxCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rule.rule)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ProgressView(value: Double(rule.count), total: Double(max(maxCount, 1)))
                    .progressViewStyle(.linear)
                    .tint(Color.Vireo.correction)
                    .frame(maxWidth: 220)
                Text("\(rule.count)×")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func countChip(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.Vireo.correction)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.Vireo.correction.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func categoryIcon(for category: String) -> some View {
        let symbolName: String = {
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
        }()
        Image(systemName: symbolName)
            .font(.title3)
            .foregroundStyle(Color.Vireo.correction)
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
