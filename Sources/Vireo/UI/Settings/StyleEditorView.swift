// StyleEditorView.swift — sheet for creating or editing a custom
// correction style.
//
// Fields:
//   • Name + subtitle (TextFields)
//   • Icon picker — horizontal scroll of SF Symbols, single-tap pick
//   • System prompt — multi-line TextEditor, with a footer hint that
//     Vireo automatically appends the JSON-return contract so the user
//     only writes the intent.
//
// Save validates name and prompt are non-empty.

import SwiftUI

struct StyleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CorrectionStyle
    let onSave: (CorrectionStyle) -> Void

    init(style: CorrectionStyle, onSave: @escaping (CorrectionStyle) -> Void) {
        _draft = State(initialValue: style)
        self.onSave = onSave
    }

    private static let iconOptions: [String] = [
        "sparkles", "graduationcap.fill", "briefcase.fill", "message.fill",
        "scissors", "lightbulb.fill", "wand.and.stars", "pencil.tip",
        "text.bubble.fill", "envelope.fill", "doc.text.fill", "quote.opening",
        "person.fill", "globe", "bolt.fill", "leaf.fill",
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameField
                    subtitleField
                    iconField
                    promptField
                    contractHint
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 560)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            Image(systemName: draft.icon)
                .foregroundStyle(Color.Vireo.correction)
                .imageScale(.large)
            Text(draft.id == CorrectionStyle.grammarCoachID ? "Edit style" : draft.name.isEmpty ? "New style" : draft.name)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name").font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
            TextField("e.g. Slack tone", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
    }

    private var subtitleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Description").font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
            TextField("One short line describing the style", text: $draft.subtitle)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
    }

    private var iconField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Icon").font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.iconOptions, id: \.self) { name in
                        Button {
                            draft.icon = name
                        } label: {
                            Image(systemName: name)
                                .font(.body)
                                .foregroundStyle(draft.icon == name ? Color.Vireo.correction : .secondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(draft.icon == name
                                              ? Color.Vireo.correction.opacity(0.12)
                                              : Color.secondary.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            draft.icon == name ? Color.Vireo.correction.opacity(0.5) : .clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var promptField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("System prompt").font(.caption.bold()).foregroundStyle(.secondary).textCase(.uppercase)
            TextEditor(text: $draft.systemPrompt)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 160)
                .padding(8)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.18), lineWidth: 0.5)
                )
        }
    }

    private var contractHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .imageScale(.small)
            Text("Write the intent only. Vireo automatically appends the JSON-return contract so the model produces a Vireo-compatible response — you don't have to specify the schema yourself.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Save") {
                onSave(draft)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.Vireo.correction)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(16)
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
