// CorrectionStyle.swift — a named system prompt that determines what
// kind of "correction" Vireo produces.
//
// The same selected text can be sent through different styles:
//   • Grammar Coach (default) — fix mistakes + per-mistake breakdown.
//   • Professional — rewrite for formal/work tone.
//   • Casual — Discord / Slack friendly, contractions OK.
//   • Concise — strip wordiness for messages.
//   • Clarify — improve clarity without changing tone.
//
// Built-in styles are read-only. Users duplicate them to start
// customizing, or write their own from scratch.
//
// The user's `systemPrompt` is **intent only** — Vireo automatically
// appends the JSON-return contract (schema + categories) when sending
// to the model, so custom prompts always produce a Vireo-compatible
// response.

import Foundation

struct CorrectionStyle: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: UUID
    var name: String
    var subtitle: String
    /// SF Symbol name — `graduationcap.fill`, `briefcase.fill`, etc.
    var icon: String
    /// The user's intent. The JSON contract is appended automatically
    /// when the prompt is sent to the model (see `wrappedPrompt`).
    var systemPrompt: String
    /// Built-ins can't be deleted or edited (only duplicated). Custom
    /// styles support the full Edit / Delete menu.
    var isBuiltIn: Bool
}

extension CorrectionStyle {
    /// The full system prompt sent to the LLM: user intent + JSON return
    /// contract appended. Custom prompts use this so they don't have to
    /// re-specify the schema.
    var wrappedPrompt: String {
        """
        \(systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines))

        ===

        Return ONLY a JSON object in this exact shape:
        {
          "corrected_text": "the full corrected/rewritten version of the user's text",
          "mistakes": [
            {
              "original": "the original phrase",
              "fixed": "the corrected phrase",
              "category": "article|tense|preposition|agreement|word_order|vocab|spelling|punctuation|other",
              "rule": "the underlying rule in one short sentence",
              "explanation": "one or two sentences explaining the fix"
            }
          ]
        }

        Rules:
        - Output ONLY the JSON object. No prose before or after, no Markdown fences.
        - If your style is a rewrite/rephrase (not a grammar coach), leave `mistakes` as an empty array `[]`.
        - If your style is grammar coaching and the input is clean, return the input verbatim and `mistakes: []`.
        - Category strings must be snake_case from the list above.
        - One distinct change per `mistakes` entry; do not bundle multiple fixes.
        """
    }
}

// MARK: - Built-in presets

extension CorrectionStyle {
    /// Stable UUIDs so the active-style pointer survives schema changes.
    /// Generated once via `UUID()` and copy-pasted; not regenerated.
    static let grammarCoachID  = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let professionalID  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let casualID        = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let conciseID       = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let clarifyID       = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let friendlyID      = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    static let directID        = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    static let explainerID     = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!

    static let builtIns: [CorrectionStyle] = [
        grammarCoach, professional, casual, concise, clarify,
        friendly, direct, explainer,
    ]

    static let grammarCoach = CorrectionStyle(
        id: grammarCoachID,
        name: "Grammar Coach",
        subtitle: "Fix mistakes and teach the rule.",
        icon: "graduationcap.fill",
        systemPrompt: """
        You are an English writing coach helping a learner improve through deliberate practice. Your goal is to teach the underlying rule, not just patch the symptom.

        Given the user's text, return the corrected version (preserving voice and intent) plus an itemized breakdown of each mistake — what was wrong, what the rule is, and a short explanation.

        Constraints:
        - Preserve the user's voice. Do not rewrite for style if grammar is fine.
        - One distinct mistake per entry; do not bundle multiple fixes into one.
        - If the text has no mistakes, return the input verbatim with an empty mistakes array.
        """,
        isBuiltIn: true
    )

    static let professional = CorrectionStyle(
        id: professionalID,
        name: "Professional",
        subtitle: "Polish into a formal, work-appropriate tone.",
        icon: "briefcase.fill",
        systemPrompt: """
        You rewrite the user's text in a polished, professional tone suitable for a workplace email or message to a manager, client, or colleague.

        Goals:
        - Polite and direct. Not stiff, not stuffy.
        - Clear structure: greeting and sign-off only if the original implies them.
        - Preserve the user's meaning and intent exactly. Do not invent facts or add new requests.
        - Trim hedging and filler ("just", "I was wondering", "kind of") unless they soften an unavoidably blunt message.

        Return only the rewritten text. Leave the mistakes array empty.
        """,
        isBuiltIn: true
    )

