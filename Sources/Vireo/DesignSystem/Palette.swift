// Palette.swift — Vireo color tokens.
//
// Custom palette, intentionally avoiding Color.red / Color.green.
// Per docs/design-system.md the palette is:
//   • Mistake (coral)    #D97757
//   • Correction (sage)  #7BA889 light → #A8C9B0 highlight
//   • Surface (paper)    #F4F1EC light / #1C1B19 dark
//   • Accent (amber)     dusty, not yellow

import SwiftUI

extension Color {
    enum Vireo {
        /// Warm coral — mistakes, deletions, error tone.
        static let mistake = Color(red: 0.851, green: 0.467, blue: 0.341)

        /// Muted sage — corrections, additions, success tone.
        static let correction = Color(red: 0.482, green: 0.659, blue: 0.537)

        /// Lighter sage for emphasized correction tokens.
        static let correctionHighlight = Color(red: 0.659, green: 0.788, blue: 0.690)

        /// Paper-warm surface for cards in light mode.
        static let surfaceLight = Color(red: 0.957, green: 0.945, blue: 0.925)

        /// Paper-dark surface for cards in dark mode.
        static let surfaceDark = Color(red: 0.110, green: 0.106, blue: 0.098)

        /// Dusty amber — streaks, progress, accents. Not yellow.
        static let accent = Color(red: 0.788, green: 0.596, blue: 0.275)

        /// Warning tone (lighter coral / soft orange).
        static let warning = Color(red: 0.85, green: 0.55, blue: 0.20)

        /// Info tone for non-urgent notch messages.
        static let info = Color(red: 0.36, green: 0.55, blue: 0.78)
    }
}
