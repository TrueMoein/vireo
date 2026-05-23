# Architecture

High-level: see [`plan.md`](plan.md). This file expands on areas the plan
treats briefly.

## Activation surfaces

Four capture surfaces, all feeding `AppCoordinator`:

| Surface | Module | Trigger |
|---|---|---|
| Hover button (primary) | `Capture/SelectionObserver` + `Capture/HoverButtonWindow` | `kAXSelectedTextChangedNotification` in any app |
| Double Right-Shift (secondary) | `Capture/ShiftDoubleTapMonitor` | Two Right-Shift presses within 300 ms |
| Filtered clipboard (tertiary) | `Capture/ClipboardMonitor` | Cmd+C of a sentence-shaped English string |
| Recall hotkey (power user) | `KeyboardShortcuts` integration | User-configured chord, default `⌥⇧Space` |

Each surface produces a `CapturedText` event with: text, source app bundle id,
caret/window position (for placement), trigger type. `AppCoordinator` owns the
pipeline from there: resolve → LLM → present in notch.

## Pipeline (capture → present)

```
Capture surface
      │
      ▼
SelectedTextResolver  (AX fast-path → Cmd+C fallback)
      │
      ▼
AppCoordinator        (rate-limit, dedupe, cache hit?)
      │
      ▼
ProviderManager       (route to fast vs quality model)
      │
      ▼
ProviderAdapter       (Anthropic tool-use / OpenAI strict JSON)
      │
      ▼
CorrectionResult      (Codable, source of truth)
      │
      ├──▶ Persistence  (write Session + Mistakes + update WeaknessTracker)
      │
      └──▶ NotchPresenter  (pill ↔ card morph)
```

## Concurrency model

- `AppCoordinator` is `@MainActor` — UI presentation must hop through main.
- LLM calls use `async/await` off-main via `URLSession`.
- `Database` exposes a `DatabasePool` (GRDB) with all writes inside
  transactions; reads can be concurrent.
- `SelectionObserver` runs on a serial DispatchQueue dedicated to AX events;
  posts back to main with `MainActor.run { … }`.

## Module dependency direction

```
            App
             │
   ┌─────────┼─────────┐
   ▼         ▼         ▼
Capture   Coach     Notch
   │         │         │
   ▼         ▼         ▼
        Persistence
             │
             ▼
     DesignSystem (leaf)
```

`LLM` is a leaf alongside `DesignSystem`. `Permission`, `Intents`, and
`Diagnostics` cross-cut and depend only on what they need.

## More to come

This document expands as phases land. For now, the plan is the source of truth.
