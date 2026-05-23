# LLM providers

Vireo speaks to LLMs through `ProviderAdapter`. Each adapter sends the user's
text + the standard correction prompt to its provider, requests a
schema-conformant structured response, and decodes into the same
`CorrectionResult` Codable.

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

**Anthropic** — define a single tool named `return_correction` with
`input_schema` set to the above. `tool_choice: { type: "tool", name:
"return_correction" }` forces the model to fill it. Schema is enforced
server-side.

**OpenAI** — set `response_format: { type: "json_schema", json_schema: {
name: "correction", strict: true, schema: <above> } }`. Token-level
constrained on `gpt-4o-2024-08-06` and later.

For both, a bounded retry on `DecodingError` re-prompts with the validation
error message before surfacing a clean failure. No silent fallback.

## Adding a provider

1. Create `Sources/Vireo/LLM/<Name>Adapter.swift`.
2. Conform to `ProviderAdapter`: `func correct(_ text: String) async throws -> CorrectionResult`.
3. Translate the schema above into the provider's structured-output format.
4. Register the adapter in `ProviderManager.allAdapters`.
5. Surface the provider in `SettingsView` with: API key field (Keychain),
   model picker, optional base URL override.
6. Add a fixture-based unit test in `Tests/VireoTests/`.
