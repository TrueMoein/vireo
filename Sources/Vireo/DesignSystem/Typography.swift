// Typography.swift — Vireo text style tokens.
//
// Per docs/design-system.md:
//   • Body / chrome     SF Pro Text + Display (default .system)
//   • Corrected sentence (signature)  New York serif, semibold
//   • Inline diff tokens  SF Mono
//   • Stats / streak counters  SF Pro Rounded
//
// No third-party fonts.

import SwiftUI

extension Font {
    enum Vireo {
        /// The signature: corrected sentence in New York serif, semibold.
        static let correctedSentence = Font.system(.title3, design: .serif).weight(.medium)

        /// Card header (e.g., "Correction" label).
        static let cardHeadline = Font.headline

        /// Inline mistake diff token (original / fixed phrase).
        static let mistakeMono = Font.system(.callout, design: .monospaced)

        /// Category + rule label (uppercase, small).
        static let categoryChip = Font.caption2

        /// Plain-language mistake explanation.
        static let detail = Font.caption

        /// Status text in popover.
        static let statusLine = Font.callout

        /// Stats and streak counters — rounded variant of SF Pro.
        static let streak = Font.system(.title2, design: .rounded).weight(.semibold)
    }
}
