# Design system

Locked decisions. See [`plan.md`](plan.md) for original reasoning;
this doc is the source of truth for what's actually in the code today.

## Palette

Custom tokens, not `Color.red` / `Color.green`. All defined in
`Sources/Vireo/DesignSystem/Palette.swift` as `Color.Vireo.*`.

| Token | Approx hex | Use |
|---|---|---|
| `mistake` | `#D97757` | Strikethrough on deleted tokens in the diff, error tones in messages. |
| `correction` | `#7BA889` | Edited tokens in the corrected sentence, success states, active style chip, sage tints throughout. |
| `correctionHighlight` | `#A8C9B0` | Lighter sage for emphasized insertions or "Easy" rating chips. |
| `surfaceLight` | `#F4F1EC` | Paper-warm card background, light-mode mesh-gradient seeds. |
| `surfaceDark` | `#1C1B19` | Paper-dark card background, dark-mode mesh-gradient seeds. |
| `accent` | `#C99846` | "Due now" count in the coach card. Dusty amber. Reserved for progress + attention. |
| `warning` | `#D98C33` | Setup-needed pills, "Vireo isn't running from a bundle" tone, AX-not-granted state. |
| `info` | `#5C8CC8` | Non-urgent notch info messages. |

Avoid pure white/black, Duolingo green, system reds at large sizes.

## Typography

| Role | Font | Weight |
|---|---|---|
| Body / chrome | SF Pro Text + Display | Regular / Medium |
| **Corrected sentence** (signature) | **New York serif** | Semibold |
| Inline diff tokens | SF Mono | Regular |
| Stats / streak counters | SF Pro Rounded | Semibold |

No third-party fonts. Use `.font(.system(size:weight:design:))` and let
optical sizing do its job — don't manually mix Display vs Text.

## Motion

| Token | Value |
|---|---|
| Entry | `.smooth(duration: 0.35, extraBounce: 0.15)` |
| Dismiss | `.snappy(duration: 0.20)` |
| Notch expand | `.spring(response: 0.50, dampingFraction: 0.70)` |
| Notch collapse | `.spring(response: 0.35, dampingFraction: 0.85)` |
| Stagger | `delay(Double(i) * 0.04)`, cap at 5 items |
| Signature transition | `.blurReplace.combined(with: .scale(0.97))` |

**Forbidden**: `.easeInOut` (reads dated), simultaneous opacity+scale on
content (pick scale, 0.92 → 1.0), continuous breathing/pulsing without a
loading reason.

## Materials

| Surface | Effect |
|---|---|
| Notch outer panel | `.glassEffect(.regular)` inside one `GlassEffectContainer` |
| Inner correction card | `.glassEffect(.clear.tint(palette.surface.opacity(0.4)))` |
| Transient HUDs | `.ultraThinMaterial` |
| MenuBarExtra | `NSVisualEffectView` bridge for system parity |

Wrap multi-surface notch UI in one `GlassEffectContainer` so highlights bend
coherently.

## Signature moments

- **First-launch onboarding**: 5-step wizard. The welcome step has an
  animated `MeshGradient` backdrop driven by `meshT` and a typing-in
  serif tagline ("Hi. I'm Vireo. I'll help you learn English from your
  own writing.") that types out at ~28ms per character. The style
  picker step uses the same sage chrome as the active correction card.
- **Streaming correction**: the notch slides into
  `StreamingCorrectionCard` with the corrected text appearing
  character-by-character (driven by the SSE parser surfacing partials),
  plus a pulsing serif caret (`▍`) that opacity-cycles `0.25 ↔ 1.0`
  every 0.6s.
- **Correction reveal → diff**: when the full result arrives, the card
  transitions via `.blurReplace.combined(with: .scale(0.96))` into
  `CorrectionCard`. The sentence renders as a word-diff:
  `SentenceDiff.render` produces an `AttributedString` with coral
  strikethrough on deletions and sage bold on insertions, inline in
  the original sentence.
- **Style chip flip**: clicking the style chip on the correction card
  opens a `Menu` of all styles; picking a different one re-uses the
  same card identity (stable `displayKey` for streaming, fresh
  `.correction(result)` after) so the transition feels like a switch,
  not a reload.

## Reference: what's where in code

| Concern | File |
|---|---|
| Palette tokens | `Sources/Vireo/DesignSystem/Palette.swift` |
| Type roles | `Sources/Vireo/DesignSystem/Typography.swift` |
| Motion presets (`.Vireo.entry`, `.Vireo.snappy`, `.Vireo.microInteraction`) | `Sources/Vireo/DesignSystem/Motion.swift` |
| Glass material helper (`.vireoGlassCard(cornerRadius:)`) | `Sources/Vireo/DesignSystem/Materials.swift` |
