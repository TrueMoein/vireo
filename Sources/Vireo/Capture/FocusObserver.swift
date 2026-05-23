// FocusObserver.swift — tracks the system-wide frontmost application.
//
// Used by HoverButtonController to know which app's text the user might be
// selecting, and to suppress the hover button when Vireo itself (e.g. the
// Settings window) is frontmost.

import AppKit
import Combine
import SwiftUI

@MainActor
final class FocusObserver: ObservableObject {
    @Published private(set) var frontmostApp: NSRunningApplication?

    private var cancellable: AnyCancellable?

    init() {
        frontmostApp = NSWorkspace.shared.frontmostApplication
        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.frontmostApp = NSWorkspace.shared.frontmostApplication
                }
            }
    }
}
