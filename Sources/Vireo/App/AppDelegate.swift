// AppDelegate.swift — owns model lifetimes and starts the notch widget.
//
// We use NSApplicationDelegateAdaptor instead of @StateObject because the
// notch widget needs to be initialized after NSScreen is populated, which is
// only guaranteed in applicationDidFinishLaunching. It also lets us flip
// activation policy to .accessory (no Dock icon, no Cmd-Tab presence) without
// needing an Info.plist + LSUIElement at this stage.

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings: SettingsModel
    let notchPresenter: NotchPresenter

    override init() {
        let settings = SettingsModel()
        self.settings = settings
        self.notchPresenter = NotchPresenter(settings: settings)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        notchPresenter.start()
    }
}
