// OpenRouterAdapter.swift — primary LLM adapter for v0.1, via OpenRouter.
//
// OpenRouter (openrouter.ai) is an OpenAI-compatible aggregator that gives
// access to ~100 models behind one API key. The model name is a runtime
// setting the user picks in Settings, e.g.:
//   - anthropic/claude-haiku-4.5     (default, ~70B class)
//   - google/gemini-3.1-flash
//   - openai/gpt-4o-mini
//   - mistralai/mistral-large        (123B)
// Smaller models (e.g., ibm-granite/granite-4.1-8b, llama-3.2-3b) are
// allowed but the UI surfaces a "≥30B recommended" warning — at 8B and
// below, structured-output reliability for grammar nuance degrades.
//
// Endpoint:
//   POST https://openrouter.ai/api/v1/chat/completions
//   Authorization: Bearer <OPENROUTER_API_KEY>
//   (Optional) HTTP-Referer: https://github.com/<you>/vireo
//   (Optional) X-Title: Vireo
//
// Structured output strategy:
//   - Capable models (OpenAI 4o+, Gemini, Claude via OpenRouter) → strict
//     JSON schema: response_format: { type: "json_schema",
//     strict: true, json_schema: ... }
//   - Other models → loose JSON mode + post-validation, bounded retry:
//     response_format: { type: "json_object" }
//   - Per-model capability map lives in ProviderManager.
//
// API key source, in priority order:
//   1. Keychain  (production / after user pastes key in Settings UI)
//   2. .env file in the repo root (dev convenience; see .env.example)
//   3. ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
//      (CI / one-off `export ... && swift run`)
//
// TODO: implement in Phase 1.

import Foundation
