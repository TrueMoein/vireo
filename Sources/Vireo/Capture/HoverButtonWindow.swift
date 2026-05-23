// HoverButtonWindow.swift — borderless NSPanel hosting the small Vireo bird
// button that blooms near the cursor when text is selected (PopClip-style).
//
// .nonactivatingPanel + .statusBar level so it floats above everything
// without stealing focus from the source app. Fade in / fade out via
// NSAnimationContext.

import AppKit
import SwiftUI

@MainActor
final class HoverButtonWindow {
    var onClick: (() -> Void)?

    private var panel: NSPanel?
    private static let size = CGSize(width: 36, height: 36)

    /// Show the button at the given cursor location (Cocoa coords —
    /// origin bottom-left). The button sits slightly to the right and below.
    func show(at mouseLocation: CGPoint) {
        let panel = ensurePanel()
        let origin = CGPoint(
            x: mouseLocation.x + 12,
            y: mouseLocation.y - 12 - Self.size.height
        )
        panel.setFrame(CGRect(origin: origin, size: Self.size), display: false)
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        guard let panel = panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            // NSAnimationContext completion runs on the main thread, but
            // Swift 6 doesn't see that statically; assume MainActor here.
            MainActor.assumeIsolated {
                panel?.orderOut(nil)
            }
        })
    }

    private func ensurePanel() -> NSPanel {
        if let existing = panel { return existing }
        let p = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = false
        p.contentView = NSHostingView(rootView: HoverButtonView(onClick: { [weak self] in
            self?.onClick?()
        }))
        panel = p
        return p
    }
}

private struct HoverButtonView: View {
    let onClick: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onClick) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                Circle()
                    .stroke(.white.opacity(0.35), lineWidth: 0.5)
                Image(systemName: "bird.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 28, height: 28)
            .scaleEffect(isHovered ? 1.12 : 1.0)
            .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
            .animation(.smooth(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Correct selection with Vireo")
    }
}
