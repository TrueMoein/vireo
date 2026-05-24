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
