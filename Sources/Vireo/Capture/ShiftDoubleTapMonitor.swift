// ShiftDoubleTapMonitor.swift — global CGEvent tap for Right-Shift
// double-tap as a secondary capture trigger.
//
// Why: ⌥⇧Space is the primary hotkey, but it requires three fingers.
// Right-Shift double-tap is the "Codex Cmd-Cmd" ergonomic, shifted off
// Cmd to avoid the macOS screenshot collision. Two presses of Right-
// Shift within `doubleTapWindow` fires the same flow as the hotkey:
// capture selection → correct → notch.
//
// Strategy:
//   • One CGEvent tap listening for .flagsChanged.
//   • Filter to keycode 60 (kVK_RightShift) only.
//   • Track press transitions (Shift just-added flag).
//   • Two presses within 300 ms → fire.
//
// Accessibility is required (same as hover button / hotkey via AX).
// Without it, start() is a no-op and the user sees the existing AX-
// permission nudges in Settings.

import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import OSLog

private let log = Logger(subsystem: "co.vireo", category: "DoubleShift")

@MainActor
final class ShiftDoubleTapMonitor: ObservableObject {
    @Published private(set) var isEnabled: Bool

    /// Maximum time between the two presses to count as a double-tap.
    static let doubleTapWindow: TimeInterval = 0.3
    /// kVK_RightShift from Carbon HIToolbox. Not exposed in newer SDKs
    /// as a Swift constant, but the value is stable across macOS.
    private static let rightShiftKeyCode: Int64 = 60
    private static let enabledDefaultsKey = "co.vireo.doubleShiftEnabled"

    private let onDoubleTap: @MainActor () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastPress: Date?

    init(onDoubleTap: @escaping @MainActor () -> Void) {
        self.onDoubleTap = onDoubleTap
        self.isEnabled = UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true
    }

    func start() {
        guard isEnabled, eventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            log.info("AX not trusted — double-shift monitor inactive")
            return
        }

        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            // Re-enable the tap if macOS timed it out (user suspended input,
            // etc.). Return the event unchanged so we never block input.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon {
                    let monitor = Unmanaged<ShiftDoubleTapMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    Task { @MainActor in monitor.reEnableTap() }
                }
                return Unmanaged.passUnretained(event)
            }
            guard type == .flagsChanged, let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keycode == ShiftDoubleTapMonitor.rightShiftKeyCode else {
                return Unmanaged.passUnretained(event)
            }
            // Shift bit being set on this transition means key just went
            // down (it's the new state after the change).
            let pressed = event.flags.contains(.maskShift)
            let monitor = Unmanaged<ShiftDoubleTapMonitor>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in monitor.handlePress(pressed: pressed) }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            log.error("CGEvent.tapCreate returned nil — AX may have just been revoked")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        log.info("Double-shift monitor started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if enabled {
            start()
        } else {
            stop()
        }
    }

    // MARK: - Internals

    fileprivate func reEnableTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("Re-enabled double-shift tap after timeout")
    }

    /// Called on Right-Shift state change. We only act on press
    /// (release is ignored). Two presses within the window fires.
    fileprivate func handlePress(pressed: Bool) {
        guard pressed else { return }
        let now = Date()
        if let last = lastPress, now.timeIntervalSince(last) < Self.doubleTapWindow {
            log.info("Right-Shift double-tap")
            lastPress = nil
            onDoubleTap()
        } else {
            lastPress = now
        }
    }
}
