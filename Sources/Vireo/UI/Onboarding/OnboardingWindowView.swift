// OnboardingWindowView.swift — first-launch 4-step wizard.
//
// Steps: welcome (MeshGradient + serif tagline) → API key → Accessibility
// permission → ready ("you're set"). Each step has a back/next pair at
// the bottom; the last step replaces Next with Done which closes the
// window and sets the hasOnboarded flag.

import AppKit
import SwiftUI

struct OnboardingWindowView: View {
    @StateObject private var state: OnboardingState
    let onComplete: () -> Void

    init(settings: SettingsModel, permission: AccessibilityPermission, onComplete: @escaping () -> Void) {
        _state = StateObject(wrappedValue: OnboardingState(settings: settings, permission: permission))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            Group {
                switch state.step {
                case .welcome:        WelcomeStep().environmentObject(state)
                case .apiKey:         APIKeyStep().environmentObject(state)
                case .accessibility:  AccessibilityStep().environmentObject(state)
                case .ready:          ReadyStep().environmentObject(state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))))
            footer
        }
        .frame(width: 580, height: 500)
        .background(.regularMaterial)
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingState.Step.allCases, id: \.self) { step in
                let active = step.rawValue <= state.step.rawValue
                Capsule()
                    .fill(active ? Color.Vireo.correction : Color.secondary.opacity(0.2))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .animation(.smooth(duration: 0.25), value: state.step)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack {
            if state.canGoBack {
                Button("Back") { state.back() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Spacer()
            if state.isLastStep {
                Button("Done") {
                    state.complete()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Vireo.correction)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
            } else {
                Button("Next") { state.next() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.Vireo.correction)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!nextEnabled)
            }
        }
        .padding(20)
    }

    private var nextEnabled: Bool {
        switch state.step {
        case .welcome:        return true
        case .apiKey:         return state.settings.hasAPIKey
        case .accessibility:  return true  // user may skip; AX needed before hotkey works
        case .ready:          return true
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    @EnvironmentObject var state: OnboardingState
    @State private var meshT: Double = 0
    @State private var typed: String = ""

    static let fullText = "Hi. I'm Vireo. I'll help you learn English from your own writing."
    static let typingInterval: Duration = .milliseconds(28)

    var body: some View {
        ZStack {
            meshBackdrop
                .opacity(0.75)
            VStack(spacing: 18) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(Color.Vireo.correction)
                Text(typed + " ")
                    .font(.system(.title, design: .serif).weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 40)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(20)
        .task { await runTyping() }
        .onAppear { startMesh() }
    }

    private var meshBackdrop: some View {
        let drift = sin(meshT * .pi * 2) * 0.08
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [Float(0.5 + drift * 0.5), 0], [1, 0],
                [0, Float(0.5 + drift * 0.4)], [0.5, 0.5], [1, Float(0.5 - drift * 0.4)],
                [0, 1], [Float(0.5 - drift * 0.5), 1], [1, 1],
            ],
            colors: [
                Color.Vireo.surfaceLight.opacity(0.7),
                Color.Vireo.correctionHighlight.opacity(0.45),
                Color.Vireo.surfaceLight.opacity(0.7),
                Color.Vireo.correction.opacity(0.35),
                Color.Vireo.accent.opacity(0.25),
                Color.Vireo.correction.opacity(0.35),
                Color.Vireo.surfaceLight.opacity(0.75),
                Color.Vireo.correctionHighlight.opacity(0.4),
                Color.Vireo.surfaceLight.opacity(0.75),
            ]
        )
        .blur(radius: 6)
    }

    private func runTyping() async {
        try? await Task.sleep(for: .milliseconds(300))
        for i in Self.fullText.indices {
            try? await Task.sleep(for: Self.typingInterval)
            typed = String(Self.fullText[...i])
        }
    }

    private func startMesh() {
        withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
            meshT = 1
        }
    }
}

private struct APIKeyStep: View {
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(
                icon: "key.fill",
                title: "Add your OpenRouter API key",
                subtitle: "Vireo uses your key to talk to the language model. Your key stays in macOS Keychain — never on a server."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("API key")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                SecureField("sk-or-v1-…", text: Binding(
                    get: { state.settings.apiKey },
                    set: { state.settings.apiKey = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                HStack(spacing: 4) {
                    Text("Get one at")
                    Link("openrouter.ai/keys", destination: URL(string: "https://openrouter.ai/keys")!)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Model")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TextField("vendor/model", text: Binding(
                    get: { state.settings.model },
                    set: { state.settings.model = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                Text("Default is fine. ≥30B params recommended; change later in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
    }
}

private struct AccessibilityStep: View {
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(
                icon: "lock.shield.fill",
                title: "Grant Accessibility permission",
                subtitle: "So Vireo can read selected text from any app, and replace it with the correction when you click Replace."
            )

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state.permission.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(state.permission.isGranted ? Color.Vireo.correction : Color.Vireo.warning)
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.permission.isGranted ? "Granted" : "Not granted yet")
                        .font(.callout.weight(.medium))
                    Text(state.permission.isGranted
                         ? "You're good to go. Click Next to continue."
                         : "Click below, then enable Vireo in System Settings. You may need to quit and relaunch Vireo for the grant to take effect."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if !state.permission.isGranted {
                Button {
                    state.permission.requestAndOpenSettings()
                } label: {
                    Label("Open System Settings…", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.Vireo.correction)
                .controlSize(.large)
            }

            Text("You can skip this and grant later from Settings → Access. The hotkey and hover button won't work until you do.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .onAppear { state.permission.refresh() }
    }
}

private struct ReadyStep: View {
    @EnvironmentObject var state: OnboardingState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader(
                icon: "sparkles",
                title: "You're set",
                subtitle: "Vireo lives in the menubar / notch. Try it now — select some text in any app and press the hotkey."
            )

            VStack(alignment: .leading, spacing: 10) {
                tipRow(
                    icon: "command",
                    title: "Hotkey",
                    detail: "⌥⇧Space (configurable in Settings → Shortcuts)"
                )
                tipRow(
                    icon: "cursorarrow.rays",
                    title: "Or click the bird",
                    detail: "A small Vireo silhouette blooms near the cursor when you select text in supported apps."
                )
                tipRow(
                    icon: "wand.and.stars",
                    title: "Get coached over time",
                    detail: "Patterns you keep getting wrong get scheduled for spaced-repetition reviews. Hover the notch to see your coach summary."
                )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
    }

    private func tipRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.Vireo.correction)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Shared

@ViewBuilder
private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
        Image(systemName: icon)
            .font(.system(size: 28))
            .foregroundStyle(Color.Vireo.correction)
            .frame(width: 32)
            .padding(.top, 4)
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.title2, design: .serif).weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
