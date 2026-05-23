// Motion.swift — Vireo animation tokens.
//
// Per docs/design-system.md. Never .easeInOut (reads dated).

import SwiftUI

extension Animation {
    enum Vireo {
        /// Default entry animation (content appearing).
        static let entry = Animation.smooth(duration: 0.35, extraBounce: 0.15)

        /// Default dismiss animation.
        static let dismiss = Animation.snappy(duration: 0.20)

        /// Notch expand spring.
        static let notchExpand = Animation.spring(response: 0.50, dampingFraction: 0.70)

        /// Notch collapse spring.
        static let notchCollapse = Animation.spring(response: 0.35, dampingFraction: 0.85)

        /// Microinteraction (hover, focus, press feedback).
        static let microInteraction = Animation.smooth(duration: 0.18)

        /// Stagger delay between sequential items, capped at 5.
        static func staggered(index i: Int) -> Animation {
            .smooth(duration: 0.30, extraBounce: 0.12)
                .delay(Double(min(i, 5)) * 0.04)
        }
    }
}
