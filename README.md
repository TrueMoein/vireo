# Vireo

A notch-resident writing coach for macOS. Select English text anywhere,
hit a hotkey, and the notch slides down with a streamed correction — plus
a per-mistake breakdown if you want to learn the rule, not just get the fix.

> _"Grammarly fixes your text. Vireo teaches you to fix your text yourself."_

![Vireo correction card in the notch](docs/images/correction-card.png)

---

## What it does

- **Five ways to capture text**: ⌥⇧Space hotkey, hover button on selection,
  Right-Shift double-tap, clipboard auto-correct, and Apple Shortcuts /
  Siri via App Intents.
- **Streamed corrections**: text appears word-by-word in the notch as the
  model writes it, with a pulsing caret. No more staring at a spinner.
- **Inline word-diff**: see the original sentence with deletions struck
  through in coral and insertions in sage — context for what changed.
  Toggle to "just corrected" for a clean copy-paste view.
- **Correction styles**: eight built-in presets (Grammar Coach,
  Professional, Casual, Concise, Clarify, Friendly, Direct, Explainer)
  plus a full editor for your own custom system prompts.
- **Switch style on any correction**: chip menu on the correction card
  re-runs the same text through a different style with one click.
- **Ambient coaching**: recurring mistake patterns become spaced-
  repetition drills generated from your *actual* recent writing. When
  you're idle and a drill is due, the notch quietly surfaces one card.
- **Replace in place**: AX writeback for native apps (Notes, Mail, Pages,
  Xcode); pasteboard + ⌘V fallback for Electron / Chromium; pasteboard
  rewrite for clipboard-triggered corrections.
- **History + Patterns**: searchable past corrections via SQLite FTS5,
  category breakdowns of your weak spots.

---

## Installation

### Pre-built download (recommended)

