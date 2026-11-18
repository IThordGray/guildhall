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

Each milestone is the thinnest slice that makes the core loop more complete, ends deployed, and is
checked by hand on a phone. Later milestones get a `/to-spec` when they start.

- **M1 — Gold while you're away.** Done when the top bar shows gold rising at a fixed rate, and
  reopening after N minutes says "While you were away: +X gold" with X exact; the save survives a
  reload on web.
- **Next:** M2 restore a room · M3 send a party · M4 adventurers · M5 rooms with jobs
- Done: M0 runs on my phone (Pages + APK per push, failing test blocks deploy).

## Stack

- Godot 4.7.1 (standard build) with typed GDScript. Not C#: Godot can't export C# to the web.
- Tests: GUT, run headless in CI.
- CI/CD: GitHub Actions. Web export (single-threaded, so GitHub Pages works without special headers)
  → GitHub Pages; Android debug APK as a workflow artifact. iOS later: needs a Mac and an Apple
  developer account.
- Hall view: roof-off top-down view of one floor, seen from high at the front. It replaces the
  spec's isometric view. `assets/concept/guildhall.png` shows the camera angle only; everything
  else about the hall follows the spec.

## Working rules

- Report the criterion that fails; never tune a number until it passes.
- A target that failed three times gets questioned, not attempted again.
- A finding is not a scope extension: it is one line to the human when the feature closes, filed in
  their tracker or dropped.

## Open — needs the human

- Hall art for M2: the hall with no UI, plus a damaged and a restored image per starting room. Who
  makes it?
