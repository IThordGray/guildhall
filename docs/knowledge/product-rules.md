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

- Portrait 9:16 and landscape, picked by the window's shape. Gold and how many parties are out are
  always on screen: in portrait in the top bar, in landscape in the left rail and screen headers.
- No dialogs or overlay panels: everything opens as a full screen with Back (the landscape party
  picker docks beside the board). The one exception: an action that spends (restore, extend) or lets an
  adventurer go (dismiss, swap) confirms in a small centred card showing only its cost and time, or
  what leaves with them, with Cancel and the action. Any scroll scrolls by dragging anywhere on it, and a control fires
  only on a tap that stayed within about 10 dp; a press that turns into a drag never fires. A card
  with only one action does it from a tap anywhere on it.
- A list of slots shows what can be acted on first, then at most one line for the soonest refill.
- A button shows only when its action applies (Train, Promote from the level the rank needs).

## Roster

- The roster never holds more adventurers than the guild has beds. A hire is refused with nothing
  changed when gold is short or every bed is taken.
- Walk-ins arrive one at a time, a hidden 3–7 minutes apart, from saved timestamps and seeds only;
  each waits until the next arrives. Accepting is free and needs a bed; with every bed taken, a
  walk-in can be swapped for a current adventurer. Dismissing returns gear to the stash where it
  fits; nobody out, training or waiting on a debrief, and never the last adventurer, can go.
- Candidate slots refill from saved timestamps only, like the quest board: being away gives the same
  candidates as watching.
- Taverns and training fill from saved timestamps only, up to their cap. Gold held changes only by
  rewards (paid when their debrief is read), spending and collecting.

## Hall

- The guild has a rank, F to S. A new game is rank F: one floor (Reception in order, a side room
  and a backroom damaged), Bram and Tobin, and what the Reception gives (2 beds, 1 candidate slot,
  2 board slots, a stash of 6). A room type or Extend above the guild's rank is refused. Saves from
  before ranks keep their rooms, roster, stash and capacities.
- Hall rooms show their name, their fill, faint furniture and one icon for what can be done; no
  status text and no adventurer faces. Unbuilt parts of the building are not drawn.
- Each room type is built at most once; more of one will come from upgrading it, not a copy. Old
  saves keep any copies they have.

## Quests

- How many parties are out is limited only by ready adventurers. A party has 1–4 members.
- The board has a fixed number of slots. Sending a quest empties its slot, which refills after its
  own countdown with a quest not on the board and not out, whatever the outcome. Refills depend only
  on saved timestamps, so being away gives the same board as watching.
- The board offers only quests at most one rank above the guild's highest-ranked adventurer, and
  only of the guild's rank or one either side, weighted toward the guild's own (R−1 10%, R 70%,
  R+1 20%). A player action that changes a rank brings the board up to date first.
- A party's chance of success and each member's health are fixed when it leaves; nothing done
  while it is out changes how the quest ends. Nobody heals while out.
- A returning party's damage, injuries, healing and XP count from its return, so members can level
  up from the debrief; its gold and loot are paid, and its members free for new quests, only when
  its debrief is read. A debrief pays once.
- A quest's XP is the party's total: each member gains the total ÷ party size, rounded down, but at least 1. A
  failed quest pays no gold and a quarter of the XP, at least 1.
- Anyone can be anything: there are no classes. A challenge tests the party's weighted stats, gear
  included, and a quest's chance averages its challenges with the weakest counted twice. Gear
  shapes growth: the stats worn items add grow faster. A title comes from the two highest stats.
- Spirit and Luck help the whole party: Spirit cuts everyone's damage; Luck brings more and better
  loot, softens a failure and may give a lucky break (the weakest challenge counts as just met),
  all fixed at send. What Luck does is never explained on screen; a lucky break shows in its debrief.
- Every recruit arrives wearing at least a weapon.
- The picker shows the chance as a range: ±10 around what the known challenges give, an unknown
  challenge counted as an even match and a lucky break left out. Until every challenge is known the
  real chance may lie outside it.
- The guild learns its quests: every party back from a quest, whatever the outcome, adds 1 point to
  that quest's chance, up to +15. It counts in the chance shown and is fixed when a party leaves.
