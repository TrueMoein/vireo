// AppCoordinator.swift — single activation surface.
//
// Every capture surface (hotkey, double-shift, hover button, clipboard
// monitor) lands here. Owns the pipeline: resolve text → call provider →
// show in notch.

import Foundation

@MainActor
final class AppCoordinator {
    let settings: SettingsModel
    let notch: NotchPresenter

    private let resolver = SelectedTextResolver()

    init(settings: SettingsModel, notch: NotchPresenter) {
        self.settings = settings
        self.notch = notch
    }

    /// Invoked by the global hotkey. Resolves selected text and routes it
    /// through the configured OpenRouter model. Surfaces busy/error/success
    /// states in the notch.
    func correctSelection() async {
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

        // Resolve selected text.
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

        // Show busy while the call is in flight.
        await notch.showBusy("Asking \(trimmedModel)")

        // Call the model.
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
}