Grab the latest `Vireo.app.zip` from the [Releases page](https://github.com/TrueMoein/vireo/releases), unzip, and drag `Vireo.app` into `/Applications`.

**First launch — bypass Gatekeeper once:**

Vireo is ad-hoc signed (no $99/yr Apple Developer ID), so the first time you open it macOS will refuse with *"Vireo can't be opened because Apple cannot check it for malicious software."* Once you allow it, macOS remembers.

- **macOS 15 (Sequoia) and newer:** double-click Vireo, dismiss the warning. Then go to **System Settings → Privacy & Security**, scroll to the *"Vireo was blocked…"* line, click **Open Anyway**. macOS will ask you to confirm one more time.
- **Older macOS:** right-click `Vireo.app` → **Open** → click **Open** in the dialog. Done.

Every subsequent launch is normal — no more warnings.

You can verify the binary matches the source by comparing `shasum -a 256 Vireo.app.zip` against the `Vireo.app.zip.sha256` attached to the same release.

### From source

If you have the toolchain installed:

```bash
git clone https://github.com/TrueMoein/vireo
cd vireo
bash scripts/run.sh
```

`scripts/run.sh` wraps the SPM build in a proper `Vireo.app` bundle (bundle ID `co.vireo`), copies the Sparkle framework + SPM resource bundles next to the binary, ad-hoc-signs the result, and opens it.

### Requirements

- macOS 26 (Tahoe) or later — Liquid Glass UI requires it.
- For source build: Xcode 17+ / Swift 6+.
- An [OpenRouter](https://openrouter.ai/keys) API key (any model with ≥30B parameters works well for grammar coaching; smaller models may produce unreliable structured output).

### First-launch onboarding

A 5-step wizard walks you through:

1. **Welcome** — animated mesh-gradient + serif tagline.
2. **API key** — paste your OpenRouter key (lands in macOS Keychain).
3. **Accessibility** — grant the AX permission. Vireo needs it to read
   selected text and write corrections back.
4. **Pick your style** — choose a default from 4 curated presets.
5. **Ready** — explains the hotkey + hover button.

Re-run the wizard any time from Settings → Access → "Re-run onboarding".

---

## Usage

### Hotkey (primary)

Select text anywhere. Hit **⌥⇧Space**. The notch expands with the
streamed correction. Click **Replace** to write it back to the source
app, **Copy** to put it on the clipboard, or **Dismiss**.

### Hover button (PopClip-style)

Select text in any AX-cooperative app (Notes, Mail, Discord, Chrome,
VS Code, etc.). A small Vireo silhouette blooms next to your cursor.
Click it → same flow as the hotkey.

### Right-Shift double-tap

Two presses of the Right-Shift key within 300 ms triggers a correction.
Same flow as the hotkey, but no chord required. Toggle in Settings →
Shortcuts.

### Clipboard auto-correct (opt-in)

Off by default. When enabled, Vireo polls the clipboard and auto-runs
the active style on sentence-shaped English copies (filtered through
`NLLanguageRecognizer`). Click Replace and the corrected text replaces
the clipboard so your next paste uses it. 10-second cooldown.

### Apple Shortcuts / Siri

`Correct text with Vireo` appears in Shortcuts.app once Vireo has been
launched at least once. Pass a String, receive the corrected version.
Honors the active style. Useful for chains like "OCR image → Vireo → email".

---

## Correction styles

Each style is a system prompt + an icon + a name. The JSON return
contract is appended automatically — you write the **intent**, Vireo
handles the schema.

### Built-ins

| Style | Use case |
|---|---|
| **Grammar Coach** (default) | Fix mistakes with per-mistake breakdown. |
| **Professional** | Formal/polite tone for emails to managers, clients. |
| **Casual** | Slack / Discord rhythm. Contractions welcome. |
| **Concise** | Strip wordiness without losing meaning. |
| **Clarify** | Reduce ambiguity while keeping tone. |
| **Friendly** | Warm, encouraging phrasing. |
| **Direct** | Lead with the ask, cut hedging. |
| **Explainer** | Restructure for code reviews / docs / tickets. |

### Custom

Settings → Styles → "New style from scratch" or duplicate any built-in.
You get a full editor with icon picker, name, subtitle, and a multi-line
system-prompt field. Vireo appends the JSON-return contract so the
model produces a Vireo-compatible response regardless of what you write.

---

## Settings

| Tab | What's there |
|---|---|
| **Provider** | OpenRouter API key, model picker (recommendations + custom), streaming toggle, "Test connection". |
| **Styles** | Active-style picker, list of all styles with per-row actions, "New style" button. |
| **Shortcuts** | Hotkey recorder, hover-button toggle, double-shift toggle, clipboard-monitor toggle, ambient-coach toggle. |
| **Access** | AX trust state + deep-link to System Settings, re-run onboarding. |
| **Diagnostics** | Live state of every subsystem (build, AX, capture surfaces, active style + model, database path). Screenshot it into bug reports. |

---

## Privacy

- Your OpenRouter key lives in **macOS Keychain**. It never leaves your
  machine except as the `Authorization` header on requests you make to
  OpenRouter's API.
- Selected text + corrections persist locally in
  `~/Library/Application Support/Vireo/vireo.sqlite`. No telemetry, no
  cloud sync, no analytics.
- Accessibility permission is used **only** to read currently-selected
  text and (on Replace) write corrections back via the AX API or the
  pasteboard. Vireo never reads arbitrary screen contents.

---

## Architecture in 30 seconds

```
[capture surface] ──► AppCoordinator ──► OpenRouterAdapter
        │                  │                      │
        │                  ▼                      ▼ (SSE streaming)
        │            CorrectionStyleStore    StreamingJSONFieldExtractor
        │                  │                      │
        │                  ▼                      ▼
        │            NotchPresenter ◄─────  CorrectionResult
        │                  │                      │
        ▼                  ▼                      ▼
   SelectedText      DynamicNotch panel    SessionRepository → SQLite
   Resolver         (state machine)        WeaknessTracker → SM-2 schedule
```

Full version: [`docs/architecture.md`](docs/architecture.md).

---

## Dependencies

| Package | Purpose |
|---|---|
| [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) | Notch panel overlay |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkey + recorder UI |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite + FTS5 + migrations |
| [Sparkle](https://sparkle-project.org/) | Auto-update (declared; not yet wired) |

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Bug reports, design feedback,
and pull requests welcome — issues with a screenshot of the Diagnostics
tab get triaged fastest.

## License

MIT. See [`LICENSE`](LICENSE).
