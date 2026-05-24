// OpenRouterAdapter.swift — primary LLM adapter for v0.1, via OpenRouter.
//
// OpenAI-compatible chat completions with `response_format: json_object`.
// We rely on a strict system prompt + post-decode validation + lenient
// Category decoding (unknown → .other) rather than strict JSON schema mode,
// because OpenRouter's pass-through behaviour for json_schema varies across
// upstream providers. Trading some token waste for portability.
//
// Endpoint: POST https://openrouter.ai/api/v1/chat/completions
// Auth: Authorization: Bearer <OPENROUTER_API_KEY>

import Foundation

struct OpenRouterAdapter: ProviderAdapter {
    let apiKey: String
    let model: String

    private static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    func correct(_ text: String) async throws -> CorrectionResult {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("https://github.com/vireo-app/vireo", forHTTPHeaderField: "HTTP-Referer")
        req.setValue("Vireo", forHTTPHeaderField: "X-Title")
        req.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": text],
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.2,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw AdapterError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AdapterError.httpStatus(http.statusCode, bodyText)
        }

        let chat = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let raw = chat.choices.first?.message.content else {
            throw AdapterError.emptyResponse
        }

        // Defensive normalization: some models wrap JSON in Markdown fences
        // or add prose like "Here's the correction:" despite the system
        // prompt saying otherwise. Strip both before decoding.
        let normalized = Self.normalizeJSONContent(raw)
        guard let contentData = normalized.data(using: .utf8) else {
            throw AdapterError.decodeFailure("Empty content after normalization", raw)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CorrectionResult.self, from: contentData)
        } catch {
            throw AdapterError.decodeFailure(error.localizedDescription, raw)
        }
    }

    /// Generate a fresh fill-in-the-blank practice sentence for a given
    /// English rule. Used by the review session for active-recall drills.
    func generateDrill(rule: String, example: Mistake?) async throws -> Drill {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("https://github.com/vireo-app/vireo", forHTTPHeaderField: "HTTP-Referer")
        req.setValue("Vireo", forHTTPHeaderField: "X-Title")
        req.timeoutInterval = 60

        var userMessage = "Rule: \(rule)"
        if let example {
            userMessage += "\nRecent mistake illustrating it:\n  original: \"\(example.originalPhrase)\"\n  fixed: \"\(example.fixedPhrase)\""
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Self.drillSystemPrompt],
                ["role": "user", "content": userMessage],
            ],
            "response_format": ["type": "json_object"],
            // Slightly higher temperature than corrections so drills vary in
            // topic across reviews of the same rule.
            "temperature": 0.6,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AdapterError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AdapterError.httpStatus(http.statusCode, bodyText)
        }

        let chat = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let raw = chat.choices.first?.message.content else {
            throw AdapterError.emptyResponse
        }

        let normalized = Self.normalizeJSONContent(raw)
        guard let contentData = normalized.data(using: .utf8) else {
            throw AdapterError.decodeFailure("Empty content after normalization", raw)
        }

        do {
            return try JSONDecoder().decode(Drill.self, from: contentData)
        } catch {
            throw AdapterError.decodeFailure(error.localizedDescription, raw)
        }
    }

    private static let drillSystemPrompt = """
    You generate ONE fresh fill-in-the-blank English practice sentence for an English learner who works as a knowledge worker (developer, designer, marketer, etc.).

    You will receive an English rule (and possibly a recent mistake illustrating it). Output a single drill sentence that exercises the same rule on different vocabulary.

    Output ONLY this JSON (no other text, no Markdown fences, no commentary):
    {
      "blank": "<sentence containing three underscores ___ where the answer goes>",
      "answer": "<exact text that fills the blank — no quotes, no surrounding context>",
      "context": "<one short sentence (≤ 15 words) explaining why this answer is correct>"
    }

    Constraints:
    - 8 to 15 words in the sentence
    - Use a topic / vocabulary DIFFERENT from any example shown
    - Exactly one blank, marked with three underscores ___
    - Sentence should be natural English a working professional might write (work, code, meetings, deployments, docs, marketing)
    - The "answer" field is the EXACT minimal text that fills the blank — no quotes, no surrounding context, no punctuation that isn't part of the answer
    """

    /// Strip Markdown code fences and any prose around the outer JSON object.
    /// Handles ```json\n{…}\n```, ```\n{…}\n```, and "Here's the JSON: {…}".
    static func normalizeJSONContent(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip leading code-fence opener
        if s.hasPrefix("```") {
            s = String(s.dropFirst(3))
            // Skip the optional language tag up to the first newline
            if let nl = s.range(of: "\n") {
                s = String(s[nl.upperBound...])
            }
        }
        // Strip trailing code-fence closer
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Snip to the outermost JSON object if there's prose before/after.
        if let first = s.firstIndex(of: "{"),
           let last = s.lastIndex(of: "}"),
           first <= last
        {
            s = String(s[first...last])
        }

        return s
    }

    private struct ChatCompletionResponse: Codable {
        let choices: [Choice]
        struct Choice: Codable { let message: Message }
        struct Message: Codable { let content: String }
    }

    enum AdapterError: LocalizedError {
        case invalidResponse
        case httpStatus(Int, String)
        case emptyResponse
        case decodeFailure(String, String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from OpenRouter."
            case .httpStatus(let code, let body):
                let snippet = body.count > 600 ? String(body.prefix(600)) + "…" : body
                return "OpenRouter \(code): \(snippet)"
            case .emptyResponse:
                return "Empty response from OpenRouter."
            case .decodeFailure(let reason, let raw):
                let snippet = raw.count > 400 ? String(raw.prefix(400)) + "…" : raw
                return "Couldn't decode JSON (\(reason)). Raw content: \(snippet)"
            }
        }
    }

    private static let systemPrompt = """
    You are an English writing coach helping a learner improve through deliberate practice. Your goal is to teach the underlying rule, not just patch the symptom.

    Given the user's text, return a JSON object with this exact shape and nothing else:
    {
      "corrected_text": "the full corrected version, preserving the user's voice and intent",
      "mistakes": [
        {
          "original": "the exact original phrase that was wrong (copy verbatim from input, including surrounding context if needed)",
          "fixed": "the corrected phrase",
          "category": "article|tense|preposition|agreement|word_order|vocab|spelling|punctuation|other",
          "rule": "the underlying English rule in one short sentence",
          "explanation": "one or two sentences explaining the fix as if teaching a curious learner — no lecturing"
        }
      ]
    }

    Constraints:
    - If the text has no mistakes, return {"corrected_text": <input verbatim>, "mistakes": []}.
    - Output ONLY the JSON object. No prose before or after, no Markdown fences.
    - Preserve the user's voice. Do not rewrite for style if grammar is fine.
    - One distinct mistake per array entry; do not bundle multiple fixes into one.
    - Category strings must be snake_case from the list above.
    """
}
