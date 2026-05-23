// SettingsModel.swift — observable settings store, bridges UI ↔ Keychain.

import Foundation
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var model: String = SettingsModel.defaultModel
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
        let savedKey = keychain.read(account: Self.keychainAccount) ?? ""
        apiKey = savedKey.isEmpty ? (Self.loadDevKeyFromDotenv() ?? "") : savedKey
        model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.defaultModel
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychain.delete(account: Self.keychainAccount)
        } else {
            keychain.write(account: Self.keychainAccount, value: trimmed)
        }
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

    // Dev convenience: load OPENROUTER_API_KEY from `.env` in the repo root
    // when Keychain is empty. Tries common paths so this works for both
    // `swift run` (cwd is repo root) and Xcode (cwd is DerivedData).
    // Production app bundles never see this file.
    private static func loadDevKeyFromDotenv() -> String? {
        if let v = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !v.isEmpty {
            return v
        }
        let candidates: [URL] = [
            URL(fileURLWithPath: ".env"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Projects/vireo/.env"),
        ]
        for url in candidates {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for raw in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty, !line.hasPrefix("#") else { continue }
                let prefix = "OPENROUTER_API_KEY="
                if line.hasPrefix(prefix) {
                    let value = String(line.dropFirst(prefix.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if !value.isEmpty { return value }
                }
            }
        }
        return nil
    }
}
