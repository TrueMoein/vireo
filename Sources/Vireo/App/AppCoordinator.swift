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
    let sessionRepository: SessionRepository?
    let weaknessTracker: WeaknessTracker?
    /// Weak so we can call reload() after each save without a retain cycle.
    weak var sessionStore: SessionStore?
    /// Set by AppDelegate so ExpandedRouter can reach the drill generator
    /// when showing notch-resident review cards.
    weak var drillGenerator: DrillGenerator?
    /// Style store — used to resolve the active style's system prompt.
    /// Set by AppDelegate after construction.
    weak var styleStore: CorrectionStyleStore?

    private let resolver = SelectedTextResolver()
    private var lastSourceApp: NSRunningApplication?
    /// Handle to the in-flight correction task so the streaming card's
    /// Cancel button (and notch dismissal) can abort the network read.
    private var currentCorrectionTask: Task<Void, Never>?
    /// Where the current correction came from. Used by `replaceCorrection`
    /// to pick AX-writeback (selection-based flows) vs pure clipboard
    /// semantics (clipboard monitor flow).
    private var lastTriggerSource: TriggerSource = .selection

    enum TriggerSource {
        /// Hotkey, hover button, double-shift — we have a source app
        /// with focused text we should replace.
        case selection
        /// Clipboard monitor — no source app context; Replace just puts
        /// the corrected text on the clipboard.
        case clipboard
    }

    init(
        settings: SettingsModel,
        notch: NotchPresenter,
        sessionRepository: SessionRepository? = nil,
        weaknessTracker: WeaknessTracker? = nil
    ) {
        self.settings = settings
        self.notch = notch
        self.sessionRepository = sessionRepository
        self.weaknessTracker = weaknessTracker
    }

    // MARK: - Correct selection

    func correctSelection() async {
        // Capture the source app *before* we present our own UI so Replace
        // can route the paste back to it later.
        lastSourceApp = NSWorkspace.shared.frontmostApplication
        lastTriggerSource = .selection

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

        await correct(text: text, styleID: nil)
    }

    /// Entrypoint from `ClipboardMonitor`. Text is already on the
    /// clipboard, so `lastSourceApp` is irrelevant for replace; we just
    /// remember it was clipboard-triggered and run the same pipeline.
    func correctFromClipboard(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastSourceApp = nil
        lastTriggerSource = .clipboard
        await correct(text: trimmed, styleID: nil)
    }

    /// Pipeline entrypoint used by both the hotkey/hover-button flow
    /// (after text resolution) and the notch chip's "re-run with another
    /// style" path. `styleID == nil` means use the currently active
    /// style from the store.
    func correct(text: String, styleID: UUID?) async {
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

        // Resolve the style to use: explicit param wins, else the
        // store's active style, else Grammar Coach.
        let resolvedStyle: CorrectionStyle
        if let store = styleStore {
            resolvedStyle = store.resolve(id: styleID ?? store.activeStyleID)
        } else {
            resolvedStyle = CorrectionStyle.grammarCoach
        }

        let adapter = OpenRouterAdapter(
            apiKey: trimmedKey,
            model: trimmedModel,
            systemPrompt: resolvedStyle.wrappedPrompt
        )

        let useStreaming = settings.streamingEnabled
        if useStreaming {
            await notch.showStreaming()
        } else {
            await notch.showBusy("Asking \(trimmedModel)")
        }

        // Cancel any prior in-flight task before kicking off this one.
        currentCorrectionTask?.cancel()
        let task = Task { [weak self, notch] in
            guard let self else { return }
            let started = ContinuousClock.now
            do {
                var result: CorrectionResult
                if useStreaming {
                    result = try await adapter.correctStreaming(text) { @MainActor partial in
                        // Updates the notch model in-place; no panel re-init.
                        notch.updateStreaming(partial: partial)
                    }
                } else {
                    result = try await adapter.correct(text)
                }
                try Task.checkCancellation()
                result.styleID = resolvedStyle.id
                let elapsed = started.duration(to: .now)
                let elapsedMs = Int(elapsed.components.seconds) * 1000
                    + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
                await notch.showCorrection(result)

                // Best-effort persistence + weakness tracking — never block the
                // user-facing flow on it.
                if let repo = self.sessionRepository {
                    let appName = self.lastSourceApp?.localizedName
                    let modelName = trimmedModel
                    let store = self.sessionStore
                    let tracker = self.weaknessTracker
                    Task.detached {
                        do {
                            try await repo.save(
                                rawText: text,
                                result: result,
                                sourceApp: appName,
                                model: modelName,
                                latencyMs: elapsedMs
                            )
                            try await tracker?.ingest(result: result)
                            await store?.reload()
                            log.info("Persisted session + ingested \(result.mistakes.count, privacy: .public) mistakes")
                        } catch {
                            log.error("Persist session failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            } catch is CancellationError {
                // User dismissed the streaming card; nothing to surface.
                log.info("Correction cancelled mid-flight")
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
        currentCorrectionTask = task
        await task.value
    }

    /// Abort the in-flight correction (if any). Called by the streaming
    /// card's Cancel button and on notch dismissal during streaming.
    func cancelInflightCorrection() {
        currentCorrectionTask?.cancel()
        currentCorrectionTask = nil
    }

    // MARK: - Post-correction actions

    /// Replace the current selection in the source app with `text`.
    ///
    /// Two paths depending on trigger source:
    ///   • `.selection` — AX write-back into the focused element, with
    ///     pasteboard + ⌘V fallback for Electron / Chromium apps. The
    ///     source app is activated first if it isn't frontmost.
    ///   • `.clipboard` — the user copied text; the corrected text just
    ///     goes back onto the clipboard so their next paste uses it.
    ///     No AX writeback, no ⌘V synthesis — too easy to paste into
    ///     the wrong window.
    func replaceCorrection(_ text: String) async {
        if lastTriggerSource == .clipboard {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
            log.info("Replace (clipboard trigger): wrote \(text.count, privacy: .public) chars back to pasteboard")
            await showReplaceToast(detail: "Corrected text is on your clipboard.")
            return
        }

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

        let appName = lastSourceApp?.localizedName ?? "the source app"

        if replaceViaAX(text: text) {
            log.info("Replace via AX write-back: \(text.count, privacy: .public) chars")
            await showReplaceToast(detail: "Replaced text in \(appName).")
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
        await showReplaceToast(detail: "Pasted into \(appName).")
    }

    /// Brief 2s success toast shown after Replace fires. Triggers an
    /// auto-hide back to compact rather than slamming the notch shut —
    /// gives the user a frame of confirmation that the action worked.
    private func showReplaceToast(detail: String) async {
        await notch.showMessage(
            NotchMessage(
                icon: "checkmark.seal.fill",
                title: "Replaced",
                detail: detail,
                tone: .info
            ),
            autoHideAfter: .seconds(2)
        )
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
