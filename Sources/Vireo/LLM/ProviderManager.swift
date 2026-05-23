// ProviderManager.swift — provider/model routing + retries.
//
// v0.1 wires a single OpenRouterAdapter and routes calls by feature:
//   - "fast" routing      — default: ibm-granite/granite-4.1-8b
//                           (user preference; swap in Settings to
//                            google/gemini-3.1-flash-lite or anthropic/
//                            claude-haiku-4.5 if quality issues surface)
//   - "quality" routing   — default: anthropic/claude-opus-4.7 for the
//                           rare review-exercise generation in Phase 5
//
// Per-model capability map says whether we can request strict JSON Schema
// or must fall back to loose JSON mode + post-validation.
//
// Bounded retry on DecodingError with re-prompt including the validation
// error message; surface a clean error if the retry fails. No silent
// fallback.
//
// TODO: implement in Phase 1.

import Foundation
