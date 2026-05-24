// ProviderTab.swift — Settings tab for OpenRouter API key + model picker +
// Test connection.

import SwiftUI

struct ProviderTab: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var notchPresenter: NotchPresenter

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

    private var isRunning: Bool {
        if case .running = settings.testResult { return true }
        return false
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
                    Label(
                        "Smaller models may produce unreliable structured output for grammar coaching. ≥30B params is recommended.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(Color.Vireo.warning)
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
                                        .foregroundStyle(Color.Vireo.correction)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Output") {
                Toggle(isOn: $settings.streamingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stream the corrected text as it's generated")
                        Text("Makes the correction appear word-by-word in the notch instead of all at once. Turn off if your provider doesn't stream reliably.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section("Test connection") {
                HStack {
                    Button(isRunning ? "Testing…" : "Run test") {
                        Task {
                            await settings.testConnection()
                            if case .success(let result) = settings.testResult {
                                await notchPresenter.showCorrection(result)
                            }
                        }
                    }
                    .disabled(!settings.hasAPIKey || isRunning)
                    Spacer()
                }
                testResultView
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var testResultView: some View {
        switch settings.testResult {
        case .idle:
            Text("Sends a sample sentence through your configured model. Result also appears in the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asking \(settings.model)…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success(let result):
            VStack(alignment: .leading, spacing: 8) {
                labeledRow("Original", SettingsModel.testSentence)
                labeledRow("Corrected", result.correctedText, accent: Color.Vireo.correction)
                if !result.mistakes.isEmpty {
                    Divider()
                    Text("Mistakes (\(result.mistakes.count))").font(.caption.bold())
                    ForEach(result.mistakes.indices, id: \.self) { i in
                        mistakeRow(result.mistakes[i])
                    }
                } else {
                    Text("No mistakes returned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .failure(let msg):
            Label(msg, systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(Color.Vireo.mistake)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private func labeledRow(_ label: String, _ text: String, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(accent ?? .primary)
                .textSelection(.enabled)
        }
    }

    private func mistakeRow(_ m: CorrectionResult.Mistake) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(m.original).strikethrough().foregroundStyle(Color.Vireo.mistake)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                Text(m.fixed).foregroundStyle(Color.Vireo.correction).bold()
            }
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)

            Text("\(m.category.rawValue) · \(m.rule)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(m.explanation)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.85))
        }
        .padding(.vertical, 4)
    }
}
