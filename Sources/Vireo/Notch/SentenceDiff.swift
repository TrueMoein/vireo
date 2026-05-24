// SentenceDiff.swift — word-level diff for rendering a unified diff of the
// user's original sentence and the corrected sentence in the notch.
//
// Tokenization: split on whitespace, keep punctuation attached to its
// neighboring word ("hello," is one token). This produces the most
// natural-looking inline diff — punctuation changes show up as token
// edits rather than orphaned tokens.
//
// Algorithm: LCS via DP. O(n*m) memory + time, which is trivial at
// sentence length (n,m ≤ ~50 tokens). Backtrack to identify which
// indices in both sequences are in the LCS, then walk both lists to
// emit ordered (same | deleted | inserted) tokens.

import Foundation
import SwiftUI

enum SentenceDiff {
    enum Token: Hashable, Sendable {
        case same(String)
        case deleted(String)
        case inserted(String)
    }

    /// Compute a unified token stream from `original` to `corrected`.
    /// `same` tokens appear in both. `deleted` are present only in
    /// `original`. `inserted` are present only in `corrected`. The order
    /// preserves both sequences' positions where possible.
    static func compute(original: String, corrected: String) -> [Token] {
        let a = tokenize(original)
        let b = tokenize(corrected)
        guard !a.isEmpty || !b.isEmpty else { return [] }
        let pairs = lcsPairs(a, b)
        return interleave(a: a, b: b, lcs: pairs)
    }

    /// Build a single AttributedString rendering the diff. Deleted tokens
    /// get a strikethrough + warm-coral foreground; inserted tokens get
    /// bold + sage foreground. Whitespace separators are preserved between
    /// tokens.
    static func render(_ tokens: [Token]) -> AttributedString {
        var result = AttributedString("")
        var needsSpace = false
        for token in tokens {
            if needsSpace { result += AttributedString(" ") }
            switch token {
            case .same(let w):
                result += AttributedString(w)
            case .deleted(let w):
                var seg = AttributedString(w)
                seg.foregroundColor = Color.Vireo.mistake
                seg.strikethroughStyle = .single
                result += seg
            case .inserted(let w):
                var seg = AttributedString(w)
                seg.foregroundColor = Color.Vireo.correction
                seg.inlinePresentationIntent = .stronglyEmphasized
                result += seg
            }
            needsSpace = true
        }
        return result
    }

    // MARK: - Internals

    private static func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// Backtrack-based LCS: returns sorted pairs (i,j) where a[i] == b[j]
    /// is in the longest common subsequence.
    private static func lcsPairs(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        let n = a.count, m = b.count
        if n == 0 || m == 0 { return [] }
        // dp[i][j] = LCS length for a[..<i] and b[..<j]
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 1...n {
            for j in 1...m {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        var pairs: [(Int, Int)] = []
        var i = n, j = m
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                pairs.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return pairs.reversed()
    }

    /// Walk `a` and `b` together, emitting tokens in order using the
    /// LCS pairs to decide what's same and what's deleted/inserted.
    private static func interleave(
        a: [String],
        b: [String],
        lcs: [(Int, Int)]
    ) -> [Token] {
        var out: [Token] = []
        var ai = 0, bi = 0
        for (li, lj) in lcs {
            while ai < li { out.append(.deleted(a[ai])); ai += 1 }
            while bi < lj { out.append(.inserted(b[bi])); bi += 1 }
            out.append(.same(a[ai]))
            ai += 1
            bi += 1
        }
        while ai < a.count { out.append(.deleted(a[ai])); ai += 1 }
        while bi < b.count { out.append(.inserted(b[bi])); bi += 1 }
        return out
    }
}
