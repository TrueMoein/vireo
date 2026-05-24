// Materials.swift — Vireo glass + material tokens.
//
// macOS 26 Tahoe ships Liquid Glass via `.glassEffect(_:in:)`. For dev-mode
// fallback if a build environment lacks it, the same call sites can use
// `.background(.regularMaterial)` — visually similar, less premium.

import SwiftUI

extension View {
    /// Notch outer panel: real Liquid Glass on Tahoe via .glassEffect, with
    /// a subtle hairline overlay + deep shadow for the floating feel.
    func vireoGlassCard(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .glassEffect(.regular, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 12)
    }

    /// Inner pane (card-within-card use). Lighter glass so the outer surface
    /// reads through.
    func vireoGlassInner(cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .glassEffect(.clear, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.04), lineWidth: 0.5))
    }
}
