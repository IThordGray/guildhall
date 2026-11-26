class_name Hall
extends RefCounted

## UNBUILT is a room the hall doesn't have yet: a First floor room before the First floor is built,
## or a ground-floor slot its layout lacks.
enum State { USABLE, DAMAGED, RESTORING, RESTORED, CONVERTING, CONVERTED, UNBUILT }

## What restoring a room costs and takes, by the order rooms are restored in: the first room the
## first entry, and so on; any after the last, the last (stand-ins). Cheap and quick first.
const RESTORES: Array[Dictionary] = [
	{"gold": 60, "seconds": 1},
	{"gold": 60, "seconds": 2},
	{"gold": 120, "seconds": 4},
	{"gold": 200, "seconds": 10},
	{"gold": 300, "seconds": 20},
]
## Rooms usable from the start, where the hall has them; every other ground-floor room starts damaged.
const STARTING_USABLE: Array[String] = ["entrance", "reception"]
## The layout of a hall saved before guild ranks, and a new game's; and each once ranked up to E.
const OLD_LAYOUT: int = 0
const NEW_LAYOUT: int = 1
const NEW_LAYOUT_E: int = 2
const OLD_LAYOUT_E: int = 3
## What a hall is, by its layout: the ground floor's rooms, what its Reception gives the guild
## before any room adds to it (beds, candidate slots, quest board slots and the stash's size), and
## the layout ranking up grows it into, "rank_up" (none keeps it). A new game is a run-down rank-F
## hall: the Reception and two damaged rooms. A hall saved before guild ranks keeps its six rooms
## and the capacity it had then, so nobody is evicted and no item lost. Rank E adds the ground-floor
## wing and keeps the capacity. A save refers to a layout by its place here: append, never reorder.
const LAYOUTS: Array[Dictionary] = [
	{"ground_floor": ["back_left", "back_right", "side_left", "reception", "side_right", "entrance"], "beds": 4, "candidate_slots": 2, "board_slots": 3, "stash": 20, "rank_up": OLD_LAYOUT_E},
	{"ground_floor": ["reception", "side_left", "back_left"], "beds": 2, "candidate_slots": 1, "board_slots": 2, "stash": 6, "rank_up": NEW_LAYOUT_E},
	{"ground_floor": ["back_left", "back_right", "side_left", "reception", "side_right", "entrance", "front_right"], "beds": 2, "candidate_slots": 1, "board_slots": 2, "stash": 6},
	{"ground_floor": ["back_left", "back_right", "side_left", "reception", "side_right", "entrance", "front_right"], "beds": 4, "candidate_slots": 2, "board_slots": 3, "stash": 20},
]
## The rank a new guild starts at.
const STARTING_RANK: String = "F"
## What ranking up from each rank needs: the rank it leads "to", the "reputation" earned, how many
## "parties" the guild has, the "story" quest done (a Dispatch.QUESTS id) and the "gold" held, and
## every room in use (`rank_up_checklist`). A rank with no row is the last.
const RANK_UPS: Dictionary[String, Dictionary] = {
	"F": {"to": "E", "reputation": 15, "parties": 2, "story": "sealed_gate", "gold": 150},
}
## Extending the hall builds the First floor: what it costs and takes, done by the builder like a
## restoration, and how many rooms must be restored first (stand-ins).
const EXTEND_GOLD: int = 400
const EXTEND_SECONDS: int = 20
const EXTEND_AFTER_RESTORES: int = 3
## The guild rank extending needs.
const EXTEND_RANK: String = "D"
## The First floor's rooms. They are new, so they start restored and empty once it is built.
const FIRST_FLOOR: Array[String] = ["upper_nw", "upper_ne", "upper_sw", "upper_se"]
## What `building` holds while the builder extends the hall; not a slot.
const EXTENSION: String = "first_floor"
## What an empty restored room can be converted into, in panel order, at any guild rank, and what
## building it costs and takes. The hall has at most one room of each type, so growth comes from
## upgrading a room, not building another; a type with "second_rank" may be built a second time once
## the guild has that rank. Every type is upgraded by the builder from tier 1, each entry of
## "upgrades" the cost and time of reaching the next tier, as far as UPGRADE_RANKS allows unless
## "upgrades_any_rank", and its "blurb", where it has one, what that tier adds. A type that adds to a
## capacity ("beds", "stash", "candidate_slots" or "board_slots" in LAYOUTS, or "training_places",
## which the Reception gives none of) has it as a key: how much one finished room adds by its tier,
## the first entry tier 1, and so on (stand-ins); see `capacity`. A Tavern's "gold_per_minute" and
## "holds" and a Training room's "stint_xp" are by tier the same way; see `tavern_gold` and
## `stint_xp`. The save and the art refer to a type by its id. What any other type does, and what its
## tiers change, is applied where its effect is, from `tier_times`: see Dispatch (Infirmary), Board
## (Map room, Quest hall tier 3) and Recruits (Common room tier 3).
const ROOM_TYPES: Dictionary[String, Dictionary] = {
	"quest_hall": {"name": "Quest hall", "blurb": "adds a slot to the quest board", "board_slots": [1, 2, 2], "gold": 60, "seconds": 2, "upgrades": [{"gold": 120, "seconds": 4}, {"gold": 300, "seconds": 10, "blurb": "Slots refill twice as fast"}]},
	"infirmary": {"name": "Infirmary", "blurb": "injuries heal twice as fast", "gold": 60, "seconds": 2, "upgrades": [{"gold": 120, "seconds": 4, "blurb": "Heals faster, shorter injuries"}, {"gold": 300, "seconds": 10, "blurb": "Heals faster, shorter injuries"}]},
	"bunk_room": {"name": "Bunk room", "blurb": "2 more beds", "beds": [2, 4, 8], "gold": 30, "seconds": 2, "second_rank": "D", "upgrades": [{"gold": 60, "seconds": 4, "blurb": "+2 beds"}, {"gold": 120, "seconds": 10, "blurb": "+4 beds"}], "upgrades_any_rank": true},
	"tavern": {"name": "Tavern", "blurb": "earns gold while you're away", "gold_per_minute": [20, 40, 60], "holds": [40, 120, 300], "gold": 60, "seconds": 2, "upgrades": [{"gold": 180, "seconds": 4, "blurb": "+20 g a minute, holds more"}, {"gold": 450, "seconds": 10, "blurb": "+20 g a minute, holds more"}]},
	"map_room": {"name": "Map room", "blurb": "reveals quests' unknown challenges", "gold": 60, "seconds": 2, "upgrades": [{"gold": 180, "seconds": 4, "blurb": "Reveals sooner"}, {"gold": 450, "seconds": 10, "blurb": "Reveals at once"}]},
	"training_room": {"name": "Training room", "blurb": "trains one adventurer at a time", "training_places": [1, 1, 2], "stint_xp": [Dispatch.TRAINING_MAX_XP, 40, 40], "gold": 60, "seconds": 2, "upgrades": [{"gold": 180, "seconds": 4, "blurb": "40 XP a stint"}, {"gold": 450, "seconds": 10, "blurb": "A second trainee"}]},
	"common_room": {"name": "Common room", "blurb": "more candidates visit", "candidate_slots": [1, 2, 2], "gold": 60, "seconds": 2, "upgrades": [{"gold": 90, "seconds": 4}, {"gold": 220, "seconds": 10, "blurb": "Slots refill twice as fast"}]},
	"storeroom": {"name": "Storeroom", "blurb": "6 more stash slots", "stash": [6, 12, 20], "gold": 60, "seconds": 2, "upgrades": [{"gold": 90, "seconds": 4, "blurb": "+6 stash slots"}, {"gold": 220, "seconds": 10, "blurb": "+8 stash slots"}]},
}
## The guild rank upgrading a room to each tier from 2 needs: the first entry tier 2, and so on. The
## guild's rank is how far its rooms grow.
const UPGRADE_RANKS: Array[String] = ["E", "D"]

