# Contributing to Vireo

Thanks for considering a contribution. Vireo is a personal-scratch-an-
itch tool that happens to be open-source — the bar for accepted PRs is
"keeps the daily-driver feel" first, "follows the existing patterns"
second.

## Code of conduct

Be kind. Be specific. No personal attacks.

---

## Local dev setup

```bash
git clone https://github.com/TrueMoein/vireo
cd vireo
bash scripts/run.sh              # build, wrap in Vireo.app, launch
```

On first launch, Vireo's onboarding wizard prompts you for your
OpenRouter API key — paste it there and it lands in macOS Keychain
(service `co.vireo`, account `openrouter`). The key persists across
rebuilds, AX re-grants, and Vireo.app rebuilds, so you only ever enter
it once.

### Why `scripts/run.sh` and not `swift run`

macOS tracks Accessibility grants per binary code-signature hash, and
both `swift run` and Xcode produce a loose Mach-O whose hash changes
on every rebuild — so AX grants evaporate. `scripts/run.sh` wraps the
build in a proper `Vireo.app` bundle with stable bundle ID `co.vireo`.
Grant **Vireo.app** (not the loose binary) in System Settings →
Privacy & Security → Accessibility.

For sticky AX trust between rebuilds, create a self-signed code-signing
identity in Keychain Access (Certificate Assistant → Create a
Certificate → Self Signed Root → Code Signing) named **"Vireo Dev"**.
The build script auto-picks it up. Permanent fix is a real Apple
Developer ID ($99/yr) — same code path, different `--sign` argument.

### Faster iteration

```bash
swift build                      # type-check + compile only
swift run                        # launch loose binary (AX won't work)
```

The loose-binary path is fine for testing the LLM pipeline, the
Settings UI, and most SwiftUI work. Use `bash scripts/run.sh` whenever
you're touching capture surfaces or replace flows.

---

## Filing an issue

1. Search existing issues first.
2. Include: macOS version, Vireo version, reproducible steps.
3. For UI / visual issues: screenshot or short screen recording.
4. For capture-flow issues: **screenshot the Settings → Diagnostics
   tab**. It shows AX trust, every capture surface's state, the active
   style + model, and the database path — exactly what we need to
   triage.

---

## Pull requests

1. Fork; branch off `main`.
2. `swift build` must pass (no warnings introduced) before pushing.
3. Keep PRs focused — one logical change per PR. The diff should be
   readable in one sitting.
4. Reference the issue you're fixing in the description.
5. PRs that change behavior need a brief test plan (what to click /
   type to verify).

### Commit messages

We don't enforce conventional-commits. Subject lines should be
imperative ("Add streaming cancel button") and ~70 chars. Body is
optional — explain *why* if non-obvious.

---

## Code style

- SwiftFormat default rules.
- Prefer `struct` over `class` unless reference semantics are needed.
- Mark types `Sendable` where structurally possible.
- One file per top-level type; small helpers can live inline.
- No third-party fonts. Use SF Pro / New York / SF Mono only.
- Comments explain *why*, not *what*. The code already shows what.
- Default to no comments — only write one when the why is non-obvious
  (a hidden constraint, a subtle invariant, a workaround for a specific
  bug, or behavior that would surprise a reader).

---

## Adding a built-in correction style

1. Open `Sources/Vireo/LLM/CorrectionStyle.swift`.
2. Add a new stable UUID constant (e.g.,
   `static let myStyleID = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!`).
3. Append it to `CorrectionStyle.builtIns`.
4. Define the style at the bottom of the extension. The
   `systemPrompt` field is your **intent only** — the JSON return
   contract is appended automatically in `wrappedPrompt`. Look at the
   existing styles for the shape.
5. (Optional) Add it to the curated list in
   `OnboardingWindowView.swift → StylePickerStep.curated` if it's a
   good first-launch default.

That's it. The new style automatically appears in Settings → Styles,
the notch correction-card chip menu, and the Diagnostics tab's
"Active style" row.

## Adding an LLM provider

See [`docs/llm-providers.md`](docs/llm-providers.md). The short version:
conform to `ProviderAdapter`, decode to `CorrectionResult`, and the rest
of the pipeline (streaming card, persistence, weakness tracking,
History) just works.

## Adding a capture surface

Existing surfaces all funnel into
`AppCoordinator.correct(text:styleID:)`. The pattern:

1. Create a class under `Sources/Vireo/Capture/`, typically
   `@MainActor` + `ObservableObject` with an `isEnabled` toggle backed
   by UserDefaults.
2. On detection, call `coordinator.correct(text:styleID:nil)` (or
   `correctFromClipboard(text:)` for clipboard-style flows where
   Replace should re-write the clipboard instead of doing AX writeback).
3. Wire it through `AppDelegate` and add a toggle to
   `ShortcutsTab.swift`.
4. Add a row to the Diagnostics panel.

---

## Changing the design system

The palette, typography, motion presets, and material rules in
`Sources/Vireo/DesignSystem/` are intentionally limited. Read
[`docs/design-system.md`](docs/design-system.md) before proposing
changes — the constraints are part of the product.

## Project status

Active development, single-maintainer focus. Phases 0–6 of the original
plan are shipped; Phase 7 (notarization, Sparkle wiring, Homebrew Cask,
GitHub Actions) is the remaining ship-readiness work. The
[`docs/plan.md`](docs/plan.md) file is the historical roadmap; current
priorities live in issues + the in-flight planning notes.
