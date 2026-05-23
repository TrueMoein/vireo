// SettingsView.swift — Vireo settings.
//
// Phase 1 minimal: Provider (API key + model), Hotkey (KeyboardShortcuts
// recorder), Permissions (Accessibility status + deep-link), and a Test
// connection that sends a sample sentence through the configured model
// and shows the structured correction inline + in the notch.

import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject var notchPresenter: NotchPresenter
    @EnvironmentObject var permission: AccessibilityPermission
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

    private var isRunning: Bool {
        if case .running = settings.testResult { return true }
        return false
    }

    var body: some View {
        Form {
            providerSection
            modelSection
            hotkeySection
            permissionsSection
            actionsSection
            testResultSection
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 760)
        .onAppear { permission.refresh() }
    }

    // MARK: - Sections

    private var providerSection: some View {
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
    }

    private var modelSection: some View {
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
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hotkeySection: some View {
        Section("Hotkey") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Correct selection")
                    Text("Select text anywhere, press this combination.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                KeyboardShortcuts.Recorder(for: .correctSelection)
            }
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        Section("Permissions") {
            HStack(alignment: .top, spacing: 10) {
                if permission.isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility granted")
                            .font(.callout)
                        Text("Vireo can read selected text and post the ⌘C used to capture it.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility not granted")
                            .font(.callout)
                        Text("Vireo needs this to read selected text from other apps. After granting, quit and relaunch Vireo.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open System Settings…") {
                            permission.openSystemSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 2)
                    }
                    Spacer()
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            HStack(spacing: 12) {
                Button("Save") {
                    settings.save()
                    saveConfirmation = "Saved"
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        saveConfirmation = nil
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button(isRunning ? "Testing…" : "Test connection") {
                    Task {
                        await settings.testConnection()
                        if case .success(let result) = settings.testResult {
                            await notchPresenter.showCorrection(result)
                        }
                    }
                }
                .disabled(!settings.hasAPIKey || isRunning)

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

    private var testResultSection: some View {
        Section("Test result") {
            testResultView
        }
    }

    @ViewBuilder
    private var testResultView: some View {
        switch settings.testResult {
        case .idle:
            Text("Click \u{201C}Test connection\u{201D} to send a sample sentence through your configured model and see the structured correction.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asking \(settings.model)…").font(.caption).foregroundStyle(.secondary)
            }
        case .success(let result):
            VStack(alignment: .leading, spacing: 10) {
                labeledRow("Original", SettingsModel.testSentence)
                labeledRow("Corrected", result.correctedText, accent: .green)
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
                .foregroundStyle(.red)
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
                Text(m.original).strikethrough().foregroundStyle(.red)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                Text(m.fixed).foregroundStyle(.green).bold()
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
