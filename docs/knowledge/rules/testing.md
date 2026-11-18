# Testing rules — Guildhall

Setup and stack rules for this repo. The universal testing rules live in Shipyard's
`rules/testing.md`. **Grows only by pattern.** Where they disagree, this file wins.

## Setup

- Run the test command in `CLAUDE.md` before every commit; the web export must succeed too.
- Tests live in `test/`, named after the rule class they cover: `gold_rate.gd` → `test/test_gold_rate.gd`.
- No snapshot tests. No coverage target.

## Godot

- Test game rules directly, with `now` passed in: "after 3600 s away, gold is 360". Never sleep or
  wait on real timers.
- Save/load gets a round-trip test: save, load into a fresh state, same values.
- Screens are checked by hand on a phone at the end of each milestone, not by UI tests.
