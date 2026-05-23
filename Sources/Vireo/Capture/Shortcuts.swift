// Shortcuts.swift — KeyboardShortcuts.Name definitions for Vireo's hotkeys.

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Primary hotkey: with text selected anywhere on the Mac, this grabs the
    /// selection and asks the configured model to correct it.
    ///
    /// @MainActor because KeyboardShortcuts.Name is not Sendable and Swift 6
    /// strict concurrency flags static-let access otherwise. All hotkey
    /// registration happens on the main actor anyway.
    @MainActor
    static let correctSelection = Self(
        "vireo.correctSelection",
        default: .init(.space, modifiers: [.option, .shift])
    )
}
