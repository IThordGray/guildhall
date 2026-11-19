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

- **Now, in order:**
  - M8 debriefs: a returned party waits for a debrief (count on the Quests tab, list, debrief
    screen). Fills the return-summary hook.
  - M9 health and levels: damage that heals over time, XP, the Level up screen, four stats
    behind power.
  - M10 challenges and ranks: quest ranks and challenges, class coverage, the forecast as a range.
  - M11 gear and loot: eight slots, the stash, loot from quests, layered sprites.
  - M12 landscape: every screen in both orientations.
- **Later, not planned yet:** the spec's starting state and extending the hall, recruitment,
  guild level, Quest hall extras, the labyrinth.
- Screens follow the v2 designs (linked from the spec).
- Done: M0 runs on my phone (Pages + APK per push, failing test blocks deploy) · M1 gold while
  you're away (drip later replaced by quests; away message removed, its hook kept) · M2 restore
  a room · M3 send a party · M4 adventurers (4 starters, seeded outcomes, injuries) · M5 rooms
  with jobs (Quest hall, Infirmary) · M6 send everyone ready (daily board, no cap on parties out,
  parties of up to 4) · M7 the v2 look (dark theme, four tabs, Hall as a floor plan with an
  In progress list). M2 onwards are on local `main`, not pushed.

## Stack

- Godot 4.7.1 (standard build) with typed GDScript. Not C#: Godot can't export C# to the web.
- Tests: GUT, run headless in CI.
- CI/CD: GitHub Actions. Web export (single-threaded, so GitHub Pages works without special headers)
  → GitHub Pages; Android debug APK as a workflow artifact. iOS later: needs a Mac and an Apple
  developer account.
- Hall view: roof-off top-down view of one floor, seen from high at the front. It replaces the
  spec's isometric view. `assets/concept/guildhall.png` shows the camera angle only; everything
  else about the hall follows the spec.
- Hall view for now: a drawn floor plan (v2 designs), room state shown by fill; no room pictures.
  The concept-art look stays the later target.

## Working rules

- A milestone reaches `main` only after the human has played it locally in the browser and said so.
- Report the criterion that fails; never tune a number until it passes.
- A target that failed three times gets questioned, not attempted again.
- A finding is not a scope extension: it is one line to the human when the feature closes, filed in
  their tracker or dropped.

## Open — needs the human

- Guild level and Quest hall extras: open questions in the spec.
