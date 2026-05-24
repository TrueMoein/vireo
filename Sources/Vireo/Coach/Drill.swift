// Drill.swift — a fill-in-the-blank practice sentence generated for one
// weakness item.

import Foundation

struct Drill: Codable, Sendable, Hashable {
    /// The sentence with `___` (three underscores) marking the blank.
    /// e.g. "I need to update ___ server before deploy."
    let blank: String

    /// The exact text that fills the blank. e.g. "the".
    let answer: String

    /// One short explanation of why the answer is correct (≤15 words).
    let context: String
}
