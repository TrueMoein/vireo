# Vireo — a notch-resident English coach for macOS

## Context

You write prompts daily for AI and Discord messages for your team. For 1–2 years
the workflow has been: write text → paste into a chat → ask for grammar fixes →
copy back. The loop fixes the symptom — clean output — but never teaches the
lesson. The same mistakes recur indefinitely.

**Vireo** closes that loop by living *inside the Mac notch*. Select an
English sentence anywhere, a small Vireo silhouette blooms next to your cursor;
tap it and the notch slides down with the corrected version, a per-mistake
breakdown, and a "save & learn" affordance. Every correction trains a personal weakness
model; recurring weaknesses become 5-minute spaced-repetition drills generated
from your own sentences. Open source from day one. Aimed to ship a daily-driver
app that looks and feels better than Raycast or the ChatGPT Mac app.

## Amendments to the approved plan

- **2026-05-23 — LLM provider strategy switched to OpenRouter.** Instead of
  shipping two adapters (Anthropic + OpenAI) at v0.1, a single
  `OpenRouterAdapter` covers ~100 models via one OpenAI-compatible API and
  one Keychain entry. Model name becomes a runtime setting. Defaults:
  `ibm-granite/granite-4.1-8b` for routine corrections (per user preference;
  watch 8B's structured-output reliability),
  `anthropic/claude-opus-4.7` for Phase 5 review-exercise generation.
  `AnthropicAdapter` and `OpenAIAdapter` files remain as skeletons for
  future direct-provider integration (BYO key, cost transparency,
  prompt caching, org compliance). See `docs/llm-providers.md` for details.

## Product shape

**Three capture surfaces, ranked by friction**

1. **PopClip-style hover button on selection** *(primary, default-on)* — select
   text anywhere, a small Vireo silhouette blooms ~100 ms later next to the
   caret. Click it → notch expands with correction. Uses `AXObserver` +
   `kAXSelectedTextChangedNotification`, debounced. Reference: Xpop.
2. **Double-tap Right-Shift** *(secondary)* — captures current AX selection if
   any, otherwise opens the notch in compose mode. Codex's Cmd-Cmd ergonomic,
   shifted off Cmd to avoid the macOS screenshot collision.
3. **Filtered clipboard monitor** *(tertiary, opt-in, auto-suggested after 3
   days of use)* — when you copy a sentence-shaped English string, the notch
   pulses gently. Filter: 12–2000 chars, has lowercase + spaces, not code/URL,
   `NLLanguageRecognizer` confidence > 0.85, not in last-5 clipboard items.

Hotkey (e.g., `⌥⇧Space`) stays as a hidden power-user surface for "recall last
correction." App Intents (`CoachEnglishIntent`) registers us with Shortcuts and
the Apple Intelligence Writing Tools sheet, so users on macOS 26+ get a
"Vireo" action without us reinventing Apple's UI.

**Notch as the primary delivery surface**

When a correction is ready, the notch auto-expands with a `ConcentricRectangle`
that morphs from the device's actual notch curvature into a glass card. Inside:

- Original sentence rendered in coral with strikethrough on changed tokens
- Corrected sentence in `New York` serif, semibold, sage tint on the edits
- Inline mistake breakdown: category icon (SF Symbol 7 with drawing animation),
  short rule, optional "show example" disclosure
- `[Replace]` pastes corrected text back, `[Copy]`, `[Save & Learn]` (flags for
  emphasis in upcoming review session)
- Auto-collapses to a pill after 4 s, fully hides after 12 s; click pill to pin

On non-notch Macs we drop a glass pill anchored to the menubar icon's
screen-x position with the same content morph — no fake notch. Three-tier
detection: `safeAreaInsets.top > 0` → notch, else built-in display → anchored
pill, else (external-only / clamshell) → top-center HUD.

**The learning flywheel**

Every correction logs each mistake tagged by category (article, tense,
preposition, agreement, word-order, vocab, L1-interference). A "weakness
item" = `category × specific rule`. After 3+ instances it enters the
`swift-fsrs` (FSRS-6) review queue. Weekly the notch surfaces a 5-minute
review built from drills synthesized from your *actual* recent mistakes
(cached LLM call). 30 correct uses in real writing demotes the weakness
to "passive."

## Architecture

**Stack (final)**

- Swift 5.10+, SwiftUI, **macOS 26 Tahoe target** (Liquid Glass requires it;
  the user's machine is on Tahoe; OSS distribution targets Tahoe-first, older
  macOS can be back-ported in v1.1 if there's demand)
- LSUIElement = true (no Dock icon)
- `MenuBarExtra` for settings/history surface, `DynamicNotchKit` for the notch
- `KeyboardShortcuts` (sindresorhus) — hotkey + user-customization UI
- `GRDB.swift` — persistence + FTS5 over corrected text
- `open-spaced-repetition/swift-fsrs` — review scheduling
- `Sparkle 2` — auto-updates
- Keychain Services for API keys
- App Intents framework for Writing Tools / Shortcuts integration

**Module structure (the critical files to be created)**

```
Sources/Vireo/
├── App/
│   ├── VireoApp.swift          # MenuBarExtra + Notch scene root
│   └── AppCoordinator.swift             # one activation surface (capture → present)
├── Capture/                             # the three capture surfaces
│   ├── SelectionObserver.swift          # AXObserver on kAXSelectedTextChangedNotification
│   ├── HoverButtonWindow.swift          # borderless NSPanel near caret (PopClip-style)
│   ├── ShiftDoubleTapMonitor.swift      # CGEvent tap for Right-Shift double-tap
│   ├── ClipboardMonitor.swift           # NSPasteboard + sentence heuristic + NLLanguageRecognizer
│   └── SelectedTextResolver.swift       # AX fast-path + simulated Cmd+C fallback
├── Notch/
│   ├── NotchPresenter.swift             # DynamicNotchKit wrapper, pill ↔ card state machine
│   ├── CorrectionCard.swift             # matched-geometry pill→card morph
│   ├── ScreenCapabilities.swift         # 3-tier detection (notch / built-in / external-only)
│   └── FallbackPillWindow.swift         # non-notch presentation
├── LLM/
│   ├── ProviderAdapter.swift            # protocol → CorrectionResult
│   ├── AnthropicAdapter.swift           # tool-use w/ return_correction tool
│   ├── OpenAIAdapter.swift              # strict structured outputs
│   ├── CorrectionResult.swift           # one Codable struct
│   └── ProviderManager.swift            # provider/model routing, retries
├── Coach/
│   ├── WeaknessTracker.swift            # promotes mistakes → weakness items
│   ├── SpacedRepetition.swift           # swift-fsrs wrapper
│   ├── ReviewSessionBuilder.swift       # drills from real mistakes (cached LLM)
│   └── ProgressReporter.swift           # weekly stats
├── Persistence/
│   ├── Database.swift                   # GRDB pool + migrations + FTS5
│   └── Models/                          # Session · Mistake · Category · WeaknessItem
├── DesignSystem/
│   ├── Palette.swift                    # coral / sage / paper warm / dusty amber
│   ├── Typography.swift                 # SF Pro + New York serif + SF Mono roles
│   ├── Motion.swift                     # spring presets, transitions
│   └── Materials.swift                  # glass effect helpers
├── UI/
│   ├── Settings/SettingsView.swift
│   ├── History/HistoryView.swift        # FTS5-backed search
│   ├── Review/ReviewSessionView.swift
│   ├── Progress/ProgressView.swift      # 14-day stacked bar that morphs to sentences
│   └── Onboarding/                      # AX onboarding + first-launch wow
├── Permission/
│   ├── AccessibilityPermission.swift    # custom AX onboarding (deep-link, poll, auto-relaunch)
│   └── KeychainStore.swift
├── Intents/
│   └── CoachEnglishIntent.swift         # App Intent for Writing Tools / Shortcuts
└── Diagnostics/
    └── DiagnosticsView.swift            # AX / hotkey / hover-observer status
```

## Design system

These are the bones — implementation fleshes the rest out, but these we settle
now so the visual language stays coherent.

**Palette** (custom, *not* `Color.red/green`)
- Mistake: warm coral `#D97757` (calmest "wrong" on display; Anthropic's accent)
- Correction: muted sage `#7BA889` → highlight `#A8C9B0`
- Surface (paper-warm): `#F4F1EC` light / `#1C1B19` dark
- Accent (streak/progress): dusty amber, not yellow
- Avoid: pure white/black, Duolingo green, system reds at large sizes

**Typography**
- Body / chrome: SF Pro Text + Display, optical sizing
- **Corrected sentence: New York serif** — this is the signature move, sets
  user-quoted content visually apart from chrome
- Inline diff tokens: SF Mono
- Stats / streak counters: SF Pro Rounded
- No third-party fonts — Inter / Söhne / Berkeley Mono make a macOS app feel
  Electron in 2026

**Motion**
- Entry: `.smooth(duration: 0.35, extraBounce: 0.15)`
- Dismiss: `.snappy(duration: 0.2)`
- Notch expand: `.spring(response: 0.5, dampingFraction: 0.7)`
- Notch collapse: `.spring(response: 0.35, dampingFraction: 0.85)`
- Stagger (multi-mistake reveal): `delay(Double(i) * 0.04)`, cap at 5
- Signature transition: `.blurReplace.combined(with: .scale(0.97))`
- Never `.easeInOut` — reads as dated
- Never simultaneous opacity + scale on content — pick scale (0.92 → 1.0)

**Materials**
- Notch outer panel: `.glassEffect(.regular)` inside one `GlassEffectContainer`
- Inner correction card: `.glassEffect(.clear.tint(palette.surface.opacity(0.4)))`
- HUDs / transient banners: `.ultraThinMaterial`
- MenuBarExtra: still bridges `NSVisualEffectView` for system parity

**Sound** — one tasteful chime on correction reveal (~150 ms, –20 LUFS),
opt-in, default off. No haptics on M-series Macs (Force Touch is gone) except
the trackpad's `NSHapticFeedbackManager` which we won't use here.

**Signature moments**
- *First-launch wow*: notch expands, `MeshGradient` animates behind glass, a
  single sentence types itself in New York serif — *"I'll quietly fix your
  English."* — then collapses. No buttons. (Reference: Bezel onboarding.)
- *Correction reveal*: notch morphs via `ConcentricRectangle` from device-corner
  curvature into a card; content fades in with `.blurReplace` at `delay: 0.15`
  while the frame is still expanding. The make-or-break detail.
- *Progress visualisation*: 14-day **horizontal stacked bar** of error
  categories built with Swift Charts; tap a day, the bar **morphs via
  `matchedGeometryEffect` into the actual sentences from that day**.

## Phase plan (~6–8 weeks of evening work)

**Phase 0 — Setup (~1 day)**
Xcode project, SPM dependencies, signing identity, repo, MIT license, README skeleton.

**Phase 1 — Notch + first capture surface (~1.5 weeks)**
`DynamicNotchKit` integration, `ScreenCapabilities` 3-tier detection, basic
`CorrectionCard` pill ↔ expanded morph, **hotkey-triggered correction loop**
end-to-end with Anthropic provider. Selected text via AX + Cmd+C fallback.
Keychain-stored API key. Custom Accessibility onboarding flow (deep-link, poll,
auto-relaunch — non-negotiable).

**Phase 2 — PopClip-style primary capture (~1 week)**
`AXObserver` on `kAXSelectedTextChangedNotification`, debounced. Floating
hover button (`NSPanel`, `.nonactivatingPanel`). Test in Discord, Chrome, Arc,
Notes, Mail, VS Code. Privacy + UX polish: hover button must feel like a
selection chrome extension, not a popup.

**Phase 3 — Design system + Liquid Glass polish (~1 week)**
Lock palette, typography (New York serif for corrected sentence), motion
presets, the `GlassEffectContainer` notch surface, mesh-gradient onboarding,
diff-style mistake rendering. This phase is about feel: nothing ships looking
half-finished.

**Phase 4 — Learning DB + second provider (~1 week)**
GRDB schema, FTS5 on corrected text, per-mistake category tagging via LLM
structured output, History view with search. Add OpenAI adapter — proves the
adapter abstraction is right *before* shape rot sets in.

**Phase 5 — Adaptive coach (~1.5 weeks)**
`WeaknessTracker` promotes recurring mistakes, `swift-fsrs` scheduling, review
session UI with drills synthesized from your real recent mistakes, weekly
progress summary, the 14-day stacked-bar progress view with sentence morph.

**Phase 6 — Secondary capture + Apple Intelligence integration (~0.5 week)**
Double-tap Right-Shift via `CGEvent` tap, filtered clipboard monitor (default
off, auto-suggest after 3 days), `CoachEnglishIntent` registered for Writing
Tools / Shortcuts.

**Phase 7 — Polish & OSS launch (~1 week)**
Diagnostics panel, settings UI (hotkey, providers, models, defaults, per-surface
toggles), notarization, Sparkle 2 appcast, Homebrew Cask submission,
screenshots, contributing guide, architecture + learning-model docs.

## Key technical decisions (settled)

- **`DynamicNotchKit` (MrKai77) for the notch.** Production-ready in 2026,
  MIT, actively maintained, async API. Roll-your-own only if we outgrow it.
- **Hotkey-triggered + auto-show on correction, NOT hover-first.** Hover is
  for ambient widgets; corrections are event-driven. Hovering mid-sentence is
  the opposite of what we want. Hover the *pill* to re-expand = recall, not
  primary.
- **PopClip-style hover *button* as primary capture surface.** Not the same
  as notch-hover — this is a tiny button near the caret, triggered by
  selection. AXObserver + `kAXSelectedTextChangedNotification`. Reference:
  Xpop (OSS, DongqiShen).
- **GRDB over SwiftData.** Tens-of-thousands rows + FTS5 needed for "find my
  past mistakes about prepositions". SwiftData maturity isn't there.
- **FSRS-6 (`swift-fsrs`) over SM-2.** ~25% fewer reviews for equivalent
  retention. Maps cleanly to "weakness item" abstraction (not discrete cards).
- **One JSON Schema, two enforcement modes.** Anthropic tool-use + OpenAI
  strict structured outputs both decode to the same `CorrectionResult`
  Codable. Authored to OpenAI's stricter subset for portability.
- **Custom Accessibility onboarding.** Default `AXIsProcessTrustedWithOptions`
  prompt is hostile + requires app relaunch users don't realize. We do
  explanation → deep-link → poll → auto-relaunch ourselves.
- **No ambient field-watching in v1.** Yes it's technically viable
  (Grammarly does it). Skip for v1: battery cost, permissions creep, the
  *perceived surveillance* on a personal Mac. Revisit in v2 only if retention
  data justifies.
- **Ride Apple Intelligence Writing Tools, don't fight.** App Intents
  registers us with the system sheet. Position: *"Writing Tools fixes it,
  Vireo teaches you to fix it yourself."*
- **macOS 26 Tahoe target for v1.0.** Liquid Glass is the headline visual
  feature. User's machine is on Tahoe. Older macOS support can be added in
  v1.1 if OSS demand surfaces — better than launching with downscaled visuals.
- **Distribution: Developer ID + notarization + Sparkle 2 + Homebrew Cask.**
  Skip MAS — accessibility-API apps can't sandbox cleanly.

## Dependencies

| Package | Purpose |
|---|---|
| [`MrKai77/DynamicNotchKit`](https://github.com/MrKai77/DynamicNotchKit) | Notch overlay |
| [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkey + recorder UI |
| [`groue/GRDB.swift`](https://github.com/groue/GRDB.swift) | Persistence + FTS5 |
| [`open-spaced-repetition/swift-fsrs`](https://github.com/open-spaced-repetition) | Review scheduling |
| [`sparkle-project/Sparkle`](https://sparkle-project.org/) | Auto-update |

## Read before writing equivalents

- [`DongqiShen/Xpop`](https://github.com/DongqiShen/Xpop) — OSS PopClip-style hover popup, Swift, MIT
- [`Hammerspoon/hammerspoon`](https://github.com/Hammerspoon/hammerspoon) `extensions/axuielement/observer.m` — C-level AX observer dance
- [`tisfeng/SelectedTextKit`](https://github.com/tisfeng/SelectedTextKit) — selected-text capture w/ AX + clipboard fallback
- [`Artlands/InplaceAI`](https://github.com/Artlands/InplaceAI) — closest functional analog
- [`tisfeng/Easydict`](https://github.com/tisfeng/Easydict) — multi-provider LLM menubar app architecture
- [`TheBoredTeam/boring.notch`](https://github.com/TheBoredTeam/boring.notch) — bug tracker is a goldmine of notch edge cases

## Visual benchmarks (apps to study screenshots / behavior of)

- **Bezel** (Lux) — gold standard for notch expand feel
- **Sky** (Shortcut team, 2025) — closest competitor to ChatGPT Mac, materially better
- **Granola** — live-transcription UI, directly relevant
- **Mela** — restrained SF Pro + color
- **Tempo** — calendar with exemplary glass + spring choreography
- **Plinky** / **NotePlan 3** / **MindNode 2025** — calm coaching palette
- **Things 3** completion sound — the right reference for the correction chime

## Open decisions for you

These don't block the plan; flag your preference and we'll bake it in:

1. **L1-interference taxonomy.** Persian (your L1) has no articles and a
   different verb-aspect system. Bake "L1 interference" categories into the
   mistake taxonomy from day one? Sharpens your personal weakness signal,
   and any Persian/Arabic/Slavic L1 user gets value too. Cost: extra
   classification logic in the LLM prompt + UI label.

2. **Default capture mix.** I'd ship all three surfaces enabled, with the
   PopClip-style hover button as the visible default and clipboard monitor
   off until day 3. Comfortable with that, or do you want the hover button
   to be opt-in for the first week as well?

3. **Default models.** Recommendation: Claude Haiku 4.5 for routine
   corrections (fast, cheap, accurate enough for grammar), Claude Opus 4.7
   for review-exercise generation (rare, quality matters). Settings UI
   exposes both, configurable per-feature. Acceptable?

## Verification (per phase)

- **After Phase 1:** Open Discord. Type a sentence with 3 known mistakes.
  Select it, press hotkey. Notch slides down with the corrected text + 3
  mistake breakdowns within 4 s. `[Copy]` round-trips back to the message.
- **After Phase 2:** Repeat the above without the hotkey — select text and
  watch the hover button bloom next to the caret in Discord, Chrome, Arc,
  Notes, Mail, VS Code. Click it → same notch flow.
- **After Phase 3:** Visual review pass. Notch morph reads as "liquid," not
  "resized." Corrected sentence in New York serif. Coral/sage diff is legible
  in both light and dark mode at default UI scaling. Onboarding sentence
  types in elegantly.
- **After Phase 4:** 20 corrections across 3 days. Open History, search
  "article" — relevant entries returned, each row category-tagged. Switching
  provider in Settings (Anthropic → OpenAI) changes nothing visible.
- **After Phase 5:** Force 5 article-omission mistakes. The category becomes
  an active weakness item. Trigger a review session — drill sentences
  resemble your real recent writing. Answer correctly 10×; FSRS pushes the
  next review out. Open the progress view, tap a day in the stacked bar —
  the bar morphs into the day's sentences.
- **After Phase 6:** Right-Shift double-tap captures selection. Copy a long
  English sentence — clipboard monitor surfaces a notch pulse. Trigger
  `CoachEnglishIntent` from Shortcuts — it runs.
- **After Phase 7:** Fresh-install on a clean Mac. Onboarding walks AX
  permission without manual relaunch. Sparkle finds and applies a test
  update. `brew install --cask vireo` works.

## Repository layout

```
vireo/
├── Sources/Vireo/                   # app code (module structure above)
├── Tests/VireoTests/                # XCTest unit + integration
├── Resources/                       # icons, sounds, mesh-gradient seeds
├── Vireo.xcodeproj
├── Package.swift                    # SPM manifest
├── README.md                        # screenshots, install, philosophy
├── LICENSE                          # MIT
├── CONTRIBUTING.md
├── docs/
│   ├── architecture.md
│   ├── design-system.md             # palette, motion, type
│   ├── llm-providers.md             # how to add a provider
│   └── learning-model.md            # FSRS + weakness items
└── .github/workflows/               # build, test, notarize-on-tag
```
