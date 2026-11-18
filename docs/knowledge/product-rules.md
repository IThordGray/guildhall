# Product rules

What must stay true, whatever the code looks like. Only rules a reader couldn't work out from the
code, or could break without noticing. **Where the code and a rule disagree, the code is wrong.**

A change that adds or changes a rule says so in its spec or brief; the manager edits this file when
it merges. Screens and wording live in the code.

## Time

- Progress runs on wall-clock time, open or closed: an hour away gives the same result as an hour
  watching.
- Every timer and outcome is computed from saved state and timestamps, never accumulated frame by
  frame, so a server could recompute it later.
- A device clock set backwards never removes progress.

## Screen

- Portrait 9:16. A top bar shows resources.
