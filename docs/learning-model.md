# Learning model

How Vireo turns one-off corrections into long-term improvement.

## Weakness items, not flashcards

A traditional spaced-repetition app reviews flashcards. Vireo reviews
**weakness items** — tuples of `(category, rule)` like:

- `(article, "use 'the' before specific nouns")`
- `(preposition, "'at' for points in time, 'on' for dates")`
- `(l1_interference, "Persian has no articles — add 'a/the' before singular countables")`

Each weakness item carries its own FSRS state. The user doesn't see cards;
they see a 5-minute review session built from drills the LLM synthesizes from
their *actual* recent mistakes.

## Promotion + demotion

| Event | Effect |
|---|---|
| Same `(category, rule)` seen 3× in distinct sessions | Promote to active weakness item; enter FSRS queue |
| User produces the corrected form unprompted in real writing | Counts as `.easy` rating |
| User produces corrected form in a synthesized drill | `.good` rating |
| Needs a hint during drill | `.hard` rating |
| Makes the mistake again in real writing | `.again` rating |
| 30 correct uses in real writing | Demote to passive (out of active review) |

## FSRS-6

We use [`swift-fsrs`](https://github.com/open-spaced-repetition/swift-fsrs).
FSRS-6 produces ~25% fewer reviews than SM-2 for the same retention. We don't
tune parameters until we have ~200 weakness items of real history — FSRS's
defaults are a fine starting point.

## Synthesized drills

`ReviewSessionBuilder` collects the top N due weakness items, sends the
user's last 3-5 mistakes in each category to the configured "quality" model,
and asks it to generate fill-in-the-blank sentences structurally similar to
the real mistakes. Cached so reviews are offline-capable.

Cache key: `(weakness_item_id, recent_mistake_hashes)`. Invalidate when new
mistakes shift the structural pattern.

## What we don't do

- No streaks-as-pressure. The amber accent shows it; we don't gamify guilt.
- No daily-quota notifications. Reviews are *available*, not nagging.
- No leaderboards. This is private.
- No "level up." Mastery is binary per item: active or passive.
