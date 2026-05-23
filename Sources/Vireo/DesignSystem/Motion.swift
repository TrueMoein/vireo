// Motion.swift — animation presets.
//
// Entry:           .smooth(duration: 0.35, extraBounce: 0.15)
// Dismiss:         .snappy(duration: 0.20)
// Notch expand:    .spring(response: 0.50, dampingFraction: 0.70)
// Notch collapse:  .spring(response: 0.35, dampingFraction: 0.85)
// Stagger:         delay(Double(i) * 0.04), capped at 5 items
// Signature trans: .blurReplace.combined(with: .scale(0.97))
//
// Never .easeInOut.
// Never simultaneous opacity + scale on content — pick scale (0.92 → 1.0).
//
// TODO: define in Phase 3.

import SwiftUI
