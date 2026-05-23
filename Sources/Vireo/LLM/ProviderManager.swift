// ProviderManager.swift — provider/model routing + retries.
//
// v0.1 wires a single OpenRouterAdapter and routes calls by feature:
//   - "fast" routing      — default: anthropic/claude-haiku-4.5
//                           (~70B, fast, cheap, excellent at structured
//                            output; user can swap in Settings to any
//                            OpenRouter model — we recommend ≥30B for
//                            reliable grammar nuance and structured output)
//   - "quality" routing   — default: anthropic/claude-opus-4.7 for the
//                           rare review-exercise generation in Phase 5
//
// Per-model capability map says whether we can request strict JSON Schema
// or must fall back to loose JSON mode + post-validation. Smaller models
// (e.g., granite-4.1-8b) are allowed but always use loose JSON + retry.
//
// Bounded retry on DecodingError with re-prompt including the validation
// error message; surface a clean error if the retry fails. No silent
// fallback.
//
// TODO: implement in Phase 1.

import Foundation
