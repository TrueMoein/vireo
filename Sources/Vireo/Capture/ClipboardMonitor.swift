// ClipboardMonitor.swift — third capture surface.
//
// When enabled, polls NSPasteboard.changeCount and, on each new copy
// that passes the English-sentence heuristic, fires the same flow as
// the hotkey: kick off a correction with the active style and show it
// in the notch. The Replace button writes the corrected text back to
// the clipboard so the user's next paste uses the corrected version.
//
// Strict filter so we don't burn API calls on URLs, code, log lines,
// CJK / RTL text, or short non-sentence copies:
//   • 12 – 2000 chars
//   • has lowercase + at least one space
//   • doesn't look like a URL or code
//   • punctuation density < 0.25
//   • NLLanguageRecognizer detects English with confidence > 0.85
//   • not in the last `recentMemory` items (avoids re-running on
//     paste-bouncing or clipboard manager re-copies)
//   • cooldown: minimum `minInterval` since the previous trigger
//
// Off by default — the user opts in via Settings → Shortcuts. We never
// auto-enable.

import AppKit
import Foundation
import NaturalLanguage
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "Clipboard")

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let coordinator: AppCoordinator
    private static let pollInterval: Duration = .milliseconds(500)
    private static let minInterval: TimeInterval = 10  // cooldown between fires
    private static let recentMemory: Int = 5
    private static let enabledDefaultsKey = "co.vireo.clipboardMonitorEnabled"

    private var pollingTask: Task<Void, Never>?
    private var lastChangeCount: Int
    private var lastFiredAt: Date = .distantPast
    /// Hash digests (FNV-1a 64-bit) of the most recent clipboard payloads
    /// we've already considered. Using hashes keeps memory bounded and
    /// avoids holding user text in memory longer than necessary.
    private var recentHashes: [UInt64] = []

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.isEnabled = UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool ?? false
    }

    func start() {
        guard isEnabled, pollingTask == nil else { return }
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled, let self else { return }
                self.tick()
            }
        }
        log.info("Clipboard monitor started")
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if enabled {
            // Reset baseline so we don't fire on whatever's currently in
            // the pasteboard the moment the user flips the toggle.
            lastChangeCount = NSPasteboard.general.changeCount
            start()
        } else {
            stop()
        }
    }

    // MARK: - Internals

    private func tick() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.passesFilter(trimmed) else { return }

        let hash = Self.fnv1a64(trimmed)
        if recentHashes.contains(hash) { return }
        rememberHash(hash)

        guard Date().timeIntervalSince(lastFiredAt) >= Self.minInterval else { return }
        lastFiredAt = Date()

        log.info("Clipboard auto-correct: \(trimmed.count, privacy: .public) chars")
        Task { @MainActor [weak coordinator] in
            await coordinator?.correctFromClipboard(text: trimmed)
        }
    }

    private func rememberHash(_ hash: UInt64) {
        recentHashes.append(hash)
        if recentHashes.count > Self.recentMemory {
            recentHashes.removeFirst(recentHashes.count - Self.recentMemory)
        }
    }

    // MARK: - Filter

    /// Pure-logic filter — no instance state touched, safe to call
    /// from any context (the test target wants nonisolated access).
    nonisolated static func passesFilter(_ text: String) -> Bool {
        let count = text.count
        guard count >= 12, count <= 2000 else { return false }

        // Must have a space (multi-word) and at least one lowercase letter
        // (rules out shouty headers, code identifiers).
        guard text.contains(" ") else { return false }
        guard text.contains(where: { $0.isLowercase }) else { return false }

        // Heuristic URL / code rejection — common starts of non-sentence text.
        let lower = text.lowercased()
        let skipPrefixes = [
            "http://", "https://", "ftp://", "file:///",
            "function ", "class ", "import ", "package ",
            "{", "[", "<", "//", "/*", "#!",
        ]
        for prefix in skipPrefixes where lower.hasPrefix(prefix) { return false }

        // Punctuation density check: too many braces/brackets/semicolons
        // relative to length suggests code.
        let codeSet: Set<Character> = ["{", "}", "[", "]", "(", ")", ";", "<", ">", "/", "\\", "|", "=", "*", "&", "^", "@"]
        let codeCount = text.filter { codeSet.contains($0) }.count
        let density = Double(codeCount) / Double(count)
        guard density < 0.25 else { return false }

        // English detection — strict confidence floor to avoid false positives
        // on Romance-language text or mixed-language snippets.
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let englishConfidence = hypotheses[.english], englishConfidence >= 0.85 else {
            return false
        }

        return true
    }

    /// FNV-1a 64-bit. Pure-Swift, no Foundation dependency on Data
    /// hashing helpers. We just need a stable, bounded-size digest so
    /// `recentHashes` doesn't hold full text strings.
    private static func fnv1a64(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01B3
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }
}