## Which of LAYOUTS the hall is.
var layout: int = NEW_LAYOUT
## The guild's rank. It limits what can be built from now on; rooms already built keep working.
var rank: String = STARTING_RANK
## Unix seconds the guild reached each rank it ranked up to: {rank: at}. A rank missing is not
## reached.
var ranked_at: Dictionary[String, int] = {}
## Slots the builder has finished restoring, converted or not.
var restored: PackedStringArray = PackedStringArray()
## Whether the builder has finished extending the hall.
var first_floor: bool = false
## Rooms the builder has finished converting: slot -> {"type": a ROOM_TYPES id, "done_at": unix
## seconds the conversion finished, which is when it reached tier 1, for a room upgraded at least
## once "upgraded_at": the unix seconds it reached each tier from 2, in order, and for a Tavern
## collected at least once "collected_at": unix seconds it was last collected}.
var converted: Dictionary[String, Dictionary] = {}
## The slot the builder is working on, or "" when the builder is free. One builder, so one
## restoration, conversion, upgrade or extension at a time.
var building: String = ""
## Unix seconds the builder started on `building`.
var building_since: int = 0
## How many seconds `building` takes in all, fixed when it started, so a later change to the rule
## tables never stretches a job under way; 0 for a job saved before lengths were kept.
var building_seconds: int = 0
## The room type `building` is being converted into, or is when it is being upgraded; "" when it is
## being restored.
var building_into: String = ""
## The tier `building`, a converted room, is being upgraded to; 0 when the job is not an upgrade.
var building_tier: int = 0
## Latest unix seconds seen. Time is read as never earlier than this, so a clock set back
## neither adds time to a countdown nor undoes a restoration or a conversion.
var checked_at: int


