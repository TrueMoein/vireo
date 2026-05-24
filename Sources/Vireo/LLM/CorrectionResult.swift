// CorrectionResult.swift — the single Codable struct both adapters decode to.
//
// Schema mirrors docs/llm-providers.md. Authored to OpenAI's stricter
// JSON-schema subset so it's portable across providers. snake_case in JSON,
// camelCase in Swift (via JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase
// at the call site).

import Foundation

struct CorrectionResult: Codable, Sendable {
    let correctedText: String
    let mistakes: [Mistake]
    /// The user's original text. NOT from the LLM — adapters populate
    /// this after decoding so downstream UI (the notch correction card)
    /// can render a word-level diff. Defaults to empty so callers that
    /// reconstruct the result from persistence don't have to bother.
    var originalText: String = ""
    /// The correction style that produced this result. Populated by the
    /// coordinator/adapter post-decode. Nil for results reconstructed
    /// from persistence (we don't store style IDs in the DB yet).
    var styleID: UUID?

    enum CodingKeys: String, CodingKey {
        case correctedText
        case mistakes
    }
}

extension CorrectionResult {
    struct Mistake: Codable, Sendable {
        let original: String
        let fixed: String
        let category: Category
        let rule: String
        let explanation: String
    }

    enum Category: String, Codable, Sendable, CaseIterable {
        case article
        case tense
        case preposition
        case agreement
        case wordOrder = "word_order"
        case vocab
        case spelling
        case punctuation
        case other

        /// Lenient decode so unknown categories from the model land in `.other`
        /// rather than failing the whole correction. Old persisted rows tagged
        /// `"l1_interference"` also fall through to `.other` here.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Category(rawValue: raw) ?? .other
        }
    }
}
