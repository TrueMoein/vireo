// CompactBirdIcon.swift — the persistent bird in the notch's compact trailing
// slot. Resting state of Vireo.
//
// Phase 1: SF Symbol "bird.fill" with subtle hover scale-up + tint.
// Phase 3 will swap for a custom Vireo silhouette and add the symbol-effect
// animation when a correction arrives ("the bird notices something").

import SwiftUI

struct CompactBirdIcon: View {
    @State private var isHovered = false

    var body: some View {
        Image(systemName: "bird.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tint)
            .frame(width: 24, height: 24)
            .scaleEffect(isHovered ? 1.12 : 1.0)
            .opacity(isHovered ? 1.0 : 0.85)
            .animation(.smooth(duration: 0.22, extraBounce: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
            .accessibilityLabel("Vireo")
            .accessibilityHint("Hover to open Vireo")
    }
}