func _init(at: int) -> void:
	checked_at = at


func state(slot: String, now: int) -> State:
	if slot not in LAYOUTS[layout]["ground_floor"] and slot not in FIRST_FLOOR:
		return State.UNBUILT
	if slot in STARTING_USABLE:
		return State.USABLE
	# A room being upgraded stays converted, and in use, throughout.
	if slot == building and building_tier == 0:
		var done := seconds_left(now) == 0
		if building_into.is_empty():
			return State.RESTORED if done else State.RESTORING
		return State.CONVERTED if done else State.CONVERTING
	if slot in converted:
		return State.CONVERTED
	if slot in restored:
		return State.RESTORED
	if slot in FIRST_FLOOR:
		return State.RESTORED if has_first_floor(now) else State.UNBUILT
	return State.DAMAGED


## Whether the First floor is built by `now`; an extension under way counts once finished.
func has_first_floor(now: int) -> bool:
	return first_floor or (building == EXTENSION and seconds_left(now) == 0)


## The type `slot` is converted, or being converted, into; "" for none.
func room_type(slot: String) -> String:
	if slot == building:
		return building_into
	return converted.get(slot, {}).get("type", "")


## How many rooms of `type` are converted by `now`; one under way counts once finished.
func rooms_done(type: String, now: int) -> int:
	var count := 0
	for room: Dictionary in converted.values():
		if room["type"] == type:
			count += 1
	if _converting() and building_into == type and seconds_left(now) == 0:
		count += 1
	return count


## The tier of the converted room `slot` at `now`; an upgrade under way counts once finished.
func tier(slot: String, now: int) -> int:
	return tier_at(slot, maxi(now, checked_at))


## The tier the converted room `slot` has at `at`, a moment past or to come: 1, and one more for each
## upgrade finished by then, one under way included.
func tier_at(slot: String, at: int) -> int:
	var reached := 1
	for upgraded_at: int in converted.get(slot, {}).get("upgraded_at", []):
		if upgraded_at <= at:
			reached += 1
	if slot == building and building_tier > 0 and _done_at() <= at:
		reached += 1
	return reached


## What the Reception gives the guild of `what`, a capacity in LAYOUTS: "beds", "candidate_slots",
## "board_slots" or "stash"; 0 for one it gives none of, such as "training_places".
func reception(what: String) -> int:
	return LAYOUTS[layout].get(what, 0)


