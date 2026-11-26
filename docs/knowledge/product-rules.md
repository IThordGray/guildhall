# Product rules

What must stay true, whatever the code looks like. Only rules a reader couldn't work out from the
code, or could break without noticing. **Where the code and a rule disagree, the code is wrong.**

A change that adds or changes a rule says so in its spec or brief; the manager edits this file when
it merges. Screens and wording live in the code.

## Time

- Progress runs on wall-clock time, open or closed. Up to 3 hours away gives the same result as
  watching. A longer absence settles everything before its last 3 hours at once: parties out come
  home, each Auto party earns the expected gold, XP, reputation, tries and loot of the quests the board would
  offer it and its mode takes (loot stops it when the stash is full, as a return would), everyone
  ends that part home and healed with no level-ups, and the board is drawn fresh from saved state.
  The last 3 hours then play out as watching.
- Every timer and outcome is computed from saved state and timestamps, never accumulated frame by
  frame, so a server could recompute it later.
- A device clock set backwards never removes progress.

## Screen

- Portrait 9:16 and landscape, picked by the window's shape. Gold and how many parties are out are
  always on screen: in portrait in the top bar, in landscape in the left rail and screen headers.
- No dialogs or overlay panels: everything opens as a full screen with Back (in landscape the party
  picker docks beside the board or the labyrinth's floors, and the chosen adventurer beside the roster list). Gear changes in
  place on the Adventurer screen: tapping a slot or a stash item swaps the stash strip (in landscape
  the left column) for that slot's tray; nothing slides over the screen. The one exception: an action that spends (restore, upgrade, extend, rank up), lets an
  adventurer go (dismiss, swap) or gives up an item (sell, swap loot in, let loot go) confirms in a small centred
  card showing only its cost and time, what leaves, or the gold it brings, with Cancel and the action. Any scroll scrolls by dragging anywhere on it, and a control fires
  only on a tap that stayed within about 10 dp; a press that turns into a drag never fires. A card
  with only one action does it from a tap anywhere on it; a candidate's or the walk-in's card opens
  their sheet instead, and only its buttons act.
- A list of slots shows what can be acted on first, and at most one line for the soonest refill.
- A button shows only when its action applies (Train, Promote once earned, Rank up once its requirements are met).

## Roster

- Adventurers quest in parties of 1–4; an adventurer is in at most one party, and anyone in none
  is a reserve. Reserves can't go on quests; they can train, change gear, level up, be promoted and
  be dismissed. New hires and walk-ins join the reserves. A party whose last member leaves is gone.
- Moving someone between parties or the reserves needs them and everyone in both parties home.
- A party's name is drawn as "The <Adjective> <Noun>" from a saved seed; the dice draws another and
  the player can type over it (blank keeps the old name, at most 24 characters).
- A party's rank is its members' ranks averaged, rounded down (F=0 … S=6).
- Promotion is earned and free: rank E after 5 successful rank-E quests at level 3 or higher, rank
  D after 5 successful rank-D quests at level 6 or higher; the player presses Promote, never
  automatic, and not while out. Each member counts the quests they succeeded on by rank (averaged
  absences count their expected successes, rounded down). A promotion raises the adventurer's two
  highest stats by 1, shown like a level-up. The Adventurer screen shows progress towards the
  next promotion.
- A save from before parties groups its adventurers into parties of up to 4 in roster order.
- The roster never holds more adventurers than the guild has beds. A hire is refused with nothing
  changed when gold is short or every bed is taken.
- Walk-ins arrive one at a time, the first a hidden 3–7 minutes into a game and each later one a
  hidden 20–28 hours after the one before (12–16 hours once the guild has reached rank E), from saved timestamps and seeds only; each waits until
  the next arrives. Accepting is free and needs a bed; with every bed taken, a
  walk-in can be swapped for a current adventurer. Dismissing returns gear to the stash where it
  fits; nobody out, training or waiting on loot to be decided, and never the last adventurer, can go.
- Candidates are rank F until the guild reaches rank E; from that moment 70% are rank E (180
  gold, level 3). The Common room adds candidate slots only.
- Candidate slots refill from saved timestamps only, like the quest board: being away gives the same
  candidates as watching.
- Taverns and training fill from saved timestamps only, up to their cap. Gold held changes only by
  rewards (paid when the party is back, a floor's clear bonus included), goal claims, spending, collecting and selling.

## Hall

- The guild has a rank, F to S. A new game is rank F: one floor (Reception in order, a side room
  and a backroom damaged), Bram and Tobin, and what the Reception gives (2 beds, 1 candidate slot,
  2 board slots, a stash of 6). Extend above the guild's rank is refused; every room type can be built at any rank. Saves from
  before ranks keep their rooms, roster, stash and capacities.
- Hall rooms show their name, their fill, faint furniture and one icon for what can be done; no
  status text and no adventurer faces. Unbuilt parts of the building are not drawn.
- Each room type is built at most once, except a second Bunk room from rank D; more of one comes
  from upgrading it. Every room upgrades twice, by the builder, each type at its own price: tier 2
  needs rank E and tier 3 rank D, except the Bunk room (any rank: 2, 3, then 4 beds). A room's
  upgrade icon shows only when the rank allows its next tier. A tier counts from when its upgrade
  finished. Old saves keep any copies they have.
- Reputation changes only when a party comes home: +1, +2 or +3 for a success at rank F, E or D,
  −1 for a failure, never below 0; a story quest may set its own (The sealed gate: +3). Ranking up
  doesn't spend it.
- The guild ranks up at the Reception when the player presses Rank up, never automatically. F → E
  needs 15 reputation, every room that can take a job in use, 2 parties, The sealed gate done, and
  150 gold. Rank E adds the
  Entrance hall and three damaged rooms (north-east, east, front). Ranking up brings the board, candidates and walk-ins up to date first; rules that
  change with rank count from the moment it was reached. The Reception shows its icon only when
  ranking up is allowed.
- A Storeroom adds 6 to the stash. Extending to the upper floor needs rank D.

## Goals

- Goals show on the Hall, several at once. A goal opens when the goals before it are claimed and is
  done when its count is met; its progress is computed from saved state, so time away can finish a
  goal but only the player claims it. Claiming pays its reward and unlocks what it names, once.
- The story chain is the guided start. Side goals run beside it and never block it.
- Auto unlocks with the side goal "Send 10 quests by hand": quests the player sends, counted when
  they come home. Until then parties can't use Auto and its switch is hidden. Saves from before
  goals keep Auto.

## Labyrinth

- The labyrinth opens when the goal "Finish The sealed gate" is claimed. Floor 1 is open from then;
  each floor after opens once the floor above is 50% explored.
- An expedition sends a whole party to an open floor, one party per floor at a time. A floor is
  never on the board, never expires, Auto never takes it, and it can be explored again after it is
  cleared. Its chance, damage, XP, gold, loot and reputation work as for a quest.
- A party home from a floor explores 20% of it and brings 3 of its material on a success, 5% and 1
  on a failure, up to 100%. The first time a floor reaches 100% it pays its clear bonus, once.
- Materials are counted apart from the stash and never fill it.

## Quests

- Labyrinth quests are ordinary board quests shown with a Labyrinth tag.
- Story quests sit in a Story row above the board while open (a goal's unlock opens them). They
  don't expire or use a slot, their challenges are all known, and Auto never takes them. A failed
  one can be tried again; a success marks it done for good.
- Only a whole party goes out, never part of one or a mix; how many are out is limited only by
  ready parties. A party takes quests at most one rank above its own rank.
- Auto (per party, once unlocked, off by default, saved, with Safe or Bold): a party with Auto on is ready the
  moment every member is home, at full health, not injured, not training and has no loot waiting.
  It then takes the board quest its rank allows with the most gold among those whose shown chance's
  low end is at least 70% (Safe) or 40% (Bold); ties go to the higher low end, then board order;
  with none it waits and tries again whenever the board changes or it is ready again. Parties ready
  together pick in party order. An Auto send's seed comes from saved state (party, quest, send
  time). Turning Auto off lets the current quest finish; the party then stays home. Any party can
  still be sent by hand.
- Auto sends, returns, healing, refills and quests leaving all happen in time order from saved
  timestamps, so one check after an absence gives the same as checking every second.
- The board has a fixed number of slots. Sending a quest empties its slot, which refills after its
  own countdown with a quest not on the board and not out, whatever the outcome. A quest left on the
  board leaves after a time by its rank, and its slot refills the same way; each row shows its time
  left. Refills and leaving depend only on saved timestamps, so being away gives the same board as
  watching.
- The board offers only quests at most one rank above the guild's highest-ranked party, and
  only of the guild's rank or one either side, weighted toward the guild's own (R−1 10%, R 70%,
  R+1 20%). A player action that changes a rank brings the board up to date first.
- A party's chance of success and each member's health are fixed when it leaves; nothing done
  while it is out changes how the quest ends. Nobody heals while out.
- There is no debrief: everything a returning party brings (gold, XP, damage, injuries, healing,
  loot) applies at its return, once, and its members are free for new quests. Loot that finds the
  stash full waits in Needs you on the Quests screen until the player swaps it in for a stash item,
  which is sold at its Armory price, or lets it go, or until the stash has room at a check, when it
  goes in by itself, oldest first; until then that party's members can't go out,
  train or be dismissed. Needs you also has one row for level-ups ready; the Quests tab counts its
  rows.
- Any stash item sells from the Armory, by quality: Standard 3, Fine 15, Legendary 60 gold. Worn
  items don't sell.
- A quest's XP is the party's total: each member gains the total ÷ party size, rounded down, but at least 1. A
  failed quest pays no gold and a quarter of the XP, at least 1.
- Anyone can be anything: there are no classes. A challenge tests the party's weighted stats, gear
  included, and a quest's chance averages its challenges with the weakest counted twice. Gear
  shapes growth: the stats worn items add grow faster. A title comes from the two highest stats.
- Spirit and Luck help the whole party: Spirit cuts everyone's damage; Luck brings more and better
  loot, softens a failure and may give a lucky break (the weakest challenge counts as just met),
  all fixed at send. What Luck does is never explained on screen, and a lucky break is never shown.
- Every recruit arrives wearing at least a weapon.
- The picker shows the chance as a range: ±10 around what the known challenges give, an unknown
  challenge counted as an even match and a lucky break left out. Until every challenge is known the
  real chance may lie outside it.
- The guild learns its quests: every party back from a quest, whatever the outcome, adds 1 point to
  that quest's chance, up to +15. It counts in the chance shown and is fixed when a party leaves.
