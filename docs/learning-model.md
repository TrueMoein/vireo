# Learning model

How Vireo turns one-off corrections into long-term improvement.

## Weakness items, not flashcards

A traditional spaced-repetition app reviews flashcards. Vireo reviews
**weakness items** — tuples of `(category, rule)` like:

- `(article, "Use 'the' before specific nouns")`
- `(preposition, "'at' for points in time, 'on' for dates")`
- `(agreement, "Third-person singular present takes -s")`

Each weakness item carries its own scheduler state (ease, interval, due
date, lapses). The user doesn't see flashcards; they see a 5-minute
review session built from **fresh fill-in-the-blank drills** the LLM
synthesizes from their actual recent mistakes.

Source files:
- `Sources/Vireo/Persistence/Models/WeaknessItem.swift` — schema (state
  enum: `.watching`, `.active`, `.mastered`).
- `Sources/Vireo/Coach/WeaknessTracker.swift` — ingest + rate logic.
- `Sources/Vireo/Coach/SpacedRepetition.swift` — pure SM-2 scheduler.
- `Sources/Vireo/Coach/ReviewSession.swift` — full review-run state
  machine.
- `Sources/Vireo/Coach/IdleCoach.swift` — ambient surfacing policy.
- `Sources/Vireo/Coach/DrillGenerator.swift` — LLM-synthesized
  fill-in-the-blank sentences.

## Ingestion + promotion

Every time a correction comes back from the LLM, `WeaknessTracker.ingest`
walks the mistakes and upserts a `weakness_item` row keyed on
`(category, rule)`:

1. If the row doesn't exist: insert one in state `.watching` with
   `occurrence_count = 1`.
2. If it exists: increment `occurrence_count`, update `last_seen`.
3. If the row was `.watching` and `occurrence_count` just crossed
   `WeaknessItem.promotionThreshold` (3): promote to `.active`,
   initialize the SM-2 state via
   `SpacedRepetition.initialState(now:)` — `ease = 2.5`,
   `intervalDays = 0`, `dueAt = now` (so the user can review it
   immediately if they want).

Promotion fires inside the same transaction as the upsert, so the
SessionStore's reload picks up the new active count atomically.

## SM-2 scheduler

We use a hand-rolled SM-2 variant instead of `swift-fsrs` — the FSRS
library's scheduling methods are internal-scoped in the public release
we depend on, so we can't call them from outside the module. SM-2 with
sensible defaults works well enough at our scale. Source:
`Sources/Vireo/Coach/SpacedRepetition.swift`.

```swift
SpacedRepetition.apply(grade:, ease:, intervalDays:, lapses:, now:)
  → (ease, intervalDays, dueAt, lapses)
```

The four ratings:

| Grade | Effect on ease | Effect on interval | Lapse count |
|---|---|---|---|
| `.again` (forgot) | −0.20 (floor 1.30) | Reset to 1 day | +1 |
| `.hard` (struggled) | −0.15 (floor 1.30) | × 1.2 | unchanged |
| `.good` (got it) | unchanged | × ease | unchanged |
| `.easy` (instant) | +0.15 (cap 3.00) | × ease × 1.3 | unchanged |

The ease factor stays clamped to `[1.30, 3.00]` so a single rough run
can't trap an item in unreviewable territory.

## Mastery threshold

When `WeaknessTracker.rate` runs and the new `intervalDays ≥ 30`,
the item is demoted from `.active` to `.mastered`. Mastered items no
longer appear in the active review queue but still exist for History /
Patterns purposes.

30 days is the SM-2/Anki convention for "out of the daily-review tail."
Mastered counts surface in the Patterns view so the user sees their
graduates.

## Synthesized drills

`DrillGenerator` is the only learning-model component that calls the
LLM. For each due weakness item, it sends:

- The rule (one short sentence)
- Optionally, the most recent real mistake illustrating it

…and asks for a one-shot JSON object: `{blank, answer, context}`. The
blank is a sentence with three underscores marking where the answer
fills in; the answer is the exact text that fills it; the context is a
≤15-word explanation of *why* that answer is correct.

Drills are cached in memory keyed by weakness-item ID — re-opening a
review doesn't burn API calls. The cache is per-session (not
persisted); a fresh app launch generates a fresh drill so the user
doesn't see the same sentence twice in a row.

## Two surfaces for review

**Main-window review session** (`UI/Main/ReviewSessionView.swift`):
A dedicated sheet you open from the popover "Review" button. Shows
"X of Y" progress, the full drill card per item, four rating buttons
(Again / Hard / Good / Easy), a typed-answer field with `⌘↩` to
check, and a completion summary tallying your ratings.

**Notch-resident drill** (`Notch/NotchReviewCard.swift`):
When `IdleCoach` decides to surface a drill (default policy: user idle
≥ 30s, at least one item due, notch state is idle, not shown in the
last 30 min, API key present), it slides one drill card into the notch
with the same reveal-then-rate flow. After the rating, the notch
dismisses. The IdleCoach is throttled to never feel naggy.

Toggle the ambient coach in Settings → Shortcuts → Ambient coach. A
"Show a drill in the notch" button is right next to it for testing.

## What we don't do

- No streaks-as-pressure. We track lapse counts but never surface them
  as guilt.
- No daily-quota notifications. Reviews are *available*, not nagging.
- No leaderboards. This is private, local-first.
- No level / XP system. Mastery is per-item, not a global score.
- No FSRS yet — when `swift-fsrs` exposes its public scheduling API
  (or we vendor the algorithm directly), we'll swap. The interface
  in `SpacedRepetition` is intentionally small so the upgrade is
  one file.
