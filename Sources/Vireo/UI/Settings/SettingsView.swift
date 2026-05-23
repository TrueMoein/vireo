// SettingsView.swift — Vireo settings.
//
// Phasing:
//   - Phase 1 (minimal, ship-ready):
//       • Provider section: paste OpenRouter API key (stored in Keychain),
//         pick a model, "Test connection" button.
//       • Hotkey field (KeyboardShortcuts recorder).
//   - Phase 7 (full): capture-surface toggles, behavior tuning,
//     sound on/off, privacy, diagnostics, about.
//
// Model picker UX (Phase 1):
//   - Free-text field accepting any OpenRouter model identifier
//     (e.g., "anthropic/claude-haiku-4.5", "google/gemini-3.1-flash").
//   - "Recommended (≥30B params)" subhead with quick-pick rows:
//       • anthropic/claude-haiku-4.5     (default)
//       • google/gemini-3.1-flash
//       • openai/gpt-4o-mini
//       • mistralai/mistral-large
//   - Warning state when user enters a known sub-30B model
//     (e.g., ibm-granite/granite-4.1-8b, meta-llama/llama-3.2-3b):
//       "Smaller models may produce unreliable structured output for
//        grammar coaching. ≥30B params is recommended."
//   - Warning is dismissible; their choice persists.
//
// TODO: implement Phase 1 minimal in Phase 1; full polish in Phase 7.

import SwiftUI
