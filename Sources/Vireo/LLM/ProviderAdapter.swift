// ProviderAdapter.swift — provider protocol.
//
// Each adapter (Anthropic, OpenAI, future Gemini/Ollama) implements this and
// returns the same CorrectionResult Codable. Single JSON Schema, two
// enforcement modes (Anthropic tool-use vs OpenAI strict structured output).
//
// TODO: implement in Phase 1.

import Foundation

protocol ProviderAdapter: Sendable {
    func correct(_ text: String) async throws -> CorrectionResult
}
