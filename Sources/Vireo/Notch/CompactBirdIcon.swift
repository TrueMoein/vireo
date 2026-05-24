// CompactBirdIcon.swift — the persistent bird in the notch's compact
// trailing slot. Resting state of Vireo.

import SwiftUI

struct CompactBirdIcon: View {
    @State private var isHovered = false

    var body: some View {
        Image(systemName: "bird.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.Vireo.correction)
            .frame(width: 24, height: 24)
            .scaleEffect(isHovered ? 1.12 : 1.0)
            .opacity(isHovered ? 1.0 : 0.88)
            .animation(.Vireo.microInteraction, value: isHovered)
            .onHover { isHovered = $0 }
            .accessibilityLabel("Vireo")
            .accessibilityHint("Hover to open Vireo")
    }
}
