// AnthropicAdapter.swift — direct Anthropic API integration (future option).
//
// Vireo's primary adapter is OpenRouterAdapter, which can already route to
// Anthropic models. This direct adapter is a future option for users who
// want their own Anthropic API key without going through OpenRouter
// (cost transparency, prompt-caching support, org compliance).
//
// Would use Anthropic Messages API with tool-use enforcement: a single tool
// `return_correction` with input_schema matching CorrectionResult, and
// tool_choice = { type: "tool", name: "return_correction" }.
//
// TODO: not in Phase 1 scope.

import Foundation
