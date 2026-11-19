# Decisions

What rarely changes: why the product exists, what it's built with, how we work. One line each;
when a decision changes, edit its line in place. No dated entries; git is the archive.

Precedence: **the human > `product-rules.md` > the code.**

Elsewhere: what must stay true → `product-rules.md` · rejected for good → `.out-of-scope/`.

## Product goals (never relitigate)

- A single-player mobile management game: restore a run-down guild hall and run its adventurers.
- For short, repeated sessions: collect returns, queue construction, re-dispatch, close the app.
- It must never become a town-builder: the guild hall is the play space, the town is backdrop.

## Current focus

Each milestone is the thinnest slice that makes the core loop more complete, is played locally in
the browser, then ends deployed. Later milestones get a `/to-spec` when they start.

- **M2 — Restore a room.** Done when Home shows the Ground floor top-down as room slots, two
  usable and the rest damaged; tapping a damaged slot spends gold to restore it on a timer (one
  builder, so one restoration at a time); the slot then shows restored, also when it finished while
  the app was closed. Restored rooms have no type yet (that is M5's convert).
- **M3 — Send a party.** Done when a bottom bar switches Hall | Quests; the quest board lists three
  fixed quests (duration, gold reward); the guild's one party (no individuals yet) goes on one
  quest at a time and its gold lands when the timer ends, also while closed. Quests replace M1's
  passive gold drip: gold now comes only from quests.
- **M4 — Adventurers.** Done when a Roster tab lists four starting adventurers (name, class, rank
  F, power) with status; dispatch picks 1–3 idle ones and shows a success chance from party power
  vs quest difficulty; the outcome is fixed at dispatch from a saved seed; success pays in full,
  failure pays a quarter and injures one member for a while. Still one quest out at a time.
- **M5 — Rooms with jobs.** Done when a restored empty room can be converted (gold + timer, uses
  the builder, unusable meanwhile) into a Quest hall (+1 quest out at a time) or an Infirmary
  (injuries heal twice as fast), and the effect applies.
- Done: M0 runs on my phone (Pages + APK per push, failing test blocks deploy) · M1 gold while
  you're away (1 gold/s, away message after more than 30 s).

## Stack

- Godot 4.7.1 (standard build) with typed GDScript. Not C#: Godot can't export C# to the web.
- Tests: GUT, run headless in CI.
- CI/CD: GitHub Actions. Web export (single-threaded, so GitHub Pages works without special headers)
  → GitHub Pages; Android debug APK as a workflow artifact. iOS later: needs a Mac and an Apple
  developer account.
- Hall view: roof-off top-down view of one floor, seen from high at the front. It replaces the
  spec's isometric view. `assets/concept/guildhall.png` shows the camera angle only; everything
  else about the hall follows the spec.
- Hall art: placeholders drawn by Claude for now, one image file per slot per state, so real art
  replaces a file without code changes.

## Working rules

- A milestone reaches `main` only after the human has played it locally in the browser and said so.
- Report the criterion that fails; never tune a number until it passes.
- A target that failed three times gets questioned, not attempted again.
- A finding is not a scope extension: it is one line to the human when the feature closes, filed in
  their tracker or dropped.

## Open — needs the human

- Nothing open.
