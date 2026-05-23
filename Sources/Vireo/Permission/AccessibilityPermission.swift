// AccessibilityPermission.swift — AX status tracking.
//
// Wraps AXIsProcessTrusted() with an AsyncStream / Combine publisher so the
// onboarding view can poll cleanly. Detects revocation at runtime.
//
// TODO: implement in Phase 1.

import ApplicationServices
import Foundation
