# Design system

Locked decisions. See [`plan.md`](plan.md) for full reasoning.

## Palette

Custom, not `Color.red` / `Color.green`.

| Token | Light | Dark | Use |
|---|---|---|---|
| `mistake` | `#D97757` | `#D97757` | Strikethrough on changed tokens, error states. Calmest "wrong" on display. |
| `correction` | `#7BA889` | `#A8C9B0` | Edited tokens in the corrected sentence, success states. |
| `surface` | `#F4F1EC` | `#1C1B19` | Paper-warm card backgrounds, hero surfaces. |
| `accent` | `#C99846` | `#E8B36A` | Streak/progress, calls to action. Dusty amber, never yellow. |

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

- **First-launch wow**: notch expands, `MeshGradient` animates, sentence types
  itself in New York serif: *"I'll quietly fix your English."* Collapses. No
  buttons.
- **Correction reveal**: `ConcentricRectangle` morphs from device-corner
  curvature into a card; content fades with `.blurReplace` at `delay: 0.15`
  while the frame is still expanding.
- **Progress view**: 14-day horizontal stacked bar of error categories. Tap a
  day → bar morphs via `matchedGeometryEffect` into the day's actual mistake
  sentences.
