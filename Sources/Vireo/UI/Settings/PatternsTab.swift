// PatternsTab.swift — Settings tab surfacing the user's recurring mistake
// patterns. Categories ranked by count, expandable to show the specific
// rules the model has called out repeatedly.

import SwiftUI

struct PatternsTab: View {
    @EnvironmentObject var store: SessionStore
    @State private var expandedCategory: String?

    var body: some View {
        VStack(spacing: 0) {
            if store.unavailable {
                unavailableState
            } else if store.patterns.isEmpty {
                emptyState
            } else {
                introBanner
                Divider()
                patternsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { Task { await store.reloadPatterns() } }
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
