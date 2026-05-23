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
        guard let raw = chat.choices.first?.message.content,
              let contentData = raw.data(using: .utf8)
        else { throw AdapterError.emptyResponse }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CorrectionResult.self, from: contentData)
        } catch {
            throw AdapterError.decodeFailure(error.localizedDescription, raw)
        }
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
    You are an English writing coach helping a non-native speaker improve through deliberate practice. Your goal is to teach the rule, not just fix the symptom.

    Given the user's text, return a JSON object with this exact shape and nothing else:
    {
      "corrected_text": "the full corrected version, preserving the user's voice and intent",
      "mistakes": [
        {
          "original": "the exact original phrase that was wrong (copy verbatim from input, including its surrounding context if needed)",
          "fixed": "the corrected phrase",
          "category": "article|tense|preposition|agreement|word_order|vocab|spelling|punctuation|l1_interference|other",
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
    - Category strings must be snake_case from the list above. Use "l1_interference" for mistakes that pattern-match a likely first-language influence (e.g., article omission for Persian/Russian L1, aspect confusion for Slavic L1).
    """
}