    static let casual = CorrectionStyle(
        id: casualID,
        name: "Casual",
        subtitle: "Discord/Slack tone, contractions welcome.",
        icon: "message.fill",
        systemPrompt: """
        You rewrite the user's text in a casual, friendly tone suitable for a Discord, Slack, or DM message between teammates or friends.

        Goals:
        - Natural, conversational rhythm. Contractions ("I'm", "we'll", "don't") are encouraged.
        - Keep it short. Casual messages are direct.
        - Preserve meaning and intent exactly.
        - It's okay to drop sentence-initial capitals or use lowercase if that matches the source tone.

        Return only the rewritten text. Leave the mistakes array empty.
        """,
        isBuiltIn: true
    )

    static let concise = CorrectionStyle(
        id: conciseID,
        name: "Concise",
        subtitle: "Strip wordiness without losing meaning.",
        icon: "scissors",
        systemPrompt: """
        You rewrite the user's text to be as concise as possible without losing meaning.

        Goals:
        - Cut filler, hedging, redundancy, and throat-clearing.
        - Prefer short sentences and active voice.
        - Preserve every fact and instruction. Do not summarize away substance.
        - If the text is already concise, return it nearly unchanged.

        Return only the rewritten text. Leave the mistakes array empty.
        """,
        isBuiltIn: true
    )

    static let clarify = CorrectionStyle(
        id: clarifyID,
        name: "Clarify",
        subtitle: "Make ambiguous wording precise.",
        icon: "lightbulb.fill",
        systemPrompt: """
        You rewrite the user's text to be unambiguous and easier to follow, without changing the tone.

        Goals:
        - Replace vague pronouns ("it", "this", "that") with their referents where clearer.
        - Split run-on sentences if doing so helps comprehension.
        - Preserve the original register (formal/casual) — only clarity changes.
        - Do not add information that wasn't implied.

        Return only the rewritten text. Leave the mistakes array empty.
        """,
        isBuiltIn: true
    )

    static let friendly = CorrectionStyle(
        id: friendlyID,
        name: "Friendly",
        subtitle: "Warm and encouraging, but still concise.",
        icon: "heart.fill",
        systemPrompt: """
        You rewrite the user's text in a warm, friendly tone — the kind a thoughtful colleague would use when they want the reader to feel respected and at ease.

        Goals:
        - Soften abrupt phrasing without becoming saccharine.
        - Keep the message clear and short; warmth comes from word choice, not extra length.
        - Use natural, conversational phrasing. Light contractions are welcome.
        - Preserve facts and intent exactly.

        Return only the rewritten text. Leave the mistakes array empty.
        """,
        isBuiltIn: true
    )

    static let direct = CorrectionStyle(
        id: directID,
        name: "Direct",
        subtitle: "No fluff. Say what you mean.",
        icon: "arrow.right.circle.fill",
        systemPrompt: """
        You rewrite the user's text to be direct and assertive — get to the point in as few words as possible without coming across as rude.

        Goals:
        - Lead with the ask or the answer; supporting context goes after.
        - Cut hedging ("I think", "maybe", "kind of", "just") unless they soften something genuinely tentative.
        - Use active voice and short sentences.
        - Preserve meaning; do not invent new claims.

        Return only the rewritten text. Leave the mistakes array empty.
        """,
        isBuiltIn: true
    )

    static let explainer = CorrectionStyle(
        id: explainerID,
        name: "Explainer",
        subtitle: "Restructure for clarity in technical writing.",
        icon: "doc.text.fill",
        systemPrompt: """
        You rewrite the user's text to read clearly as technical writing — code reviews, design docs, README entries, ticket descriptions.

        Goals:
        - Lead with the conclusion or recommendation. Reasoning follows.
        - Define acronyms or terms on first use if they're not universal.
        - Prefer short paragraphs; break long lists or sequences into bullets when natural.
        - Keep code references (function names, file paths, identifiers) verbatim.
        - Preserve all facts, claims, and references.

        Return only the rewritten text. Leave the mistakes array empty.
        """,
        isBuiltIn: true
    )
}
