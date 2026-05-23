# LLM providers

Vireo speaks to LLMs through `ProviderAdapter`. Each adapter sends the user's
text + the standard correction prompt to its provider, requests a
schema-conformant structured response, and decodes into the same
`CorrectionResult` Codable.

## v0.1: OpenRouter as the single adapter

Vireo ships with **`OpenRouterAdapter`** as the only enabled adapter.
[OpenRouter](https://openrouter.ai) is an OpenAI-compatible aggregator that
gives access to ~100 models behind one API key. This means: one Keychain
entry, one auth flow, one HTTP client — and the user picks any model at
runtime from Settings.

Defaults shipped:

| Routing | Default model | Why |
|---|---|---|
| Fast (every correction) | `ibm-granite/granite-4.1-8b` | Cheap, fast. Watch reliability of structured output at 8B; easy to swap. |
| Quality (review-exercise generation, Phase 5) | `anthropic/claude-opus-4.7` | Rare call, quality matters. |

Endpoint: `POST https://openrouter.ai/api/v1/chat/completions`
Auth: `Authorization: Bearer <OPENROUTER_API_KEY>`

## Direct-provider adapters (future)

`AnthropicAdapter.swift` and `OpenAIAdapter.swift` are placeholder skeletons
for users who want their own per-provider key (cost transparency,
prompt-caching support, org compliance). Not in v0.1 scope.

## The schema

Author once, enforce twice. Written to OpenAI's stricter JSON-schema subset
(no `oneOf`, no `default`, `additionalProperties: false`) so it's portable.

```jsonc
{
  "type": "object",
  "additionalProperties": false,
  "required": ["corrected_text", "mistakes"],
  "properties": {
    "corrected_text": {
      "type": "string",
      "description": "Full corrected version of the input, preserving the user's voice and intent."
    },
    "mistakes": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["original", "fixed", "category", "rule", "explanation"],
        "properties": {
          "original": { "type": "string" },
          "fixed":    { "type": "string" },
          "category": {
            "type": "string",
            "enum": [
              "article",
              "tense",
              "preposition",
              "agreement",
              "word_order",
              "vocab",
              "spelling",
              "punctuation",
              "l1_interference",
              "other"
            ]
          },
          "rule":        { "type": "string" },
          "explanation": { "type": "string" },
          "severity":    { "type": "string", "enum": ["minor", "moderate", "major"] }
        }
      }
    }
  }
}
```

## Enforcement modes

Through OpenRouter we have two enforcement options depending on the target
model:

**Strict JSON Schema** — for models that support it (OpenAI 4o+, Google
Gemini, and a few others):

```
response_format: {
  type: "json_schema",
  json_schema: { name: "correction", strict: true, schema: <above> }
}
```

Token-level constrained. Schema violations are impossible.

**Loose JSON mode** — for models that don't (Granite 4.1 8B falls here as
of 2026-05; verify per-model):

```
response_format: { type: "json_object" }
```

The model returns valid JSON but we have to validate against our schema
on the client side. A bounded retry on `DecodingError` re-prompts with the
validation error message before surfacing a clean failure. No silent
fallback.

`ProviderManager.modelCapabilities` is the table of which model gets which
treatment.

## Adding a provider

In v0.1 most "adding a provider" needs are satisfied by picking a different
OpenRouter model in Settings — no code change required.

When a true direct adapter is justified (cost, caching, compliance):

1. Create `Sources/Vireo/LLM/<Name>Adapter.swift`.
2. Conform to `ProviderAdapter`: `func correct(_ text: String) async throws -> CorrectionResult`.
3. Translate the schema above into the provider's structured-output format.
4. Register the adapter in `ProviderManager.allAdapters`.
5. Surface the provider in `SettingsView` with: API key field (Keychain),
   model picker, optional base URL override.
6. Add a fixture-based unit test in `Tests/VireoTests/`.
