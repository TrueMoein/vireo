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
    private let keychain = KeychainStore.shared

    init() {
        apiKey = keychain.read(account: Self.keychainAccount) ?? ""
        model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.defaultModel
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