## Whether the guild's rank is at least `needed`.
func has_rank(needed: String) -> bool:
	return Challenges.RANKS.find(rank) >= Challenges.RANKS.find(needed)


## What ranking up from the guild's rank needs (RANK_UPS) against what a guild with `reputation`,
## `gold` held, `parties` (Parties.parties) and the story quests `story_done` (Dispatch.story_done)
## has at `now`, in order: {"what": "reputation", "rooms", "parties", "story" or "gold", "has",
## "needs", "met"}; the story line has 1 of 1 once its quest is done. Rooms count those on the
## layout's ground floor that can take a job, the Reception and the entrance hall not among them;
## one is in use once its conversion has finished. Empty at the last rank.
func rank_up_checklist(reputation: int, gold: int, parties: int, story_done: PackedStringArray, now: int) -> Array[Dictionary]:
	var checklist: Array[Dictionary] = []
	if not RANK_UPS.has(rank):
		return checklist
	var rooms := 0
	var in_use := 0
	for slot: String in LAYOUTS[layout]["ground_floor"]:
		if slot in STARTING_USABLE:
			continue
		rooms += 1
		if state(slot, now) == State.CONVERTED:
			in_use += 1
	var needs: Dictionary = RANK_UPS[rank]
	var story := 1 if needs["story"] in story_done else 0
	for line: Array in [["reputation", reputation, needs["reputation"]], ["rooms", in_use, rooms], ["parties", parties, needs["parties"]], ["story", story, 1], ["gold", gold, needs["gold"]]]:
		checklist.append({"what": line[0], "has": line[1], "needs": line[2], "met": line[1] >= line[2]})
	return checklist


## Why the guild, with `reputation` earned, `gold` held, and `parties` and `story_done` as for
## `rank_up_checklist`, can't rank up at `now`, in words for the player; "" when it can: the first
## unmet line of `rank_up_checklist`.
func rank_up_refusal(reputation: int, gold: Gold, parties: int, story_done: PackedStringArray, now: int) -> String:
	if not RANK_UPS.has(rank):
		return "Highest rank for now"
	for line: Dictionary in rank_up_checklist(reputation, gold.amount, parties, story_done, now):
		if line["met"]:
			continue
		match line["what"]:
			"rooms":
				return "Every room in use first"
			"parties":
				# RANK_UPS' one row needs 2.
				return "Form a second party first"
			"story":
				return "Finish %s first" % Dispatch.QUESTS[RANK_UPS[rank]["story"]]["name"]
		return "Need %d more %s" % [line["needs"] - line["has"], line["what"]]
	return ""


## Pays and ranks the guild up at `now`, with what it has as for `rank_up_refusal`, growing the hall
## into its layout's "rank_up" and recording when; false, with nothing changed, when
## `rank_up_refusal` gives a reason. Reputation is not spent. Rooms the hall already has keep their
## state; the ones the new layout adds start damaged.
func rank_up(reputation: int, gold: Gold, parties: int, story_done: PackedStringArray, now: int) -> bool:
	if not rank_up_refusal(reputation, gold, parties, story_done, now).is_empty():
		return false
	checkpoint(now)
	gold.spend(RANK_UPS[rank]["gold"])
	rank = RANK_UPS[rank]["to"]
	layout = LAYOUTS[layout].get("rank_up", layout)
	ranked_at[rank] = checked_at
	return true


## Whether the hall is one saved before guild ranks, ranked up since or not.
func from_before_ranks() -> bool:
	return layout == OLD_LAYOUT or layout == OLD_LAYOUT_E


## How many items the stash holds at most at `now`, as `capacity` gives it.
func stash_cap(now: int) -> int:
	return capacity("stash", now)


## How many adventurers the guild has beds for at `now`, as `capacity` gives it.
func beds(now: int) -> int:
	return capacity("beds", now)


