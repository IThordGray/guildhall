class_name Goals
extends RefCounted

## What Odile, the town clerk, asks of the guild next. Story goals open one after another; side goals
## open alongside and never hold the story back. A goal is locked until every goal it opens after is
## claimed, open until what it counts meets its target, then done until the player claims it, which
## pays its reward and turns on what it unlocks. What a goal counts is read from the game each time
## it is asked, never added up as it happens; only quests sent by hand are counted as they come home.

enum State { LOCKED, OPEN, DONE, CLAIMED }

const STORY: String = "story"
const SIDE: String = "side"
## What claiming "hand_quests" unlocks: Auto (see Auto.checkpoint).
const AUTO: String = "auto"

## Chapter 1, in the order the story tells it. Each goal: "name", what the player sees it called;
## "kind", STORY or SIDE; "openers", the goals that must be claimed before it opens; "counts", what
## it counts (`progress`), with "rank" or "quest" where that needs one, and "need", the target;
## "line", what the clerk says; "gold" and, for some, "reputation", its reward; "unlocks", a flag or
## story quest claiming it turns on, "" for none. The save refers to a goal by its id.
const GOALS: Dictionary[String, Dictionary] = {
	"first_quest": {"name": "Send a party on a quest", "kind": STORY, "openers": [], "counts": "quests_home", "need": 1, "line": "Pick a quest from the board and see your party home.", "gold": 10, "unlocks": ""},
	"first_restore": {"name": "Restore a room", "kind": STORY, "openers": ["first_quest"], "counts": "rooms_restored", "need": 1, "line": "This old hall needs work. Have the builder restore a room.", "gold": 15, "unlocks": ""},
	"first_room": {"name": "Give a room a job", "kind": STORY, "openers": ["first_restore"], "counts": "rooms_in_use", "need": 1, "line": "An empty room earns nothing. Give your restored room a job.", "gold": 15, "unlocks": ""},
	"first_recruit": {"name": "Recruit someone", "kind": STORY, "openers": ["first_room"], "counts": "adventurers", "need": 3, "line": "Three adventurers make a proper guild. Hire someone new.", "gold": 20, "unlocks": ""},
	"second_party": {"name": "Form a second party", "kind": STORY, "openers": ["first_recruit"], "counts": "parties", "need": 2, "line": "Two parties can work at once. Form a second one.", "gold": 20, "unlocks": "sealed_gate"},
	"sealed_gate": {"name": "Finish The sealed gate", "kind": STORY, "openers": ["second_party"], "counts": "story_quest", "quest": "sealed_gate", "need": 1, "line": "The town wants the sealed gate opened. I think you're ready.", "gold": 30, "reputation": 3, "unlocks": Labyrinth.UNLOCK},
	"first_expedition": {"name": "Send a party into the labyrinth", "kind": STORY, "openers": ["sealed_gate"], "counts": "floors_home", "need": 1, "line": "The gate is open. Send a party down and see what they find.", "gold": 20, "unlocks": ""},
	"rank_e": {"name": "Rank up to E", "kind": STORY, "openers": ["sealed_gate"], "counts": "guild_rank", "rank": "E", "need": 1, "line": "You've earned the town's trust. Rank the guild up to E.", "gold": 50, "unlocks": ""},
	"hand_quests": {"name": "Send 10 quests by hand", "kind": SIDE, "openers": [], "counts": "hand_quests", "need": 10, "line": "Send ten quests out yourself, then your parties may go alone.", "gold": 20, "unlocks": AUTO},
}

## The goals claimed, each once, in the order they were.
var claimed: PackedStringArray = PackedStringArray()
## The flags and story quests claims have turned on.
var unlocked: PackedStringArray = PackedStringArray()
## How many quests the player sent by hand have come home, whatever their outcome.
var hand_quests: int = 0
## The outings the player sent by hand that were still out when last counted (`outing_key`).
var out_by_hand: PackedStringArray = PackedStringArray()


## Whether a claim has turned `flag` on.
func is_unlocked(flag: String) -> bool:
	return flag in unlocked


## The state of goal `id` at `now`, for a guild of `dispatch` and `hall` that has finished the story
## quests in `story_done`.
func state(id: String, dispatch: Dispatch, hall: Hall, story_done: PackedStringArray, now: int) -> State:
	if id in claimed:
		return State.CLAIMED
	for opener: String in GOALS[id]["openers"]:
		if opener not in claimed:
			return State.LOCKED
	var have_need := progress(id, dispatch, hall, story_done, now)
	return State.DONE if have_need.x >= have_need.y else State.OPEN


