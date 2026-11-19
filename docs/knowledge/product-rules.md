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

- Portrait 9:16 and landscape. A top bar shows gold and how many parties are out.

## Quests

- How many parties are out is limited only by ready adventurers. A party has 1–4 members.
- The board holds a fixed number of quests per local day. A quest sent is used until the next day,
  whatever its outcome.
- A party's chance of success and each member's health are fixed when it leaves; nothing done
  while it is out changes how the quest ends. Nobody heals while out.
