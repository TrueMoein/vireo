# Architecture

This is the map a new contributor needs to find their way around in
10 minutes. The companion file [`design-system.md`](design-system.md)
covers palette / typography / motion, and
[`llm-providers.md`](llm-providers.md) covers the LLM contract.

## Module layout

```
Sources/Vireo/
├── App/                  # @main entry, NSApplicationDelegate, AppCoordinator
├── Capture/              # five capture surfaces + selected-text resolver
├── Coach/                # weakness tracker, SM-2 scheduler, drill generator, idle coach
├── DesignSystem/         # palette, typography, motion, glass materials
├── Diagnostics/          # the Settings → Diagnostics panel
├── Intents/              # AppIntent + AppShortcutsProvider for Shortcuts.app
├── LLM/                  # OpenRouterAdapter, CorrectionStyle/Store, streaming parser
├── Notch/                # NotchPresenter state machine + all card views
├── Permission/           # Accessibility trust + Keychain
├── Persistence/          # GRDB Database, migrations, Session + Mistake + WeaknessItem
├── UI/Main/              # main window: History, Patterns, ReviewSession
├── UI/Onboarding/        # 5-step first-launch wizard
├── UI/Settings/          # five Settings tabs + SettingsModel
└── Utility/              # tiny helpers (Date+CompactRelative, etc.)
```

Tests live in `Tests/VireoTests/`.

## Five capture surfaces

All of them call into `AppCoordinator` and produce a `CorrectionResult`:

| Surface | File | Trigger | Trigger source |
|---|---|---|---|
| Hotkey | `KeyboardShortcuts` integration | `⌥⇧Space` (configurable) | `.selection` |
| Hover button | `HoverButtonController` + `HoverButtonWindow` | 200ms AX poll of `kAXSelectedTextAttribute` while Vireo isn't frontmost | `.selection` |
| Double-shift | `ShiftDoubleTapMonitor` | Two Right-Shift presses within 300ms (CGEventTap on `.flagsChanged`) | `.selection` |
| Clipboard | `ClipboardMonitor` | `NSPasteboard.changeCount` delta + sentence filter + `NLLanguageRecognizer` | `.clipboard` |
| Shortcuts intent | `CoachEnglishIntent` (via `VireoShortcuts: AppShortcutsProvider`) | Apple Shortcuts invocation | `.selection` (intent-passed text) |

`AppCoordinator.lastTriggerSource` records which one fired. The
**Replace** action branches on it: `.selection` does AX writeback into
the focused element with pasteboard + ⌘V fallback; `.clipboard` writes
the corrected text back to the pasteboard and stops.

## End-to-end correction pipeline

```
[capture surface]
        │
        ▼  (selection-based surfaces only)
SelectedTextResolver        AX fast-path → ⌘C clipboard fallback
        │
        ▼
AppCoordinator.correct(text:styleID:)
        │
        ▼
CorrectionStyleStore.resolve(id:)         → CorrectionStyle.wrappedPrompt
        │
        ▼
OpenRouterAdapter (streaming or non-streaming, picked by settings.streamingEnabled)
        │
        ├─ stream:true → SSE → StreamingJSONFieldExtractor → onPartialCorrection
        │                                                            │
        │                                                            ▼
        │                                                NotchPresenter.updateStreaming
        │
        ▼
CorrectionResult (correctedText + mistakes + originalText + styleID)
        │
        ├──► NotchPresenter.showCorrection → CorrectionCard
        │                                       │
        │                                       └─ chip menu re-runs via correct(text:styleID:newID)
        │
        └──► Task.detached:
                SessionRepository.save        (Session row + Mistake rows; styleID stored)
                WeaknessTracker.ingest        (upserts weakness_item, promotes at count ≥ 3)
                SessionStore.reload           (refreshes History + Recent UI)
```

## Notch state machine

`NotchPresenter` owns one `DynamicNotch` instance. Its display state is
`NotchModel.Display`:

| State | Trigger | View |
|---|---|---|
| `.idle` | Resting | (compact bird icon) |
| `.popover` | Hover-enter, after 150ms | `NotchPopover` (header + cards + footer) |
| `.busy(label)` | Non-streaming correction in flight | `BusyCard` |
| `.streamingCorrection(partial)` | Streaming correction in flight | `StreamingCorrectionCard` |
| `.correction(result)` | Result ready | `CorrectionCard` (diff + mistakes + style chip + actions) |
| `.message(NotchMessage)` | Errors / info / warnings | `MessageCard` (auto-hides 6s) |
| `.firstLaunch` | First launch only | `FirstLaunchCard` (auto-hides 4s) |
| `.review(payload)` | IdleCoach surfaces a due drill | `NotchReviewCard` |

`ExpandedRouter` switches on the case and renders the right card.
`locksHover` lives on each case — true for any state where a hover-out
shouldn't dismiss (correction, busy, streaming, review).

The screensaver-level panel can get displaced when an accessory app
activates / deactivates. `NotchPresenter.installActivationObservers`
re-asserts the panel front on `didBecomeActive` /
`didResignActive` / `didChangeScreenParameters`, gated to only fire
when the display is `.idle` so it doesn't fight in-progress animations.

## Streaming pipeline

OpenRouter speaks Server-Sent Events when you pass `stream: true`. The
flow:

