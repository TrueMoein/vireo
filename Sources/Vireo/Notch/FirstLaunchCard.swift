// FirstLaunchCard.swift — the signature first-launch moment.
//
// MeshGradient backdrop in palette tones with a single sentence typing
// itself in New York serif: "I'll quietly fix your English." Auto-dismisses
// after the line finishes typing + a brief pause. Shown once per user
// (UserDefaults flag set by NotchPresenter after the first show).

import SwiftUI

struct FirstLaunchCard: View {
    @State private var typed: String = ""
    @State private var meshT: Double = 0  // 0...1, animates the mesh points

    static let fullText = "I'll quietly fix your English."
    static let typingInterval: Duration = .milliseconds(55)

    var body: some View {
        ZStack {
            meshBackdrop

            VStack(alignment: .center, spacing: 14) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.Vireo.correction)

                Text(typed + " ")
                    .font(.system(.title2, design: .serif).weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }
            .padding(.vertical, 28)
        }
        .frame(width: 520, height: 200)
        .vireoGlassCard(cornerRadius: 28)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .task {
            await runTyping()
        }
        .onAppear { startMeshAnimation() }
    }

    private var meshBackdrop: some View {
        // Animate the middle column of the 3x3 grid so the glow drifts.
        let drift = sin(meshT * .pi * 2) * 0.08
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [Float(0.5 + drift * 0.5), 0], [1, 0],
                [0, Float(0.5 + drift * 0.4)], [0.5, 0.5], [1, Float(0.5 - drift * 0.4)],
                [0, 1], [Float(0.5 - drift * 0.5), 1], [1, 1],
            ],
            colors: [
                Color.Vireo.surfaceLight.opacity(0.85),
                Color.Vireo.correctionHighlight.opacity(0.55),
                Color.Vireo.surfaceLight.opacity(0.85),

                Color.Vireo.correction.opacity(0.42),
                Color.Vireo.accent.opacity(0.30),
                Color.Vireo.correction.opacity(0.42),

                Color.Vireo.surfaceLight.opacity(0.92),
                Color.Vireo.correctionHighlight.opacity(0.5),
                Color.Vireo.surfaceLight.opacity(0.92),
            ]
        )
        .blur(radius: 8)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func runTyping() async {
        // Brief pause before the cursor starts.
        try? await Task.sleep(for: .milliseconds(350))
        for i in Self.fullText.indices {
            try? await Task.sleep(for: Self.typingInterval)
            typed = String(Self.fullText[...i])
        }
    }

    private func startMeshAnimation() {
        withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
            meshT = 1
        }
    }
}
