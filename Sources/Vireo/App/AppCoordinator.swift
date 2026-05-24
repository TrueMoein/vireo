// AppCoordinator.swift — single activation surface.
//
// Every capture surface (hotkey, double-shift, hover button, clipboard
// monitor) lands here. Owns the pipeline: resolve text → call provider →
// show in notch. Also owns the post-correction actions (Replace, Copy)
// since they need to paste back into the original source app.

import AppKit
import ApplicationServices
import Foundation
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "Coordinator")

@MainActor
final class AppCoordinator {
    let settings: SettingsModel
    let notch: NotchPresenter

    private let resolver = SelectedTextResolver()
    private var lastSourceApp: NSRunningApplication?

    init(settings: SettingsModel, notch: NotchPresenter) {
        self.settings = settings
        self.notch = notch
    }

    // MARK: - Correct selection

    func correctSelection() async {
        // Capture the source app *before* we present our own UI so Replace
        // can route the paste back to it later.
        lastSourceApp = NSWorkspace.shared.frontmostApplication

        let trimmedKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            await notch.showMessage(
                NotchMessage(
                    icon: "key.fill",
                    title: "No API key set",
                    detail: "Open Settings and paste your OpenRouter key.",
                    tone: .warning
                )
            )
            return
        }

        let trimmedModel = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            await notch.showMessage(.warning("No model selected"))
            return
        }

        let text: String
        do {
            text = try await resolver.resolve()
        } catch let error as SelectedTextResolver.ResolveError {
            let icon: String
            switch error {
            case .noSelection: icon = "text.cursor"
            case .accessibilityDenied: icon = "lock.shield.fill"
            case .readFailed: icon = "exclamationmark.triangle.fill"
            }
            await notch.showMessage(
                NotchMessage(
                    icon: icon,
                    title: error.errorDescription ?? "Couldn't read selection",
                    detail: nil,
                    tone: error == .accessibilityDenied ? .warning : .info
                )
            )
            return
        } catch {
            await notch.showMessage(.error(error.localizedDescription))
            return
        }

        guard !text.isEmpty else {
            await notch.showMessage(.info("No text selected", detail: "Select some text and press the hotkey again."))
            return
        }

        await notch.showBusy("Asking \(trimmedModel)")

        let adapter = OpenRouterAdapter(apiKey: trimmedKey, model: trimmedModel)
        do {
            let result = try await adapter.correct(text)
            await notch.showCorrection(result)
        } catch {
            await notch.showMessage(
                NotchMessage(
                    icon: "exclamationmark.octagon.fill",
                    title: "Couldn't get correction",
                    detail: error.localizedDescription,
                    tone: .error
                )
            )
        }
    }

    // MARK: - Post-correction actions

    /// Replace the current selection in the source app with `text`.
    ///
    /// Strategy (in order):
    /// 1. If the source app isn't currently frontmost (e.g., user opened
    ///    Settings between hotkey and Replace), activate it and *await*
    ///    enough time for focus to settle. Doing the rest synchronously
    ///    on the wrong app is the most common Replace failure.
    /// 2. AX write-back via AXUIElementSetAttributeValue on the focused
    ///    element. Direct, instant, no pasteboard hijack. Works in native
    ///    AX-cooperative text fields (Notes, Mail, TextEdit, Pages, Xcode).
    /// 3. Pasteboard + ⌘V fallback for apps where AX selectedText is
    ///    read-only (most Electron / Chromium apps).
    func replaceCorrection(_ text: String) async {
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        let needsActivation = lastSourceApp != nil
            && lastSourceApp?.processIdentifier != currentFrontmost?.processIdentifier

        if needsActivation, let app = lastSourceApp {
            let activated = app.activate()
            log.info("""
                Replace: activating \(app.localizedName ?? "?", privacy: .public) \
                (was \(currentFrontmost?.localizedName ?? "?", privacy: .public)) \
                returned=\(activated, privacy: .public)
                """)
            // Wait for focus to actually shift. AX writes done before this
            // settles would target the wrong element.
            try? await Task.sleep(for: .milliseconds(220))
        }

        if replaceViaAX(text: text) {
            log.info("Replace via AX write-back: \(text.count, privacy: .public) chars")
            return
        }
        log.info("Replace: AX write-back unavailable, using pasteboard + ⌘V")

        let pb = NSPasteboard.general
        pb.clearContents()
        let pbOK = pb.setString(text, forType: .string)
        log.info("Replace pasteboard write: \(pbOK, privacy: .public)")

        try? await Task.sleep(for: .milliseconds(80))
        Self.simulateCommandV()
        log.info("Replace ⌘V posted")
    }

    /// Try the AX-direct path. Returns true on success.
    private func replaceViaAX(text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let getStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard getStatus == .success, let focusedRef = focused else {
            log.info("AX write-back: no focused element (status=\(getStatus.rawValue, privacy: .public))")
            return false
        }
        let element = unsafeDowncast(focusedRef, to: AXUIElement.self)
        let setStatus = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        if setStatus != .success {
            log.info("AX write-back: set failed (status=\(setStatus.rawValue, privacy: .public))")
        }
        return setStatus == .success
    }

    /// Copy `text` to the clipboard without touching the source app.
    func copyCorrection(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private static func simulateCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            log.error("simulateCommandV: CGEventSource creation failed")
            return
        }
        let vKey: CGKeyCode = 0x09 // ANSI V
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else {
            log.error("simulateCommandV: CGEvent creation failed")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
