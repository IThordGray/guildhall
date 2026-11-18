# Code rules — Guildhall

Stack rules for this repo. The universal *Do less* principles live in Shipyard's
`rules/code.md`; each rule here names the principle it serves ([P1]–[P10]). **Grows only by
pattern.** Where this file and Shipyard's rules disagree, this file wins.

## Godot / GDScript

- [P5] Game rules (timers, costs, rates, outcomes) live in plain GDScript classes that take `now`
  as an argument and need no scene tree. Scenes read them and render; they hold no rules.
- [P3] Nothing runs per frame that can run on change: UI updates on signals; `_process` only for
  what visibly animates, such as a countdown on screen.
- [P9] Static typing everywhere (`var gold: int`, typed returns).
