// SettingsModel.swift — observable settings store, bridges UI ↔ Keychain.

import Foundation
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var apiKey: String = "" {
        didSet { persistAPIKey() }
    }
    @Published var model: String = SettingsModel.defaultModel {
        didSet { persistModel() }
    }
    @Published var streamingEnabled: Bool = true {
        didSet { persistStreamingEnabled() }
    }
    @Published var testResult: TestResult = .idle

    enum TestResult {
        case idle
        case running
        case success(CorrectionResult)
        case failure(String)
    }

    static let defaultModel = "anthropic/claude-haiku-4.5"
    static let keychainAccount = "openrouter"
    static let testSentence = "I want create new feature for app, but I dont know if my boss agree with it."

    private static let modelDefaultsKey = "co.vireo.selectedModel"
    private static let streamingDefaultsKey = "co.vireo.streamingEnabled"
    private let keychain = KeychainStore.shared

    init() {
        apiKey = keychain.read(account: Self.keychainAccount) ?? ""
        model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.defaultModel
        // Default to on; respect an explicit user toggle if present.
        if UserDefaults.standard.object(forKey: Self.streamingDefaultsKey) != nil {
            streamingEnabled = UserDefaults.standard.bool(forKey: Self.streamingDefaultsKey)
        }
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Persist both fields. Used by testConnection() as a defensive flush
    /// before firing a network call.
    func save() {
        persistAPIKey()
        persistModel()
    }

    private func persistAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychain.delete(account: Self.keychainAccount)
        } else {
            keychain.write(account: Self.keychainAccount, value: trimmed)
        }
    }

    private func persistModel() {
        UserDefaults.standard.set(model, forKey: Self.modelDefaultsKey)
    }

    private func persistStreamingEnabled() {
        UserDefaults.standard.set(streamingEnabled, forKey: Self.streamingDefaultsKey)
    }

    /// Persist current key/model, then send a sample sentence through the
    /// configured OpenRouter model and surface the corrected output.
    func testConnection() async {
        save()

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            testResult = .failure("No API key set.")
            return
        }
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            testResult = .failure("No model set.")
            return
        }

        testResult = .running
        let adapter = OpenRouterAdapter(apiKey: trimmedKey, model: trimmedModel)
        do {
            let result = try await adapter.correct(Self.testSentence)
            testResult = .success(result)
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }
}
