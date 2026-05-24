// HistoryTab.swift — Settings tab listing past corrections with search.

import SwiftUI

struct HistoryTab: View {
    @EnvironmentObject var store: SessionStore
    @State private var searchQuery = ""
    @State private var expandedID: Int64?
    @State private var expandedMistakes: [Mistake] = []

    var body: some View {
        VStack(spacing: 0) {
            if store.unavailable {
                unavailableState
            } else {
                searchBar
                Divider()
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // .onAppear fires on every tab switch back to History; .task only
        // fires once when the view is first created. Belt-and-suspenders so
        // newly-saved corrections show up reliably.
        .onAppear { Task { await store.reload(search: searchQuery) } }
        .onChange(of: searchQuery) { _, q in
            Task { await store.reload(search: q) }
        }
    }

    // MARK: - States

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38))
                .foregroundStyle(Color.Vireo.warning)
            Text("History unavailable")
                .font(.headline)
            Text("Vireo couldn't open its database at launch. Check the console for details.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search corrections", text: $searchQuery)
                .textFieldStyle(.plain)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                Task { await store.reload(search: searchQuery) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.sessions.isEmpty {
            VStack { Spacer(); ProgressView(); Spacer() }
        } else if store.sessions.isEmpty {
            emptyState
        } else {
            sessionList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bird")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.55))
            Text(searchQuery.isEmpty ? "No corrections yet" : "No matches")
                .font(.headline)
                .foregroundStyle(.secondary)
            if searchQuery.isEmpty {
                Text("Select text in any app and press ⌥⇧Space\n— or click the floating bird that appears.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.sessions) { session in
                    sessionRow(session)
                    Divider()
                }
                statsFooter
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        let isExpanded = expandedID == session.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Task { await toggle(session) }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(session.timestamp, style: .relative)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let app = session.sourceApp {
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(app)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(session.correctedText)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedDetail(for: session)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
        .background(isExpanded ? AnyShapeStyle(.primary.opacity(0.03)) : AnyShapeStyle(Color.clear))
    }

    private func expandedDetail(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Original")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(session.rawText)
                .font(.callout)
                .foregroundStyle(Color.Vireo.mistake.opacity(0.85))
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !expandedMistakes.isEmpty {
                Divider().padding(.vertical, 4)
                Text("\(expandedMistakes.count) fix\(expandedMistakes.count == 1 ? "" : "es")")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(expandedMistakes) { m in
                    mistakeRow(m)
                }
            }

            if let model = session.model {
                Text(model)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func mistakeRow(_ m: Mistake) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(m.originalPhrase)
                    .strikethrough()
                    .foregroundStyle(Color.Vireo.mistake)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(m.fixedPhrase)
                    .foregroundStyle(Color.Vireo.correction)
                    .bold()
            }
            .font(.system(.callout, design: .monospaced))
            Text("\(m.category) · \(m.rule)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(m.explanation)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.82))
        }
    }

    private var statsFooter: some View {
        Text("\(store.totalCount) correction\(store.totalCount == 1 ? "" : "s") total")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private func toggle(_ session: Session) async {
        if expandedID == session.id {
            expandedID = nil
            expandedMistakes = []
        } else {
            expandedID = session.id
            expandedMistakes = await store.mistakes(for: session)
        }
    }
}
