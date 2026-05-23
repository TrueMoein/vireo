// ProviderManager.swift — provider/model routing + retries.
//
// Selects which ProviderAdapter handles which call based on user settings:
//   - "fast" routing      — default: Claude Haiku 4.5
//   - "quality" routing   — default: Claude Opus 4.7 (review exercises)
//
// Bounded retry on DecodingError with re-prompt including the validation
// error message; surface clean error if retry fails. No silent fallback.
//
// TODO: implement in Phase 1.

import Foundation
