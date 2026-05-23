// ScreenCapabilities.swift — three-tier display detection.
//
// Returns one of:
//   .notch              — built-in display with notch (safeAreaInsets.top > 0)
//   .builtInNoNotch     — built-in display, no notch
//   .externalOnly       — lid closed or no built-in display attached
//
// Drives whether NotchPresenter uses DynamicNotchKit or FallbackPillWindow.
//
// TODO: implement in Phase 1.

import AppKit
