// OpenAIAdapter.swift — OpenAI chat-completions with strict structured output.
//
// response_format: { type: "json_schema", strict: true, json_schema: ... }
// Token-level constrained on gpt-4o-2024-08-06+. Decode straight into
// CorrectionResult. Bounded retry on DecodingError with re-prompt.
//
// TODO: implement in Phase 4.

import Foundation