1. `OpenRouterAdapter.correctStreaming(_:onPartialCorrection:)` opens
   `URLSession.bytes(for:)` and iterates `lines`.
2. Each `data: {...}` line is decoded into a `StreamChunk`; the
   `delta.content` fragment is appended to a running buffer.
3. The buffer is fed to `StreamingJSONFieldExtractor`. That's a tiny
   state machine that scans for `"corrected_text"\s*:\s*"` and then
   captures characters (with full JSON escape handling, including
   `\uXXXX`) until the unescaped closing `"`.
4. Each new partial is reported via the `@MainActor` callback. The
   `AppCoordinator` calls `NotchPresenter.updateStreaming(partial:)`
   which updates the model. SwiftUI re-renders just the partial text;
   the card identity is stable so no view tear-down.
5. On `data: [DONE]`, the full buffer is fed to a normal `JSONDecoder`
   to extract `mistakes` and produce the final `CorrectionResult`.

`AppCoordinator.currentCorrectionTask` is a handle to the in-flight
task; the streaming card's Cancel button calls
`cancelInflightCorrection()` which aborts the network read.

## Persistence

GRDB on a single `~/Library/Application Support/Vireo/vireo.sqlite`.

Tables (after v3):

```
session          id, timestamp, source_app, raw_text, corrected_text,
                 llm_provider, model, latency_ms, style_id

mistake          id, session_id (FK→session.id ON DELETE CASCADE),
                 original_phrase, fixed_phrase, category, rule, explanation

session_fts      FTS5 virtual table on (raw_text, corrected_text)
                 synced to `session` via triggers

weakness_item    id, category, rule, occurrence_count, first_seen, last_seen,
                 state (watching / active / mastered),
                 ease, interval_days, due_at, last_reviewed,
                 review_count, lapse_count
                 (UNIQUE index on (category, rule))
```

`SessionRepository` is an actor that wraps the queue. All UI reads go
through `SessionStore` (`@MainActor` `ObservableObject`), which pulls
recent sessions + category patterns + the weakness summary, and triggers
reloads after each save.

## Spaced-repetition coach

`WeaknessTracker.ingest(result:)` upserts a `(category, rule)` row for
every mistake. At occurrence count ≥ 3 the item is **promoted** from
`.watching` to `.active`, given an initial SM-2 state (ease 2.5,
interval 0d, dueAt now), and starts appearing in the review queue.

`SpacedRepetition.apply(grade:ease:intervalDays:lapses:)` is a pure
function:

| Grade | Effect |
|---|---|
| `.again` | Lapse++. Ease −0.2 (clamped ≥ 1.3). Interval reset to 1d. |
| `.hard` | Interval × 1.2. Ease −0.15. |
| `.good` | Interval × ease. |
| `.easy` | Interval × ease × 1.3. Ease +0.15 (clamped ≤ 3.0). |

At `intervalDays ≥ 30` an active item is demoted to `.mastered` (no
longer surfaces in reviews).

`ReviewSession` orchestrates a full review run; `NotchReviewCard` shows
one card at a time when `IdleCoach` decides to surface it
(idle ≥ 30s, has due item, not in setup state, hasn't shown in last 30
min, polled every 10s).

## Module dependency direction

```
                       App
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
    Capture          Coach            Notch
        │               │               │
        └───────┬───────┴───────┬───────┘
                ▼               ▼
           Persistence         LLM
                │               │
                └───────┬───────┘
                        ▼
                  DesignSystem (leaf)
```

`Permission`, `Intents`, `Diagnostics`, `UI/*`, `Utility` cross-cut
and depend only on what they need.

## Concurrency model

- `AppCoordinator`, `NotchPresenter`, `SettingsModel`, all view models:
  `@MainActor`. UI presentation hops through main.
- `SessionRepository`, `WeaknessTracker`: actors. Reads can interleave;
  writes serialize via GRDB's queue.
- Streaming adapter: `URLSession.shared.bytes(for:)` runs off-main; the
  partial callback is `@MainActor` so we never write to the model from
  outside main.
- CGEvent taps (double-shift): the C callback runs on a non-main
  thread; the inside dispatches to `MainActor.run` before touching any
  state.

## Why some things look funny

- **`UUID` constants for built-in styles** — built-ins are read-only;
  customs live in UserDefaults JSON. Stable UUIDs let the
  `activeStyleID` pointer survive across re-installs and code changes.
- **`originalText` and `styleID` on `CorrectionResult`** are `var`s
  with custom CodingKeys excluding them — adapters populate them
  post-decode so the LLM's JSON doesn't need to carry them.
- **`NotchPresenter.installActivationObservers` only re-asserts when
  `.idle`** — re-ordering the panel mid-animation makes hover flicker
  and re-fires haptic feedback. Discovered via user testing; do not
  remove the guard.
- **Per-file constants duplicated in `CoachEnglishIntent`** — the
  intent's `perform()` runs nonisolated. `SettingsModel` and
  `CorrectionStyleStore` are `@MainActor` and can't be touched from
  there; duplicating a thin slice (UserDefaults keys, default model
  name, style resolution) is the cleanest workaround.

## Pointer to the historical plan

[`docs/plan.md`](plan.md) is the original 6–8 week roadmap that
seeded the project. Most of phases 0–6 are now shipped; phase 7
(notarization, Sparkle wiring, Homebrew Cask, GitHub Actions CI) is
the remaining ship-readiness work.
