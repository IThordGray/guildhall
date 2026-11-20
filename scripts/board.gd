class_name Board
extends RefCounted

## How many slots the board has without a Quest hall; each finished one adds one.
const QUESTS_A_REFRESH: int = 3
## How long a slot takes to refill after its quest is sent, by the rank of the quest sent from it:
## short for easy quests, longer for hard ones (stand-ins).
const REFILL_SECONDS: Dictionary[String, int] = {"F": 600, "E": 1_800, "D": 3_600}

## Each slot's quest, a key of Dispatch.QUESTS, or "" while the slot refills.
var slots: PackedStringArray = PackedStringArray()
## Unix seconds each empty slot refills at; unused while the slot is filled.
var refill_at: PackedInt64Array = PackedInt64Array()
## Each quest seen out with a party, and the unix seconds that party is back, so a refill worked
## out after the party is home still knows the quest was out until then.
var back_at: Dictionary[String, int] = {}
## Latest unix seconds the board has been refilled up to.
var checked_at: int = 0


## How many slots hold a quest.
func filled() -> int:
	return slots.size() - slots.count("")


## Brings the board up to `now`: adds a slot for each Quest hall finished, due at the hall's finish
## time in `quest_halls_done`, and fills the empty slots in the order their time comes. Each slot
## is judged at its own refill time from saved timestamps alone, so refilling once after an absence
## gives the same board as refilling every second through it: it takes a quest neither on the
## board nor out with a party at that moment, or, with none free, the first freed after it; and
## only a quest at most one rank above the guild's highest-ranked adventurer. Time is read from no
## earlier than `dispatch` or the board last saw, so a clock set back never undoes a refill or
## restarts a countdown. A new board starts with every slot filled.
func refill(dispatch: Dispatch, now: int, quest_halls_done: PackedInt64Array) -> void:
	var at := maxi(maxi(now, dispatch.checked_at), checked_at)
	if slots.is_empty():
		checked_at = at
	while slots.size() < QUESTS_A_REFRESH:
		_add_slot(checked_at)
	var halls := quest_halls_done.duplicate()
	halls.sort()
	for i: int in range(slots.size() - QUESTS_A_REFRESH, halls.size()):
		_add_slot(halls[i])
	_note_outings(dispatch)
	# The rank now stands for every refill due up to `at`: a rank changes only by a player action,
	# and whatever does that refills the board first, so fills due before it use the rank before it.
	var top := _top_rank(dispatch.adventurers.roster)
	while true:
		var next := -1
		var next_time := 0
		for i: int in slots.size():
			var time := _fill_time(i, top)
			if time < 0 or time > at:
				continue
			if next == -1 or time < next_time or (time == next_time and refill_at[i] < refill_at[next]):
				next = i
				next_time = time
		if next == -1:
			break
		slots[next] = _pick(next, next_time, top)
	checked_at = at


## Sends `party` on `quest` through `dispatch`, empties its slot and starts that slot's countdown;
## false, with nothing sent, when the board at `now` doesn't show `quest` or `dispatch` refuses the
## party. The other arguments are as for `refill` and `Dispatch.send`.
func send(dispatch: Dispatch, quest: String, party: PackedStringArray, roll_seed: int, gold: Gold, now: int, quest_halls_done: PackedInt64Array, infirmary_from: int = -1) -> bool:
	dispatch.checkpoint(now, gold, infirmary_from)
	refill(dispatch, now, quest_halls_done)
	var slot := slots.find(quest)
	if quest == "" or slot == -1:
		return false
	if not dispatch.send(quest, party, roll_seed, gold, now, infirmary_from):
		return false
	_note_outings(dispatch)
	slots[slot] = ""
	refill_at[slot] = dispatch.checked_at + REFILL_SECONDS[Dispatch.QUESTS[quest]["rank"]]
	return true


## Seconds from `now` until empty slot `slot` refills; 0 once due, while no quest is free.
func seconds_to_refill(slot: int, dispatch: Dispatch, now: int) -> int:
	return maxi(0, refill_at[slot] - maxi(maxi(now, dispatch.checked_at), checked_at))


## Puts the board into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("board", "slots", slots)
	file.set_value("board", "refill_at", refill_at)
	file.set_value("board", "back_at", back_at)
	file.set_value("board", "checked_at", checked_at)


## The board saved at `path`, or one with no slots, which the first `refill` fills, when the save
## has none.
static func load_or_start(path: String) -> Board:
	var board := Board.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section_key("board", "slots"):
		return board
	board.slots = file.get_value("board", "slots")
	board.refill_at = file.get_value("board", "refill_at")
	board.back_at = file.get_value("board", "back_at")
	board.checked_at = file.get_value("board", "checked_at")
	return board


func _add_slot(due: int) -> void:
	slots.append("")
	refill_at.append(due)


func _note_outings(dispatch: Dispatch) -> void:
	for outing: Dictionary in dispatch.outings:
		back_at[outing["quest"]] = dispatch.back_at(outing)


# The highest rank in `roster` (Adventurers.roster); F when it is empty.
static func _top_rank(roster: Dictionary) -> String:
	var top := 0
	for who: Dictionary in roster.values():
		top = maxi(top, Challenges.RANKS.find(who["rank"]))
	return Challenges.RANKS[top]


# When empty slot `slot` fills, for a guild whose highest rank is `top`: its refill time, or no
# earlier than the board was last refilled to, as it found nothing free before then; else the
# first party's return after that frees a quest. -1 when the slot is filled or no return to come
# frees one.
func _fill_time(slot: int, top: String) -> int:
	if slots[slot] != "":
		return -1
	var from := maxi(refill_at[slot], checked_at)
	var times: Array[int] = [from]
	for back: int in back_at.values():
		if back > from:
			times.append(back)
	times.sort()
	for time: int in times:
		if not _free(time, top).is_empty():
			return time
	return -1


# The quests neither on the board nor out at `time` that a guild whose highest rank is `top` can
# take (Challenges.can_join), in Dispatch.QUESTS order.
func _free(time: int, top: String) -> PackedStringArray:
	var free := PackedStringArray()
	for quest: String in Dispatch.QUESTS:
		if quest not in slots and back_at.get(quest, 0) <= time and Challenges.can_join(top, Dispatch.QUESTS[quest]["rank"]):
			free.append(quest)
	return free


# A quest for `slot` from those free at `time` for a guild whose highest rank is `top`, drawn by a
# seed of the slot and its refill time, so the same save always refills the same way.
func _pick(slot: int, time: int, top: String) -> String:
	var free := _free(time, top)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([slot, refill_at[slot]])
	return free[rng.randi_range(0, free.size() - 1)]