## How much of `what`, a capacity (ROOM_TYPES), the guild has at `now`: the Reception's, and what
## each finished room adds by its tier then; a room under way counts once finished.
func capacity(what: String, now: int) -> int:
	var total := reception(what)
	for slot: String in converted:
		var adds: Array = ROOM_TYPES[converted[slot]["type"]].get(what, [])
		if not adds.is_empty():
			total += int(adds[tier(slot, now) - 1])
	if _converting() and seconds_left(now) == 0:
		total += int(ROOM_TYPES[building_into].get(what, [0])[0])
	return total


## When each slot of `what`, "candidate_slots" or "board_slots", that rooms add came, in unix
## seconds, one entry a slot: a room's tier-1 slots at its conversion, and the ones each later tier
## adds at the time that tier was reached, so no slot exists before its tier. Only rooms and tiers
## the last checkpoint saw count.
func added_at(what: String) -> PackedInt64Array:
	var times := PackedInt64Array()
	for room: Dictionary in converted.values():
		var adds: Array = ROOM_TYPES[room["type"]].get(what, [])
		var reached: Array = [room["done_at"]] + room.get("upgraded_at", [])
		var before := 0
		for at: int in mini(adds.size(), reached.size()):
			for slot: int in int(adds[at]) - before:
				times.append(int(reached[at]))
			before = int(adds[at])
	return times


## The slot of the first room of `type` to be converted, on any floor, counting one under way,
## whose end is fixed when it starts; "" when there is none.
func first_room(type: String) -> String:
	var first := ""
	for slot: String in converted:
		if converted[slot]["type"] == type and (first.is_empty() or int(converted[slot]["done_at"]) < int(converted[first]["done_at"])):
			first = slot
	# A room under way finishes after every converted one, so it is first only when alone.
	if building_into == type and first.is_empty():
		first = building
	return first


## Unix seconds the first room of `type` is converted at, as `first_room`; -1 when there is none.
func first_done_at(type: String) -> int:
	var first := first_room(type)
	if first.is_empty():
		return -1
	# A room being upgraded is among the converted ones.
	return _done_at() if first not in converted else int(converted[first]["done_at"])


## The unix seconds the guild first had a room of `type` at each tier, tier 1 first: for each tier,
## the earliest any room of that type reached it, a conversion or upgrade under way counted at the
## time it will finish, which is fixed when it starts; empty when there is none. Rules that change by
## a room's tier read it from these alone, so time away gives the same as watching.
func tier_times(type: String) -> PackedInt64Array:
	var rooms: Array[String] = []
	for slot: String in converted:
		if converted[slot]["type"] == type:
			rooms.append(slot)
	if _converting() and building_into == type:
		rooms.append(building)
	var times := PackedInt64Array()
	for slot: String in rooms:
		var reached := _tier_times(slot)
		for index: int in reached.size():
			if index == times.size():
				times.append(reached[index])
			else:
				times[index] = mini(times[index], reached[index])
	return times


## How many adventurers can train at once at `now`: each finished Training room's places by its
## tier then, as `capacity` gives it.
func training_places(now: int) -> int:
	return capacity("training_places", now)


## The most XP a stint of training gives when read at `now`: the "stint_xp" of the highest tier any
## finished Training room has then. A stint is short, so it takes the cap of the moment it is read,
## not the tier it started at.
func stint_xp(now: int) -> int:
	var by_tier: Array = ROOM_TYPES["training_room"]["stint_xp"]
	var most: int = by_tier[0]
	for slot: String in converted:
		if converted[slot]["type"] == "training_room":
			most = maxi(most, int(by_tier[tier(slot, now) - 1]))
	return most


## The most gold the Tavern in `slot` holds at `now`: the "holds" of its tier then.
func tavern_cap(slot: String, now: int) -> int:
	return int(ROOM_TYPES["tavern"]["holds"][tier(slot, now) - 1])


