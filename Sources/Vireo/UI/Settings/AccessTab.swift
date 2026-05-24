// AccessTab.swift — Settings tab for Accessibility permission state +
// dev-mode diagnostics.

import AppKit
import SwiftUI

struct AccessTab: View {
    @EnvironmentObject var permission: AccessibilityPermission
    /// Set by AppDelegate via .onAppear closure in SettingsView's Access tab
    /// so the "Re-run onboarding" button has something to call. We pass it
    /// through Notification to avoid threading another EnvironmentObject
    /// down the tab tree just for this rare button.
    @State private var onboardingTrigger: () -> Void = {}

    var body: some View {
        Form {
            if !permission.runningFromBundle {
                wrongBinarySection
            }

            Section("Accessibility") {
                if permission.isGranted {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.Vireo.correction)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Granted").font(.callout)
                            Text("Vireo can read selected text, post ⌘C to capture it, and write the corrected text back.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    deniedSection
                }
            }

            Section("Diagnostics") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Running binary")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(permission.runningBinaryPath)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Onboarding") {
                Button("Re-run onboarding…") {
                    OnboardingState.resetForTesting()
                    NotificationCenter.default.post(name: .vireoShowOnboarding, object: nil)
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .onAppear { permission.refresh() }
    }

    private var deniedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.Vireo.warning)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not granted").font(.callout)
                    Text("Vireo needs Accessibility to read selected text and write corrections back. After enabling the toggle in System Settings, quit and re-run Vireo.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Button("Request & open Settings…") {
                    permission.requestAndOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Quit Vireo") {
                    permission.quitForRelaunch()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    permission.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Re-check status")
            }
        }
    }

    private var wrongBinarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(Color.Vireo.warning)
                        .font(.title3)
                    Text("Running the wrong binary").font(.headline)
                }
                Text("This Vireo is the loose Xcode/swift-run executable. Its code signature changes on every rebuild, so Accessibility grants won't stick.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Quit, then in Terminal:\n  cd ~/Projects/vireo\n  bash scripts/run.sh")
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button("Quit Vireo") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}
