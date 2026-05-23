// SelectedTextResolver.swift — get the currently-selected text from the
// focused app.
//
// Strategy:
//   1. AX fast-path: AXUIElementCopyAttributeValue on the system-wide
//      focused element with kAXSelectedTextAttribute. Silent and instant
//      in native text fields. Doesn't work reliably in Electron apps,
//      Chromium-based browsers, or apps that don't expose AX selection —
//      returns nil/empty in those cases.
//   2. Clipboard fallback: save pasteboard → simulate ⌘C via CGEvent →
//      poll NSPasteboard.changeCount until it ticks (≤200 ms) → read the
//      new content → restore the original pasteboard contents. Works
//      almost everywhere copy works.
//
// Reference: github.com/tisfeng/SelectedTextKit.

import AppKit
import ApplicationServices

struct SelectedTextResolver: Sendable {

    enum ResolveError: LocalizedError {
        case noSelection
        case accessibilityDenied
        case readFailed

        var errorDescription: String? {
            switch self {
            case .noSelection:
                return "No text selected."
            case .accessibilityDenied:
                return "Vireo needs Accessibility permission to read selected text."
            case .readFailed:
                return "Couldn't read the selection."
            }
        }
    }

    /// Try AX first; on empty/failure, fall back to the Cmd+C clipboard trick.
    @MainActor
    func resolve() async throws -> String {
        if AXIsProcessTrusted(), let viaAX = readViaAccessibility(), !viaAX.isEmpty {
            return viaAX.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let viaClipboard = try await readViaClipboardTrick()
        return viaClipboard.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AX path

    private func readViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focused: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard focusResult == .success, let focusedElement = focused else { return nil }

        // The CFTypeRef returned is an AXUIElement — bridge it via
        // unsafeDowncast (compiler's preferred form over unsafeBitCast).
        let element = unsafeDowncast(focusedElement, to: AXUIElement.self)

        var selected: AnyObject?
        let selectedResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selected
        )
        guard selectedResult == .success, let text = selected as? String else { return nil }
        return text
    }

    // MARK: - Clipboard fallback

    @MainActor
    private func readViaClipboardTrick() async throws -> String {
        let pb = NSPasteboard.general
        let originalChangeCount = pb.changeCount
        let originalString = pb.string(forType: .string)

        try simulateCommandC()

        // Poll for the pasteboard to change. Bounded by ~200 ms total.
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(200))
        var newContent: String?
        while ContinuousClock.now < deadline {
            if pb.changeCount != originalChangeCount {
                newContent = pb.string(forType: .string)
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        // Restore the original pasteboard regardless of outcome.
        defer {
            if let originalString {
                pb.clearContents()
                pb.setString(originalString, forType: .string)
            }
        }

        guard let text = newContent, !text.isEmpty else {
            throw ResolveError.noSelection
        }
        return text
    }

    private func simulateCommandC() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw ResolveError.readFailed
        }
        let cKey: CGKeyCode = 0x08 // ANSI C
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        else { throw ResolveError.readFailed }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
