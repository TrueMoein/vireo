// AppCoordinator.swift — single activation surface.
//
// Every capture surface (hotkey, double-shift, hover button, clipboard
// monitor) lands here. Owns the pipeline: resolve text → call provider →
// show in notch. Also owns the post-correction actions (Replace, Copy)
// since they need to paste back into the original source app.

import AppKit
import Foundation

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

    /// Paste `text` back into the original source app, replacing its current
    /// selection. Activates the app first, then simulates ⌘V after a short
    /// delay so focus has settled.
    func replaceCorrection(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        lastSourceApp?.activate()

        Task {
            try? await Task.sleep(for: .milliseconds(120))
            Self.simulateCommandV()
        }
    }

    /// Copy `text` to the clipboard without touching the source app.
    func copyCorrection(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private static func simulateCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKey: CGKeyCode = 0x09 // ANSI V
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
