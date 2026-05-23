// SettingsModel.swift — observable settings store, bridges UI ↔ Keychain.

import Foundation
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var model: String = SettingsModel.defaultModel

    static let defaultModel = "anthropic/claude-haiku-4.5"
    static let keychainAccount = "openrouter"
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
