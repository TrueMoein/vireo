# LLM providers

Vireo speaks to LLMs through one adapter today: **`OpenRouterAdapter`**.
[OpenRouter](https://openrouter.ai) is an OpenAI-compatible aggregator —
one API key, one HTTP client, and the user picks any model at runtime
from Settings. Direct per-provider adapters are out of v1 scope (the
files `AnthropicAdapter.swift` and `OpenAIAdapter.swift` exist as
stubs only).

This doc covers the wire format, how the active **Correction Style**
plugs into the prompt, the streaming pipeline, and the shape of any
future adapter.

## The contract

Every adapter returns the same Codable: `LLM/CorrectionResult.swift`.

```jsonc
{
  "corrected_text": "the full corrected/rewritten version of the input",
  "mistakes": [
    {
      "original":    "the original phrase",
      "fixed":       "the corrected phrase",
      "category":    "article|tense|preposition|agreement|word_order|vocab|spelling|punctuation|other",
      "rule":        "the underlying rule in one short sentence",
      "explanation": "one or two sentences explaining the fix"
    }
  ]
}
```

Constraints:

- Output **only** the JSON object — no Markdown fences, no prose.
- If the input has no mistakes (grammar styles) or the style is a rewrite,
  `mistakes` should be `[]`.
- Category strings are snake_case from the list above. **Lenient decode**:
  the `Category` enum's `init(from:)` maps unknown values to `.other`, so
  a hallucinated category doesn't tank the whole correction.

`CorrectionResult` carries two extra fields populated *after* JSON
decode, not from the LLM:

- `originalText: String` — set by the adapter from the user's input so the
  notch can render a word-diff.
- `styleID: UUID?` — set by `AppCoordinator` to record which style
  produced the row. Persisted alongside the session.

## The system prompt comes from the active style

The user's active `CorrectionStyle` is the source of truth for "what
should the model do." The adapter's old hard-coded prompt is gone —
`OpenRouterAdapter` now accepts `systemPrompt` at init time.

The pipeline:

1. `AppCoordinator.correct(text:styleID:)` calls
   `styleStore.resolve(id:)` to pick the active or explicitly-requested
   style.
2. It reads `style.wrappedPrompt` — which is `style.systemPrompt`
   (the user's *intent*) plus an appended **JSON return contract**
   (the schema above + the constraint rules).
3. It constructs `OpenRouterAdapter(apiKey:, model:, systemPrompt:)`.

This means **custom prompts work without users having to specify the
JSON shape themselves.** They write "rewrite as a polite reminder" and
Vireo handles the rest. See `LLM/CorrectionStyle.swift` for the wrapper.

## Two adapter methods

```swift
struct OpenRouterAdapter: ProviderAdapter {
    let apiKey: String
    let model: String
    let systemPrompt: String

    /// Non-streaming. Used by the Shortcuts intent path and as the
    /// streaming-toggle-off fallback. Single POST, full result back.
    func correct(_ text: String) async throws -> CorrectionResult

    /// Streaming. Used by the hotkey / hover / double-shift / clipboard /
    /// re-correct flows when `settings.streamingEnabled` is true.
    /// Invokes the partial-text callback on the MainActor as the
    /// model emits each chunk.
    func correctStreaming(
        _ text: String,
        onPartialCorrection: @Sendable @MainActor (String) -> Void
    ) async throws -> CorrectionResult
}
```

## Endpoint + auth

```
POST https://openrouter.ai/api/v1/chat/completions
Authorization: Bearer <OPENROUTER_API_KEY>
Content-Type: application/json
HTTP-Referer: https://github.com/TrueMoein/vireo
X-Title: Vireo
```

Body for both methods is the same shape; `correctStreaming` adds
`"stream": true`:

```jsonc
{
  "model":            "<vendor/model>",
  "messages": [
    { "role": "system",  "content": "<wrappedPrompt from active style>" },
    { "role": "user",    "content": "<selected text>" }
  ],
  "response_format":  { "type": "json_object" },
  "temperature":      0.2,
  "stream":           true   // only in correctStreaming
}
```

We use `response_format: json_object` rather than strict `json_schema`
because OpenRouter's pass-through of strict schemas varies wildly by
upstream provider. Trade some token cost for portability; client-side
parsing handles violations.

## The streaming pipeline

Server-Sent Events arrive as `data: <json>` lines, terminated by
`data: [DONE]`. Each JSON envelope contains a `delta.content` fragment.

```
URLSession.bytes(for:)
        │
        ▼ async lines
[ data: {"choices":[{"delta":{"content":"…"}}]} ]
        │
        ▼ decode StreamChunk, append delta.content to buffer
String buffer
        │
        ▼ StreamingJSONFieldExtractor.feed(_:)
"corrected_text" value, partial-by-partial
        │
        ▼ MainActor callback
NotchPresenter.updateStreaming(partial:)
        │
        ▼ data: [DONE]
JSONDecoder over the full buffer
        │
        ▼
CorrectionResult { correctedText, mistakes[], originalText, styleID }
```

`StreamingJSONFieldExtractor` is a single-field state machine. It scans
for `"corrected_text"\s*:\s*"` and then captures bytes (with full JSON
escape handling, including `\uXXXX`) until the unescaped closing `"`.
Only that one field streams; `mistakes` is parsed in one shot at the
end. Source: `Sources/Vireo/LLM/StreamingJSONFieldExtractor.swift`.

## The ≥30B recommendation

The Settings model picker accepts any OpenRouter model name, but warns
when the user enters something below ~30B parameters:

- Grammar coaching wants nuance smaller models fake unconvincingly.
- Structured-output adherence drops noticeably below 30B (silent enum
  violations, dropped required fields).
- Cost difference is small at typical usage (Claude Haiku 4.5 is
  roughly $0.001 per correction).

Quick-picks shown in Settings → Provider:
- `anthropic/claude-haiku-4.5` (default)
- `google/gemini-3.1-flash`
- `openai/gpt-4o-mini`
- `mistralai/mistral-large`

The warning is dismissible — users can pick anything they want.

## Defensive JSON normalization

Models occasionally wrap their output in Markdown fences or stick a
sentence of prose before the JSON, even with `response_format` set.
`OpenRouterAdapter.normalizeJSONContent` strips:

- Leading ```` ```json ```` or ```` ``` ```` fences with optional language tag
- Trailing ```` ``` ```` fences
- Any prose before the first `{` or after the last `}`

After normalization, decoding goes through a `JSONDecoder` with
`.keyDecodingStrategy = .convertFromSnakeCase`, so the JSON's
`corrected_text` maps to `CorrectionResult.correctedText` cleanly.

## Adding a new provider

The OpenRouter aggregator covers almost every model worth using. Direct
adapters are only worth building for: per-provider prompt-caching (e.g.,
Anthropic), org-compliance reasons, or a self-hosted model.

When justified:

1. Create `Sources/Vireo/LLM/<Name>Adapter.swift`.
2. Conform to `ProviderAdapter` (`func correct(_ text: String) async throws -> CorrectionResult`).
   Mirror `OpenRouterAdapter` for the streaming method if your provider
   supports SSE.
3. Carry `systemPrompt: String` at init — Vireo's active-style flow
   needs it. **Do not hard-code a system prompt.**
4. Decode into `CorrectionResult` (snake_case → camelCase via the
   decoder's strategy). Populate `originalText` post-decode.
5. Register the adapter in whichever construction site the user picks
   (today: `AppCoordinator.correct(text:styleID:)` constructs
   `OpenRouterAdapter` directly; if a `ProviderManager` returns; future
   work).
6. Surface the provider in `SettingsView` → `ProviderTab`: API key
   field (Keychain via `KeychainStore`), model picker, optional base
   URL override.
7. Add a fixture-based unit test in `Tests/VireoTests/`.

The intent path (`Sources/Vireo/Intents/CoachEnglishIntent.swift`) runs
in a nonisolated context and reads its own UserDefaults / Keychain keys
directly, so a new adapter has to be wired there too — duplicate the
key constants for now (see how the active-style resolver does it).
