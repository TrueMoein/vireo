// CoachEnglishIntent.swift — App Intent registering "Correct text with
// Vireo" with Shortcuts.app (and, on macOS 26+ with Apple Intelligence
// enabled and a Developer-ID-signed build, the Writing Tools sheet).
//
// The intent runs in-process when invoked from Shortcuts.app while Vireo
// is running, which lets us surface the correction in the notch via the
// shared AppCoordinator. When invoked while the app is suspended, the
// host process resolves the intent via App Intents extension dispatch —
// in that case `presenterBridge` is nil and we return the corrected text
// silently without notch UI.

import AppIntents
import AppKit
import Foundation
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "Intent")

/// A weak handle that the AppDelegate populates at launch, letting the
/// in-process intent invocation surface the correction in the notch
/// without requiring direct references between modules.
@MainActor
enum VireoIntentBridge {
    static weak var coordinator: AppCoordinator?
}

struct CorrectEnglishIntent: AppIntent {
    static let title: LocalizedStringResource = "Correct English"
    static let description = IntentDescription(
        "Send text through Vireo to get a grammar correction plus a per-mistake breakdown."
    )

    /// String literals duplicated from SettingsModel + CorrectionStyleStore
    /// because those types are @MainActor-isolated and the intent's
    /// `perform()` runs from a nonisolated context. Keep these in sync.
    static let keychainAccount = "openrouter"
    static let modelDefaultsKey = "co.vireo.selectedModel"
    static let defaultModel = "anthropic/claude-haiku-4.5"
    static let activeStyleDefaultsKey = "co.vireo.activeStyleID"
    static let customStylesDefaultsKey = "co.vireo.customStyles"

    @Parameter(
        title: "Text",
        description: "The English sentence or paragraph you want corrected.",
        inputOptions: String.IntentInputOptions(
            keyboardType: .default,
            capitalizationType: .sentences,
            multiline: true,
            autocorrect: false
        )
    )
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(value: text, dialog: "There's no text to correct.")
        }

        guard let apiKey = KeychainStore.shared
            .read(account: Self.keychainAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            return .result(
                value: text,
                dialog: "Vireo can't find an OpenRouter API key. Open Vireo's Settings and paste your key."
            )
        }
        let model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey)
            ?? Self.defaultModel

        // Resolve the active style from UserDefaults. We can't touch
        // CorrectionStyleStore directly (MainActor isolated); instead we
        // duplicate a thin slice of its logic for the nonisolated path.
        let activeStyle = Self.resolveActiveStyle()

        log.info("""
            Intent invoked: model=\(model, privacy: .public) \
            style=\(activeStyle.name, privacy: .public) \
            chars=\(trimmed.count, privacy: .public)
            """)

        let adapter = OpenRouterAdapter(
            apiKey: apiKey,
            model: model,
            systemPrompt: activeStyle.wrappedPrompt
        )
        do {
            let result = try await adapter.correct(trimmed)

            // If we're running in-process (Vireo is the active app or
            // running as accessory), mirror the correction into the notch
            // AND persist the session so it shows up in History and the
            // mistakes feed the weakness tracker. Out-of-process
            // invocations just return the corrected text — they don't get
            // notch UI or session tracking.
            let modelName = model
            let trimmedInput = trimmed
            await MainActor.run {
                guard let coordinator = VireoIntentBridge.coordinator else { return }
                Task { @MainActor in
                    await coordinator.notch.showCorrection(result)
                }
                if let repo = coordinator.sessionRepository {
                    let tracker = coordinator.weaknessTracker
                    let store = coordinator.sessionStore
                    Task.detached {
                        do {
                            try await repo.save(
                                rawText: trimmedInput,
                                result: result,
                                sourceApp: "Shortcuts",
                                model: modelName,
                                latencyMs: 0
                            )
                            try await tracker?.ingest(result: result)
                            await store?.reload()
                        } catch {
                            log.error("Intent persist failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            }

            let summary = result.mistakes.isEmpty
                ? "Looks clean — no fixes needed."
                : "Fixed \(result.mistakes.count) issue\(result.mistakes.count == 1 ? "" : "s")."
            return .result(value: result.correctedText, dialog: IntentDialog(stringLiteral: summary))
        } catch {
            log.error("Intent failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Resolve the currently-active style without touching the
    /// MainActor-isolated CorrectionStyleStore. Reads:
    ///   • `co.vireo.activeStyleID` — UUID string
    ///   • `co.vireo.customStyles` — JSON [CorrectionStyle]
    /// Falls back to Grammar Coach if either is missing or malformed.
    private static func resolveActiveStyle() -> CorrectionStyle {
        let activeID: UUID
        if let raw = UserDefaults.standard.string(forKey: activeStyleDefaultsKey),
           let parsed = UUID(uuidString: raw) {
            activeID = parsed
        } else {
            activeID = CorrectionStyle.grammarCoachID
        }

        if let style = CorrectionStyle.builtIns.first(where: { $0.id == activeID }) {
            return style
        }

        if let data = UserDefaults.standard.data(forKey: customStylesDefaultsKey),
           let customs = try? JSONDecoder().decode([CorrectionStyle].self, from: data),
           let match = customs.first(where: { $0.id == activeID }) {
            return match
        }

        return CorrectionStyle.grammarCoach
    }
}

/// Registers Vireo's intents with Shortcuts.app so they're discoverable
/// without the user constructing a custom shortcut. The phrases here
/// become Spotlight + Siri triggers (macOS 26 Apple Intelligence).
struct VireoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CorrectEnglishIntent(),
            phrases: [
                "Correct text with \(.applicationName)",
                "Fix grammar with \(.applicationName)",
                "Coach my English with \(.applicationName)",
            ],
            shortTitle: "Correct text",
            systemImageName: "bird.fill"
        )
    }
}
