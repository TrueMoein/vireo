# Vireo

A notch-resident English coach for macOS that helps non-native speakers learn
from their actual writing — not just have it fixed.

## What it does

Select an English sentence anywhere on your Mac (Discord, Slack, browser,
notes), and a small Vireo silhouette button blooms next to your cursor. Tap
it, and the notch slides down with:

- the corrected sentence in New York serif
- a per-mistake breakdown — category, rule, brief explanation
- `[Replace]` to paste back, `[Copy]`, or `[Save & Learn]` to flag for
  spaced-repetition review

Every correction quietly trains a personal weakness profile. Recurring
mistakes become 5-minute review drills synthesized from your *actual* recent
sentences — not generic textbook ones. Over time you stop making the same
mistakes.

The difference from Grammarly / "paste into ChatGPT": you *learn*. Vireo
explains the rule, tracks the pattern, and surfaces it for review until you
genuinely have it.

## Status

**Pre-alpha (Phase 0 scaffolding).** See [`docs/plan.md`](docs/plan.md) for the
6–8 week roadmap.

## Requirements

- macOS 26 (Tahoe) or later — Liquid Glass UI requires it
- Xcode 17+ / Swift 6+
- An Anthropic and/or OpenAI API key (your own; stored in Keychain)
- Apple Developer ID for code-signing (only needed for distribution, not local development)

## Development setup

```bash
git clone https://github.com/<you>/vireo
cd vireo
swift package resolve
swift build
```

For the menubar + notch app to run with the right entitlements (Accessibility,
hardened runtime, signing), open in Xcode:

```bash
open Package.swift   # opens as a Swift Package in Xcode
```

Then Product → Run (`⌘R`). On first launch Vireo walks you through granting
Accessibility permission (required for the hover-button capture surface).

## Architecture (one paragraph)

`AppCoordinator` is the single activation surface. Four capture surfaces
(hover button on selection, double-tap Right-Shift, filtered clipboard
monitor, recall hotkey) call into it. It resolves the selected text, hands
it to the configured `ProviderAdapter` (Anthropic or OpenAI, more pluggable),
decodes the structured response into `CorrectionResult`, and asks
`NotchPresenter` to show it. Every mistake is logged to GRDB with FTS5
indexing. Recurring `(category, rule)` patterns become `WeaknessItem`s on the
`swift-fsrs` review schedule. See [`docs/architecture.md`](docs/architecture.md)
for the full picture.

## Key dependencies

- [`DynamicNotchKit`](https://github.com/MrKai77/DynamicNotchKit) — notch overlay
- [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) — global hotkey + recorder UI
- [`GRDB.swift`](https://github.com/groue/GRDB.swift) — persistence + FTS5
- [`swift-fsrs`](https://github.com/open-spaced-repetition/swift-fsrs) — spaced-repetition algorithm
- [`Sparkle 2`](https://sparkle-project.org/) — auto-updates

## License

MIT. See [`LICENSE`](LICENSE).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Bug reports, design feedback, and
pull requests welcome.
