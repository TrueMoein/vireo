// AppCoordinator.swift — single activation surface.
//
// All four capture surfaces (hover button, double-shift, clipboard monitor,
// recall hotkey) call into AppCoordinator. It owns the pipeline:
//   capture → resolve text → LLM → CorrectionResult → notch present.
//
// TODO: implement in Phase 1.

import Foundation

@MainActor
final class AppCoordinator {
}