## The gold the Tavern in `slot` holds at `now`: since it finished or was last collected, each
## tier's "gold_per_minute" from the moment that tier was reached, never more than the "holds" of the
## tier it was earned at, so gold a full Tavern would have earned is lost, as when watching; 0 for
## any other room. Computed from saved times alone, so being away gives the same as watching.
func tavern_gold(slot: String, now: int) -> int:
	if room_type(slot) != "tavern" or state(slot, now) != State.CONVERTED:
		return 0
	var at := maxi(now, checked_at)
	var reached := _tier_times(slot)
	var since: int = reached[0] if slot not in converted else int(converted[slot].get("collected_at", reached[0]))
	var info: Dictionary = ROOM_TYPES["tavern"]
	# Gold a minute times seconds, divided once at the end so no tier's part is rounded alone.
	var earned := 0
	for index: int in reached.size():
		if reached[index] > at:
			break
		var until := at if index + 1 == reached.size() else mini(reached[index + 1], at)
		earned += maxi(0, until - maxi(reached[index], since)) * int(info["gold_per_minute"][index])
		earned = mini(earned, int(info["holds"][index]) * 60)
	return earned / 60


## Moves all the gold the Tavern in `slot` holds at `now` into `gold` and starts it filling again
## from then; the amount moved. An empty room gives 0 and is left as it was.
func collect(slot: String, gold: Gold, now: int) -> int:
	var amount := tavern_gold(slot, now)
	if amount == 0:
		return 0
	# A Tavern finished since the last checkpoint is among the converted rooms after it.
	checkpoint(now)
	converted[slot]["collected_at"] = checked_at
	gold.amount += amount
	return amount


## Seconds until the builder's current job finishes; 0 when it has finished or none is running.
func seconds_left(now: int) -> int:
	if building.is_empty():
		return 0
	return maxi(0, _done_at() - maxi(now, checked_at))


## Why `slot` can't be restored at `now`, in words for the player; "" when it can.
func refusal(slot: String, gold: Gold, now: int) -> String:
	if state(slot, now) != State.DAMAGED:
		return "Not damaged"
	return _builder_refusal(next_restore()["gold"], gold, now)


## Pays and starts restoring `slot` at `now`; false, with nothing paid, when `refusal` gives a reason.
func restore(slot: String, gold: Gold, now: int) -> bool:
	if not refusal(slot, gold, now).is_empty():
		return false
	_start(slot, "", 0, next_restore()["gold"], gold, now)
	return true


## What the next restoration costs and takes, {"gold", "seconds"} from RESTORES: the rooms
## restored and one under way come before it.
func next_restore() -> Dictionary:
	var before := restored.size()
	if _restoring():
		before += 1
	return _restore_after(before)


## How many seconds the builder's current job takes in all: as fixed when it started, or for a job
## saved before that, by the rule tables now.
func job_seconds() -> int:
	if building_seconds > 0:
		return building_seconds
	if building == EXTENSION:
		return EXTEND_SECONDS
	if building_into.is_empty():
		# The room under way is not yet among those restored.
		return _restore_after(restored.size())["seconds"]
	if building_tier > 0:
		return ROOM_TYPES[building_into]["upgrades"][building_tier - 2]["seconds"]
	return ROOM_TYPES[building_into]["seconds"]


# Whether the builder's current job is a restoration.
func _restoring() -> bool:
	return not building.is_empty() and building != EXTENSION and building_into.is_empty()


# Whether the builder's current job is a conversion.
func _converting() -> bool:
	return not building_into.is_empty() and building_tier == 0


# What restoring a room costs and takes once `before` rooms are restored.
static func _restore_after(before: int) -> Dictionary:
	return RESTORES[mini(before, RESTORES.size() - 1)]


## Why `slot` can't be converted into `type` at `now`, in words for the player; "" when it can.
## A type already built, or being built, can't be built again, but for a second room of a type with
## "second_rank" at that rank; rooms of a type a save already holds twice stay as they are.
func convert_refusal(slot: String, type: String, gold: Gold, now: int) -> String:
	if state(slot, now) != State.RESTORED:
		return "Not an empty room"
	if _converting() and building_into == type and seconds_left(now) > 0:
		return "Being built"
	var done := rooms_done(type, now)
	if done > 1 or (done == 1 and not ROOM_TYPES[type].has("second_rank")):
		return "Already built"
	if done == 1 and not has_rank(ROOM_TYPES[type]["second_rank"]):
		return "Guild rank %s" % ROOM_TYPES[type]["second_rank"]
	return _builder_refusal(ROOM_TYPES[type]["gold"], gold, now)


