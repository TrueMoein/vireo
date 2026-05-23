// AccessibilityPermission.swift — Accessibility-API trust status with live
// updates.
//
// AXIsProcessTrusted() is the canonical check. We refresh:
//   - on app becomes-active (catches user toggling permission in System
//     Settings then switching back),
//   - on demand via refresh() (e.g., when Settings view appears).
// macOS still typically requires a relaunch after grant before AX
// observers actually receive events; the full custom onboarding (deep
// link + poll + auto-relaunch) lands in Phase 7.

import AppKit
import ApplicationServices
import Combine
import SwiftUI

@MainActor
final class AccessibilityPermission: ObservableObject {
    @Published private(set) var isGranted: Bool

    private var observer: AnyCancellable?

    init() {
        isGranted = AXIsProcessTrusted()
        observer = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
    }

    func refresh() {
        let now = AXIsProcessTrusted()
        if now != isGranted {
            isGranted = now
        }
    }

    /// Deep-link to System Settings → Privacy & Security → Accessibility.
    /// User must add and enable Vireo there; current macOS usually requires
    /// quitting and relaunching the app after grant before AX events flow.
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
