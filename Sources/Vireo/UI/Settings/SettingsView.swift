// SettingsView.swift — Vireo settings.
//
// Phase 1 minimal: Provider section (API key + model picker). Full polish
// (capture toggles, behavior, privacy, diagnostics, about) lands in Phase 7.
//
// Model picker UX:
//   - Free-text field accepting any OpenRouter model id
//   - "Recommended (≥30B params)" quick-picks
//   - Dismissible warning when a known sub-30B model is entered

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsModel
    @State private var saveConfirmation: String?

    private static let recommendedModels = [
        "anthropic/claude-haiku-4.5",
        "google/gemini-3.1-flash",
        "openai/gpt-4o-mini",
        "mistralai/mistral-large",
    ]

    private static let knownSubThirtyB: Set<String> = [
        "ibm-granite/granite-4.1-8b",
        "ibm-granite/granite-4.1-3b",
        "meta-llama/llama-3.2-3b",
        "meta-llama/llama-3.2-1b",
        "google/gemma-2-2b",
        "microsoft/phi-3.5-mini",
    ]

    private var showsSubThirtyBWarning: Bool {
        Self.knownSubThirtyB.contains(settings.model.lowercased())
    }

    var body: some View {
        Form {
            Section("OpenRouter") {
                SecureField("API key", text: $settings.apiKey, prompt: Text("sk-or-v1-…"))
                    .textContentType(.password)

                HStack(spacing: 4) {
                    Text("Get a key at")
                    Link("openrouter.ai/keys", destination: URL(string: "https://openrouter.ai/keys")!)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Model") {
                TextField("Model identifier", text: $settings.model, prompt: Text("vendor/model-name"))
                    .font(.system(.body, design: .monospaced))

                if showsSubThirtyBWarning {
                    Label("Smaller models may produce unreliable structured output for grammar coaching. ≥30B params is recommended.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended (≥30B)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(Self.recommendedModels, id: \.self) { name in
                        Button {
                            settings.model = name
                        } label: {
                            HStack {
                                Text(name)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                if settings.model == name {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                HStack {
                    Button("Save") {
                        settings.save()
                        saveConfirmation = "Saved"
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            saveConfirmation = nil
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)

                    if let confirmation = saveConfirmation {
                        Label(confirmation, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .transition(.opacity)
                    }

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 520)
    }
}
