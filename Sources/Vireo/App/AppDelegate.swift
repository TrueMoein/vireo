// AppDelegate.swift — owns model lifetimes, starts the notch widget, and
// registers the global hotkey + the PopClip-style hover button controller.

import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings: SettingsModel
    let notchPresenter: NotchPresenter
    let coordinator: AppCoordinator
    let permission: AccessibilityPermission
    let focusObserver: FocusObserver
    let hoverButton: HoverButtonController
    let database: Database?
    let sessionRepository: SessionRepository?
    let weaknessTracker: WeaknessTracker?
    let sessionStore: SessionStore
    let drillGenerator: DrillGenerator
    let onboardingController: OnboardingWindowController
    let idleCoach: IdleCoach
    let styleStore: CorrectionStyleStore
    let doubleShift: ShiftDoubleTapMonitor
    let clipboardMonitor: ClipboardMonitor

    override init() {
        let settings = SettingsModel()

        // Database is best-effort: a failure here shouldn't break the app,
        // just means history isn't recorded for this run.
        let database: Database?
        do {
            database = try Database()
        } catch {
            print("[Vireo] Database init failed: \(error)")
            database = nil
        }
        self.database = database
        let repo = database.map(SessionRepository.init)
        let tracker = database.map(WeaknessTracker.init)
        self.sessionRepository = repo
        self.weaknessTracker = tracker
        // SessionStore is always non-nil; it carries an `unavailable` flag
        // for the History tab to render a clean error state if the DB
        // failed to open.
        self.sessionStore = SessionStore(repository: repo, weaknessTracker: tracker)
        self.drillGenerator = DrillGenerator(settings: settings)
        let styleStore = CorrectionStyleStore()
        self.onboardingController = OnboardingWindowController(
            settings: settings,
            permission: AccessibilityPermission(),
            styleStore: styleStore
        )

        let presenter = NotchPresenter(settings: settings)
        let coordinator = AppCoordinator(
            settings: settings,
            notch: presenter,
            sessionRepository: repo,
            weaknessTracker: tracker
        )
        let focusObserver = FocusObserver()
        let hoverButton = HoverButtonController(coordinator: coordinator, focus: focusObserver)

        self.settings = settings
        self.notchPresenter = presenter
        self.coordinator = coordinator
        self.permission = AccessibilityPermission()
        self.focusObserver = focusObserver
        self.hoverButton = hoverButton
        // IdleCoach surfaces a single drill into the notch when the user
        // is idle. Started in applicationDidFinishLaunching.
        self.idleCoach = IdleCoach(
            settings: settings,
            repository: repo,
            presenter: presenter
        )
        self.styleStore = styleStore
        // Closures referencing `coordinator` need to be wired after
        // super.init. We seed the monitor with a placeholder that flips
        // on the wired coordinator below.
        self.doubleShift = ShiftDoubleTapMonitor(onDoubleTap: { [weak coordinator] in
            Task { @MainActor in
                await coordinator?.correctSelection()
            }
        })
        self.clipboardMonitor = ClipboardMonitor(coordinator: coordinator)
        super.init()
        // Break the retain cycle: coordinator strongly holds presenter via
        // its notch field; presenter holds coordinator weakly for action
        // dispatch from CorrectionCard buttons.
        presenter.coordinator = coordinator
        // Wire SessionStore into the coordinator so History refreshes
        // automatically after each save.
        coordinator.sessionStore = self.sessionStore
        // Wire stores into the presenter so the rich popover can read them.
        presenter.sessionStore = self.sessionStore
        presenter.permission = self.permission
        presenter.styleStore = self.styleStore
        // Onboarding needs to re-assert the notch panel after it activates
        // (same reason as NotchPopover.bringWindowForward — accessory apps
        // can have their screensaver-level panels displaced on activation).
        self.onboardingController.notchPresenter = presenter
        // Expose the drill generator on the coordinator so the notch
        // expanded router can build NotchReviewCard for ambient drills.
        coordinator.drillGenerator = self.drillGenerator
        // Style store enables active-style resolution + the "switch
        // style on the notch correction card" re-run flow.
        coordinator.styleStore = self.styleStore
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        notchPresenter.start()
        registerHotkeys()
        idleCoach.start()
        doubleShift.start()
        clipboardMonitor.start()
        // Expose the coordinator to in-process intent invocations so the
        // Shortcuts.app intent can surface its correction in the notch.
        VireoIntentBridge.coordinator = coordinator

        // First launch: show the proper onboarding wizard. Subsequent
        // launches show nothing (the wizard's hasOnboarded flag gates
        // future presentations). The MeshGradient welcome moment now
        // lives inside the wizard's first step rather than as a
        // standalone notch card.
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            self.onboardingController.showIfNeeded()
        }
    }

    private func registerHotkeys() {
        let coordinator = self.coordinator
        KeyboardShortcuts.onKeyDown(for: .correctSelection) {
            Task { @MainActor in
                await coordinator.correctSelection()
            }
        }
    }

    /// Vireo's primary surface is the notch panel, which AppKit doesn't
    /// count as a "window" for the auto-terminate check. Without this
    /// override, closing Settings (or the main window) leaves AppKit
    /// thinking there are no windows left and quits the whole app —
    /// killing the notch with it. Returning false keeps Vireo alive
    /// as long as the user hasn't explicitly chosen Quit.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