## Pays and starts converting `slot` into `type` at `now`; false, with nothing paid, when
## `convert_refusal` gives a reason.
func convert_room(slot: String, type: String, gold: Gold, now: int) -> bool:
	if not convert_refusal(slot, type, gold, now).is_empty():
		return false
	_start(slot, type, 0, ROOM_TYPES[type]["gold"], gold, now)
	return true


## What upgrading the converted room `slot` to its next tier costs and takes at `now`, {"gold",
## "seconds"}; {} when its type has no tiers or it is at its highest.
func next_upgrade(slot: String, now: int) -> Dictionary:
	var upgrades: Array = ROOM_TYPES.get(room_type(slot), {}).get("upgrades", [])
	var at := tier(slot, now)
	if at > upgrades.size():
		return {}
	return upgrades[at - 1]


## Whether the guild's rank allows the converted room `slot` its next tier at `now`: the tier's rank
## in UPGRADE_RANKS, or any rank for a type with "upgrades_any_rank"; false at its highest tier.
func rank_allows_upgrade(slot: String, now: int) -> bool:
	if next_upgrade(slot, now).is_empty():
		return false
	return ROOM_TYPES[room_type(slot)].get("upgrades_any_rank", false) or has_rank(UPGRADE_RANKS[tier(slot, now) - 1])


## Why `slot` can't be upgraded at `now`, in words for the player; "" when it can. The next tier
## needs `rank_allows_upgrade`.
func upgrade_refusal(slot: String, gold: Gold, now: int) -> String:
	var info: Dictionary = ROOM_TYPES.get(room_type(slot), {})
	if not info.has("upgrades"):
		return "Not upgradable"
	var next := next_upgrade(slot, now)
	if next.is_empty():
		return "Highest tier"
	if not rank_allows_upgrade(slot, now):
		return "Guild rank %s" % UPGRADE_RANKS[tier(slot, now) - 1]
	return _builder_refusal(next["gold"], gold, now)


## Pays and starts upgrading `slot` to its next tier at `now`; false, with nothing paid, when
## `upgrade_refusal` gives a reason. The tier rises once the job finishes.
func upgrade(slot: String, gold: Gold, now: int) -> bool:
	if not upgrade_refusal(slot, gold, now).is_empty():
		return false
	_start(slot, room_type(slot), tier(slot, now) + 1, next_upgrade(slot, now)["gold"], gold, now)
	return true


## Why the hall can't be extended at `now`, in words for the player; "" when it can.
func extend_refusal(gold: Gold, now: int) -> String:
	if first_floor or building == EXTENSION:
		return "Already extended"
	if not has_rank(EXTEND_RANK):
		return "Guild rank %s" % EXTEND_RANK
	# A restoration finished since the last checkpoint is not yet among those restored.
	var restores := restored.size() + (1 if _restoring() and seconds_left(now) == 0 else 0)
	if restores < EXTEND_AFTER_RESTORES:
		return "Restore the ground floor first"
	return _builder_refusal(EXTEND_GOLD, gold, now)


## Pays and starts extending the hall at `now`; false, with nothing paid, when `extend_refusal`
## gives a reason.
func extend(gold: Gold, now: int) -> bool:
	if not extend_refusal(gold, now).is_empty():
		return false
	_start(EXTENSION, "", 0, EXTEND_GOLD, gold, now)
	return true


## True when the builder finished a job after the last checkpoint: the "while you were away" news
## when the checkpoint was taken on leaving.
func finished_since_checkpoint(now: int) -> bool:
	return not building.is_empty() and seconds_left(now) == 0


