// OpenRouterAdapter.swift — primary LLM adapter for v0.1, via OpenRouter.
//
// OpenRouter (openrouter.ai) is an OpenAI-compatible aggregator that gives
// access to ~100 models behind one API key. The model name is a runtime
// setting, e.g.:
//   - ibm-granite/granite-4.1-8b
//   - google/gemini-3.1-flash-lite
//   - anthropic/claude-haiku-4.5
//   - openai/gpt-4o-mini
//
// Endpoint:
//   POST https://openrouter.ai/api/v1/chat/completions
//   Authorization: Bearer <OPENROUTER_API_KEY>
//   (Optional) HTTP-Referer: https://github.com/<you>/vireo
//   (Optional) X-Title: Vireo
//
// Structured output strategy:
//   - Capable models (OpenAI 4o+, Gemini, some others) → strict JSON schema:
//       response_format: { type: "json_schema", strict: true, json_schema: ... }
//   - Other models → loose JSON mode + post-validation, bounded retry:
//       response_format: { type: "json_object" }
//   - Per-model capability map lives in ProviderManager.
//
// Auth source:
//   - Production: Keychain (KeychainStore service "co.vireo", account
//     "openrouter")
//   - Development: ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
//
// TODO: implement in Phase 1.

import Foundation
