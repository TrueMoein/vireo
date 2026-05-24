// StylesTab.swift — Settings tab for managing correction styles.
//
// Layout:
//   • Active style card — large, with name + subtitle + Edit/Duplicate.
//   • All styles list — pick active (tap row icon); per-row menu for
//     Set active / Duplicate / Edit / Delete (Delete + Edit only on
//     custom styles).
//   • Footer button: "+ New style from scratch" opens the editor.

import SwiftUI

struct StylesTab: View {
    @EnvironmentObject var styleStore: CorrectionStyleStore
    @State private var editing: CorrectionStyle?
    @State private var isPresentingNew: Bool = false

    var body: some View {
        Form {
            activeSection
            allStylesSection
            newStyleSection
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .sheet(item: $editing) { style in
            StyleEditorView(style: style) { saved in
                if style.isBuiltIn {
                    // Editing a built-in is never reached (UI hides Edit on built-ins),
                    // but defensively treat it as a "save as custom" path.
                    styleStore.add(saved)
                } else if styleStore.customStyles.contains(where: { $0.id == saved.id }) {
                    styleStore.update(saved)
                } else {
                    styleStore.add(saved)
                }
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            StyleEditorView(style: blankCustomStyle()) { saved in
                styleStore.add(saved)
            }
        }
    }

    private func blankCustomStyle() -> CorrectionStyle {
        CorrectionStyle(
            id: UUID(),
            name: "Untitled style",
            subtitle: "",
            icon: "sparkles",
            systemPrompt: "Describe how you want the user's text transformed. e.g. \"Rewrite as a polite reminder.\"",
            isBuiltIn: false
        )
    }

    // MARK: - Active card

    private var activeSection: some View {
        Section("Active style") {
            let active = styleStore.activeStyle
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: active.icon)
                    .font(.title2)
                    .foregroundStyle(Color.Vireo.correction)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(active.name)
                        .font(.headline)
                    Text(active.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !active.isBuiltIn {
                    Button("Edit") { editing = active }
                        .controlSize(.small)
                }
                Button("Duplicate") {
                    let copy = styleStore.duplicate(active)
                    editing = copy
                }
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - All styles list

    private var allStylesSection: some View {
        Section("All styles") {
            ForEach(styleStore.allStyles) { style in
                styleRow(style)
            }
        }
    }

    private func styleRow(_ style: CorrectionStyle) -> some View {
        let isActive = style.id == styleStore.activeStyleID
        return HStack(alignment: .center, spacing: 12) {
            Button {
                styleStore.setActive(style.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : style.icon)
                        .font(.body)
                        .foregroundStyle(isActive ? Color.Vireo.correction : Color.secondary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(style.name).font(.callout.weight(.medium))
                            if !style.isBuiltIn {
                                Text("Custom")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(style.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Set as active") { styleStore.setActive(style.id) }
                Button("Duplicate") {
                    let copy = styleStore.duplicate(style)
                    editing = copy
                }
                if !style.isBuiltIn {
                    Button("Edit") { editing = style }
                    Divider()
                    Button("Delete", role: .destructive) { styleStore.delete(id: style.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
        }
    }

    // MARK: - New style footer

    private var newStyleSection: some View {
        Section {
            Button {
                isPresentingNew = true
            } label: {
                Label("New style from scratch", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.Vireo.correction)
            }
            .buttonStyle(.plain)
        }
    }
}
