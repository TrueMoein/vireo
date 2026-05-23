// AnthropicAdapter.swift — Anthropic Messages API with tool-use enforcement.
//
// Uses a single tool named `return_correction` with input_schema matching
// CorrectionResult. tool_choice = { type: "tool", name: "return_correction" }
// guarantees a schema-conformant tool call back.
//
// TODO: implement in Phase 1.

import Foundation
