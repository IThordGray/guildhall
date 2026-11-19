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

- **Next:** on hold while the human settles the spec's open questions (guild level, Quest hall
  extras, quest difficulty shown or hidden). The build stays as it is until then.
- Dispatch is limited only by ready adventurers: no slots. The board holds a fixed number of
  quests a day; a Quest hall raises it. The prototype's slot rule goes when the build resumes.
- Screens follow the v2 designs (linked from the spec): plain dark UI, four tabs (Hall, Quests,
  Roster, Labyrinth), debriefs instead of a returns pop-up. Portrait and landscape are both in;
  the build is portrait-only so far.
- Done: M0 runs on my phone (Pages + APK per push, failing test blocks deploy) · M1 gold while
  you're away (drip later replaced by quests; away message removed, its hook kept) · M2 restore
  a room · M3 send a party · M4 adventurers (4 starters, seeded outcomes, injuries) · M5 rooms
  with jobs (Quest hall, Infirmary).

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

- Guild level, Quest hall extras, and whether quest difficulty is shown: open questions in the spec.
