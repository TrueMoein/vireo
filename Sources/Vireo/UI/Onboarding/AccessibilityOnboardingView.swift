// AccessibilityOnboardingView.swift — custom Accessibility permission flow.
//
// The hostile default AXIsProcessTrustedWithOptions prompt is replaced by:
//   1. One-screen explanation + GIF of what the permission enables
//   2. Deep-link to
//      x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
//   3. Poll AXIsProcessTrusted() every 0.5 s while window is up
//   4. Auto-relaunch via NSWorkspace.shared.open + NSApp.terminate when granted
//   5. Detect revocation at runtime, re-enter onboarding if needed
//
// Single biggest cause of negative reviews on AX-dependent apps if skipped.
//
// TODO: implement in Phase 1.

import SwiftUI