## Records a finished job as restored, converted, upgraded or extended for good, and the time seen.
func checkpoint(now: int) -> void:
	checked_at = maxi(checked_at, now)
	if finished_since_checkpoint(checked_at):
		if building == EXTENSION:
			first_floor = true
		elif building_into.is_empty():
			restored.append(building)
		elif building_tier > 0:
			converted[building]["upgraded_at"] = converted[building].get("upgraded_at", []) + [_done_at()]
		else:
			converted[building] = {"type": building_into, "done_at": _done_at()}
		building = ""
		building_into = ""
		building_tier = 0
		building_seconds = 0


func _builder_refusal(cost: int, gold: Gold, now: int) -> String:
	if seconds_left(now) > 0:
		return "Builder busy"
	var short_gold := cost - gold.amount
	if short_gold > 0:
		return "Need %d more gold" % short_gold
	return ""


func _start(slot: String, into: String, to_tier: int, cost: int, gold: Gold, now: int) -> void:
	checkpoint(now)
	gold.spend(cost)
	building = slot
	building_into = into
	building_tier = to_tier
	building_since = checked_at
	# The builder was free, so nothing is fixed yet and this reads the rule tables.
	building_seconds = job_seconds()


func _done_at() -> int:
	return building_since + job_seconds()


# Unix seconds the room `slot`, converted or being converted, reached each tier, tier 1 first; an
# upgrade under way counts at the time it will finish.
func _tier_times(slot: String) -> Array[int]:
	if slot not in converted:
		return [_done_at()]
	var times: Array[int] = [int(converted[slot]["done_at"])]
	for upgraded_at: int in converted[slot].get("upgraded_at", []):
		times.append(upgraded_at)
	if slot == building and building_tier > 0:
		times.append(_done_at())
	return times


## Puts the hall into `file`, which other state shares, so one save holds the whole game.
## The builder's job keeps the keys it had when it could only restore, so older saves still load.
func write(file: ConfigFile) -> void:
	file.set_value("hall", "layout", layout)
	file.set_value("hall", "rank", rank)
	file.set_value("hall", "ranked_at", ranked_at)
	file.set_value("hall", "restored", restored)
	file.set_value("hall", "converted", converted)
	file.set_value("hall", "restoring", building)
	file.set_value("hall", "restoring_since", building_since)
	file.set_value("hall", "converting_into", building_into)
	file.set_value("hall", "building_seconds", building_seconds)
	file.set_value("hall", "building_tier", building_tier)
	file.set_value("hall", "first_floor", first_floor)
	file.set_value("hall", "checked_at", checked_at)


## The hall saved at `path`, or a new game's at `now` when there is no save. A save without a
## layout is from before guild ranks, and keeps the hall it had then.
static func load_or_start(path: String, now: int) -> Hall:
	var hall := Hall.new(now)
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return hall
	hall.layout = int(file.get_value("hall", "layout", OLD_LAYOUT))
	hall.rank = file.get_value("hall", "rank", STARTING_RANK)
	hall.ranked_at.assign(file.get_value("hall", "ranked_at", {}))
	if not file.has_section("hall"):
		return hall
	hall.restored = file.get_value("hall", "restored", PackedStringArray())
	hall.converted.assign(file.get_value("hall", "converted", {}))
	# A save from before tier times kept only the tier reached: each tier counts from the conversion.
	for room: Dictionary in hall.converted.values():
		if room.has("tier"):
			var upgraded_at := []
			upgraded_at.resize(int(room["tier"]) - 1)
			upgraded_at.fill(int(room["done_at"]))
			room["upgraded_at"] = upgraded_at
			room.erase("tier")
	hall.building = file.get_value("hall", "restoring", "")
	hall.building_since = int(file.get_value("hall", "restoring_since", 0))
	hall.building_into = file.get_value("hall", "converting_into", "")
	hall.building_seconds = int(file.get_value("hall", "building_seconds", 0))
	hall.building_tier = int(file.get_value("hall", "building_tier", 0))
	hall.first_floor = file.get_value("hall", "first_floor", false)
	hall.checked_at = int(file.get_value("hall", "checked_at", now))
	return hall
