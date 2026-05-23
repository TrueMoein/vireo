// CorrectionResult.swift — the single Codable struct both adapters decode to.
//
// Source of truth for the correction payload. Schema is authored to OpenAI's
// stricter JSON-schema subset (no oneOf, no default, additionalProperties:
// false) so it works for both providers.
//
// TODO: define schema in Phase 1. Mirror in docs/llm-providers.md.

import Foundation

struct CorrectionResult: Codable, Sendable {
}
