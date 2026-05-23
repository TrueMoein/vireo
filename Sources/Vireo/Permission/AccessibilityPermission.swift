// AccessibilityPermission.swift — Accessibility-API trust status with live
// updates + dev-mode diagnostics.
//
// In production, AXIsProcessTrusted() is straightforward: the user grants
// once, the app sees it on next launch. In development with an SPM
// executable, macOS may track Accessibility grants per binary *path*, which
// can differ between Xcode and `swift run` and even between clean builds.
// We surface the running binary's path in Settings + log it at startup so
// the user can verify which Vireo they actually granted in System Settings.

import AppKit
import ApplicationServices
import Combine
import SwiftUI

@MainActor
final class AccessibilityPermission: ObservableObject {
    @Published private(set) var isGranted: Bool

    /// The path of the currently-running Vireo binary. Displayed in Settings
    /// so the user can confirm it matches the Vireo enabled in System
    /// Settings → Privacy & Security → Accessibility.
    let runningBinaryPath: String

    private var observer: AnyCancellable?

    init() {
        let granted = AXIsProcessTrusted()
        self.isGranted = granted
        self.runningBinaryPath = Bundle.main.executablePath ?? "<unknown>"

        observer = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }

        Self.logDiagnostics(granted: granted)
    }

    func refresh() {
        let now = AXIsProcessTrusted()
        if now != isGranted {
            isGranted = now
            print("[Vireo] AX trust changed → \(now)")
        }
    }

    /// Bring up macOS's "add app to Accessibility" prompt (which auto-adds
    /// the running binary to the list if it's not there yet) AND deep-link
    /// to the Accessibility pane. User must then toggle the entry on and
    /// quit + relaunch Vireo for the trust to take effect.
    func requestAndOpenSettings() {
        // Calling with prompt:true auto-adds the running binary to the
        // Accessibility list if it isn't there yet and shows the system
        // dialog. No-op if we're already trusted. Shown at most once per
        // app launch (macOS de-duplicates).
        //
        // Using the string literal directly because the imported
        // `kAXTrustedCheckOptionPrompt` C constant is a `var` to Swift,
        // which Swift 6 strict concurrency rejects as non-Sendable shared
        // mutable state. The literal value is what Apple's CFSTR macro
        // expands to anyway.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Quit Vireo. The user must relaunch from Xcode (or `swift run`) for
    /// the AX trust granted in System Settings to take effect.
    func quitForRelaunch() {
        NSApp.terminate(nil)
    }

    // MARK: - Diagnostics

    private static func logDiagnostics(granted: Bool) {
        print("──── Vireo accessibility diagnostics ────")
        print("Bundle ID:       \(Bundle.main.bundleIdentifier ?? "<nil — SPM executable, no Info.plist>")")
        print("Bundle path:     \(Bundle.main.bundlePath)")
        print("Executable path: \(Bundle.main.executablePath ?? "<unknown>")")
        print("AX trusted:      \(granted)")
        print("─────────────────────────────────────────")
    }
}
