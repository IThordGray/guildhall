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

- **Next:** to plan with the human (the next-batch page's later items: rank C's wing and tier 4,
  floors 4–6, the Notice board, renting rooms).
- Single-player for good: no multiplayer is planned.
- **Later, not planned yet:** battery use (a phone emptied in a day of play: frames drawn while
  nothing moves, low-processor mode, pausing when hidden); Quest hall extras, the labyrinth.
- Screens follow the v2 designs (linked from the spec).
- Interim, for play-testing: a start screen (Continue / New game), to be revised; a Test speed
  control (×1/×10/×60 while open), to be removed before release.
- Done: M0 runs on my phone (Pages + APK per push, failing test blocks deploy) · M1 gold while
  you're away (drip later replaced by quests; away message removed, its hook kept) · M2 restore a
  room · M3 send a party · M4 adventurers (4 starters, seeded outcomes, injuries) · M5 rooms with
  jobs (Quest hall, Infirmary) · M6 send everyone ready (daily board, no cap on parties out, parties
  of up to 4) · M7 the v2 look (dark theme, four tabs, Hall as a floor plan with an In progress
  list) · M8 debriefs (returned parties wait as debriefs, counted on the Quests tab) · M9a stats, XP
  and levels (four stats behind power, player-pressed level-ups by hidden growth) · M9b health and
  damage (heals over time, heavy damage injures; no death until recruitment exists) · M10 challenges
  and ranks (hidden difficulty, class coverage, forecast as a range, reveal on return) · M11 gear
  and loot (eight slots, shared stash, loot by rank and quality; design icons and faces) · M12
  landscape (left rail, side-by-side screens) · board slots each refill on their own countdown ·
  swipe between adventurers · M13 recruitment (roster saved; two candidate slots refilling on their
  own countdown, all stats shown; 100 gold a hire; 4 beds +2 per Bunk room, at most
  8; placeholder faces for recruits) · M14 more quests and the first session (18 quests over F–D; a slot's
  refill time by the rank sent; restores dearer and slower in order; 100 starting gold; damage by
  rank, so a failed E quest can injure from full health) · M15 promotion (F→E at level 3 for 150g,
  E→D at level 6 for 400g, on the Adventurer screen) · M16 Tavern (fills with 2 gold a minute up to
  120; tap Collect, a +N flies to the gold) · M17 first floor (Extend from the Entrance hall after 3
  restores, 400g · 10:00; four empty rooms on 1F; floor selector) · M18 Map room (a board quest's
  unknown challenges show 5 minutes after it is on the board and a Map room is finished) · M19
  Training room (one trainee per room, 1 XP a minute up to 60 a stint, banked on Stop; after 10
  minutes' training a hint names the fastest-growing stat). · M20 Common room (+1 candidate slot each, at most 4;
  after the first, a quarter of candidates are rank E at 180g).
  · Play-note fixes (health +3 a level past 1, so a failed quest of a member's promotion rank
  injures about 55–65%; rank-E recruits arrive at level 3; a builder job keeps the length it
  started with; training shows in In progress; picker forecast updates on a reveal).
  · Phone play notes (drag-scroll anywhere, taps need clear intent, full screens instead of
  dialogs; gear chosen from its slot, an Armory screen, debrief opens adventurers, no captions or
  blurbs on the plan; each room type once; XP at the return, gold and loot when the debrief is
  read; every adventurer gets a face generated from their own seed).
  · Phone play notes 2 (one countdown per list, actions first; whole-card taps; slop about 10 dp
  with fling; Train and Promote only when they apply; Armory is storage only; XP shared by the
  party; failure pays no gold and a quarter of the XP; quest gold cut to a fifth (F) or a quarter).
  · Full figures (32×44 layered figures wearing their gear on the Adventurer screen, Roster rows
  and picker cards, drawn at runtime from the design generator's shapes; face tokens are a crop of
  the figure's head). · G1 rank-F start (one floor: Reception, side room, backroom; Bram and Tobin;
  Reception gives 2 beds, 1 candidate slot, 2 board slots, stash of 6; Bunk room and Common room
  only) · Hall icons (rooms show name and one icon; restore and extend confirm in a small sheet). · Quiet floor plan (designed on the canvas: game
  colours, faint furniture per room type, building centred, no faces or unbuilt outlines; the
  confirmation is a centred card). · Pacing (every timer ÷30 and quest rewards ÷3 after play at
  ×60; F quests easy for the two starters; the board's ranks weighted by the guild's rank; the
  guild learns a quest, +1 a try up to +15). · Anyone can be anything (nine stats incl.
  Endurance, Presence, Luck; challenges test weighted stats, the weakest counted twice; every item
  adds stats and shapes growth; titles from the top two stats; Luck's lucky break). · Walk-ins (free,
  a hidden 3–7 min arrival, swap when beds are full; dismiss from the Adventurer screen)). · Compact gear and roster (52-dp roster rows; stat chips and icon-only slots with fit
  badges; gear changed in place from a slot or a stash item through a tray; landscape roster list beside
  the adventurer; candidates and walk-ins open a character sheet). · Needs you and compact Quests (no
  debrief: returns pay at once; only full-stash loot and ready level-ups wait in Needs you; board
  quests leave after a time by rank; compact Quests rows and a picker of one quest card over compact
  rows). · Parties (everyone who quests is in a named party of 1–4, the rest are reserves; only
  whole parties go out, gated by party rank; Auto per party, Safe or Bold, replayed while away;
  absences past 3 hours settled by averages; promotion earned by 5 successful quests at the next
  rank and free, +1 to the two highest stats; waiting loot stows itself once there is room). · G2 guild rank E (reputation from quests;
  the Reception shows rank and the checklist, Rank up for 150g; rank E adds the wing with a split
  front, the Storeroom, walk-ins every 12–16 h and 70% rank-E candidates; Extend needs D; Bunk room
  upgrades twice; restores 60, 60 then dearer, Bunk room 30 to build; promotion progress shown). · M1 goals and story
  quests (a Goals card on the Hall with Claim; the guided start as the story chain; Auto unlocked by
  10 quests sent by hand; story quests above the board; The sealed gate; F → E also needs 2 parties
  and the gate). · M2 the labyrinth (a Labyrinth tab after The sealed gate; three floors explored by
  expeditions for materials and a clear bonus; labyrinth quests tagged on the board). · M3 G3 (every room type at any rank; tiers 2–3 for every room,
  capped by rank; Bunk 2/4/8 beds, no roster cap; chapter 2 with the Kitchen; E → D by metrics). · M4 the town (a Hall | Town switch after rank E; the Market sells 4
  items a day and buys materials). · M5 rank C (six C quests, promotion to C, D → C; Deadly elite
  expeditions, the only way to die; an Elite switch per party for Auto).

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
