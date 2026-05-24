// DrillGenerator.swift — on-demand LLM-generated practice sentences for
// review sessions. In-memory cache keyed by weakness item id so a drill
// is fetched once per session, not per render.

import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "co.vireo", category: "DrillGenerator")

@MainActor
final class DrillGenerator: ObservableObject {
    let settings: SettingsModel
    private var cache: [Int64: Drill] = [:]

    init(settings: SettingsModel) {
        self.settings = settings
    }

    /// Returns a cached drill or generates a new one via OpenRouter.
    func drill(for itemId: Int64, rule: String, example: Mistake?) async throws -> Drill {
        if let cached = cache[itemId] { return cached }

        let trimmedKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw DrillError.noAPIKey }
        let trimmedModel = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else { throw DrillError.noModel }

        let adapter = OpenRouterAdapter(apiKey: trimmedKey, model: trimmedModel)
        let drill = try await adapter.generateDrill(rule: rule, example: example)
        cache[itemId] = drill
        log.info("Generated drill for #\(itemId, privacy: .public)")
        return drill
    }

    /// Clear the cache (e.g., between review sessions or when settings change).
    func reset() {
        cache.removeAll()
    }

    enum DrillError: LocalizedError {
        case noAPIKey
        case noModel

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No OpenRouter API key set."
            case .noModel: return "No model selected."
            }
        }
    }
}