## The goals open or done at `now`, as the player sees them listed: the story goals, then the side
## goals, each in table order. The arguments are as for `state`.
func shown(dispatch: Dispatch, hall: Hall, story_done: PackedStringArray, now: int) -> PackedStringArray:
	var story := PackedStringArray()
	var side := PackedStringArray()
	for id: String in GOALS:
		if state(id, dispatch, hall, story_done, now) not in [State.OPEN, State.DONE]:
			continue
		if GOALS[id]["kind"] == STORY:
			story.append(id)
		else:
			side.append(id)
	return story + side


## What goal `id` counts, as [have, need], from the game as it is at `now`: parties home from any
## quest or from any floor of the labyrinth (Dispatch.tries), rooms on the ground floor restored or with a job, adventurers, parties,
## whether its story quest is in `story_done` or the guild has its rank, or quests sent by hand
## home (`hand_quests`).
func progress(id: String, dispatch: Dispatch, hall: Hall, story_done: PackedStringArray, now: int) -> Vector2i:
	var goal: Dictionary = GOALS[id]
	var have := 0
	match goal["counts"]:
		"quests_home":
			for tried: int in dispatch.tries.values():
				have += tried
		"floors_home":
			for floor_id: String in Labyrinth.FLOORS:
				have += int(dispatch.tries.get(floor_id, 0))
		"rooms_restored", "rooms_in_use":
			for slot: String in Hall.LAYOUTS[hall.layout]["ground_floor"]:
				var room := hall.state(slot, now)
				if room == Hall.State.CONVERTED or (goal["counts"] == "rooms_restored" and room in [Hall.State.RESTORED, Hall.State.CONVERTING]):
					have += 1
		"adventurers":
			have = dispatch.adventurers.roster.size()
		"parties":
			have = dispatch.adventurers.parties.parties.size()
		"story_quest":
			have = 1 if goal["quest"] in story_done else 0
		"guild_rank":
			have = 1 if hall.has_rank(goal["rank"]) else 0
		"hand_quests":
			have = hand_quests
	return Vector2i(have, goal["need"])


## Claims goal `id`: pays its gold into `dispatch`'s and its reputation into the guild's, records
## the claim and turns on what it unlocks; false, with nothing changed, unless it is done at `now`.
## The other arguments are as for `state`.
func claim(id: String, dispatch: Dispatch, hall: Hall, story_done: PackedStringArray, now: int) -> bool:
	if state(id, dispatch, hall, story_done, now) != State.DONE:
		return false
	var goal: Dictionary = GOALS[id]
	dispatch.gold.amount += int(goal["gold"])
	dispatch.reputation += int(goal.get("reputation", 0))
	claimed.append(id)
	if not goal["unlocks"].is_empty() and not is_unlocked(goal["unlocks"]):
		unlocked.append(goal["unlocks"])
	return true


## Notes `outing`, just sent by the player, so it counts once it comes home (`count_home`).
func sent_by_hand(outing: Dictionary) -> void:
	out_by_hand.append(outing_key(outing))


## Counts each outing sent by hand that is no longer out in `dispatch` as home.
func count_home(dispatch: Dispatch) -> void:
	var still_out := PackedStringArray()
	for outing: Dictionary in dispatch.outings:
		still_out.append(outing_key(outing))
	for key: String in out_by_hand.duplicate():
		if key not in still_out:
			out_by_hand.remove_at(out_by_hand.find(key))
			hand_quests += 1


## What tells `outing` apart from every other: a party is out on one quest at a time, from a time
## no other outing of its starts at.
static func outing_key(outing: Dictionary) -> String:
	return "%s@%d" % [outing.get("party_id", ""), outing["since"]]


## Puts the goals into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("goals", "claimed", claimed)
	file.set_value("goals", "unlocked", unlocked)
	file.set_value("goals", "hand_quests", hand_quests)
	file.set_value("goals", "out_by_hand", out_by_hand)


## The goals saved at `path`; a new game's, with nothing unlocked, when there is no save. A save
## without goals is from before them: its guild has had Auto all along, so it keeps it, and with
## nothing claimed, the goals it already meets are done.
static func load_or_start(path: String) -> Goals:
	var goals := Goals.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return goals
	if not file.has_section("goals"):
		goals.unlocked.append(AUTO)
		return goals
	goals.claimed = file.get_value("goals", "claimed", PackedStringArray())
	goals.unlocked = file.get_value("goals", "unlocked", PackedStringArray())
	goals.hand_quests = int(file.get_value("goals", "hand_quests", 0))
	goals.out_by_hand = file.get_value("goals", "out_by_hand", PackedStringArray())
	return goals
