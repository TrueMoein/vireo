// OpenAIAdapter.swift — direct OpenAI API integration (future option).
//
// Vireo's primary adapter is OpenRouterAdapter, which can already route to
// OpenAI models. This direct adapter is a future option for users who want
// their own OpenAI API key without OpenRouter as middleware.
//
// Would use chat completions with strict structured output:
//   response_format: { type: "json_schema", strict: true, json_schema: ... }
//
// TODO: not in Phase 1 scope.

import Foundation
