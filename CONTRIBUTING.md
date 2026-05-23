# Contributing to Vireo

Thanks for considering a contribution.

## Code of conduct

Be kind. Be specific. No personal attacks.

## Filing an issue

1. Search existing issues first.
2. Include macOS version, Vireo version, and reproducible steps.
3. For UI/visual issues, include a screenshot or short screen recording.
4. For capture-flow issues, include the output of Vireo → Diagnostics
   (menubar → Diagnostics) — it captures AX status, hotkey state, last
   capture, and last LLM call.

## Pull requests

1. Fork, branch off `main`.
2. `swift build` and `swift test` must pass before pushing.
3. Keep PRs focused — one logical change per PR.
4. Reference the issue you're fixing in the description.
5. PRs that change behaviour need a brief test plan.

## Code style

- SwiftFormat default rules.
- Prefer `struct` over `class` unless reference semantics are needed.
- Mark types `Sendable` where structurally possible.
- One file per top-level type; small helpers can live inline.
- No third-party fonts. Use SF Pro / New York / SF Mono only.

## Adding an LLM provider

See [`docs/llm-providers.md`](docs/llm-providers.md).

## Changing the design system

The palette, typography, motion presets, and material rules in
`Sources/Vireo/DesignSystem/` are intentionally limited. Read
[`docs/design-system.md`](docs/design-system.md) before proposing changes — the
constraints are part of the product.
