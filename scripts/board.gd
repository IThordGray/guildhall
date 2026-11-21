class_name Board
extends RefCounted

## How long a slot takes to refill after its quest is sent, by the rank of the quest sent from it:
## short for easy quests, longer for hard ones (stand-ins).
const REFILL_SECONDS: Dictionary[String, int] = {"F": 600, "E": 1_800, "D": 3_600}
## Once the first Map room is finished, each quest on the board has its unknown challenges revealed
## this long after the later of when it was put on the board and when that room finished; more Map
## rooms don't speed it (stand-in).
const MAP_REVEAL_SECONDS: int = 300

## Each slot's quest, a key of Dispatch.QUESTS, or "" while the slot refills.
var slots: PackedStringArray = PackedStringArray()
## Unix seconds each empty slot refills at; unused while the slot is filled.
var refill_at: PackedInt64Array = PackedInt64Array()
## Unix seconds each filled slot was filled at; unused while the slot is empty.
var filled_at: PackedInt64Array = PackedInt64Array()
## Each quest seen out with a party, and the unix seconds that party is back, so a refill worked
## out after the party is home still knows the quest was out until then.
var back_at: Dictionary[String, int] = {}
## Latest unix seconds the board has been refilled up to.
var checked_at: int = 0
## How many slots the board has without a Quest hall, as the Reception gives it (Hall.reception);
## each finished one adds one. Not saved: whoever loads the game sets it from the hall.
var reception_slots: int = Hall.LAYOUTS[Hall.NEW_LAYOUT]["board_slots"]
## The unix seconds the first Map room is finished at, as the last refill was told; -1 for none.
var _map_room_from: int = -1


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
## restarts a countdown. A new board starts with every slot filled. Then, with the first Map room
## finished at `map_room_from` (-1 for none), reveals for good the unknown challenges of each quest
## on the board MAP_REVEAL_SECONDS after the later of its fill time and that, all by `now`.
func refill(dispatch: Dispatch, now: int, quest_halls_done: PackedInt64Array, map_room_from: int = -1) -> void:
	var at := maxi(maxi(now, dispatch.checked_at), checked_at)
	if slots.is_empty():
		checked_at = at
	while slots.size() < reception_slots:
		_add_slot(checked_at)
	var halls := quest_halls_done.duplicate()
	halls.sort()
	for i: int in range(slots.size() - reception_slots, halls.size()):
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
		filled_at[next] = next_time
	checked_at = at
	# A quest leaves the board only when sent, and every send refills first, so the quests on the
	# board now have been there since their fill time: revealing them here is the same as revealing
	# each the moment its time came.
	_map_room_from = map_room_from
	for i: int in slots.size():
		if seconds_to_reveal(slots[i], dispatch, at) == 0:
			dispatch.revealed.append(slots[i])


## Sends `party` on `quest` through `dispatch`, empties its slot and starts that slot's countdown;
## false, with nothing sent, when the board at `now` doesn't show `quest` or `dispatch` refuses the
## party. The other arguments are as for `refill` and `Dispatch.send`.
func send(dispatch: Dispatch, quest: String, party: PackedStringArray, roll_seed: int, now: int, quest_halls_done: PackedInt64Array, infirmary_from: int = -1, map_room_from: int = -1) -> bool:
	dispatch.checkpoint(now, infirmary_from)
	refill(dispatch, now, quest_halls_done, map_room_from)
	var slot := slots.find(quest)
	if quest == "" or slot == -1:
		return false
	if not dispatch.send(quest, party, roll_seed, now, infirmary_from):
		return false
	_note_outings(dispatch)
	slots[slot] = ""
	refill_at[slot] = dispatch.checked_at + REFILL_SECONDS[Dispatch.QUESTS[quest]["rank"]]
	return true


## Seconds from `now` until empty slot `slot` refills; 0 once due, while no quest is free.
func seconds_to_refill(slot: int, dispatch: Dispatch, now: int) -> int:
	return maxi(0, refill_at[slot] - maxi(maxi(now, dispatch.checked_at), checked_at))


## Seconds from `now` until the soonest of the empty slots that is counting down refills; 0 when
## every empty slot is due and waits for a quest to be free; -1 when no slot is empty.
func seconds_to_next_refill(dispatch: Dispatch, now: int) -> int:
	var soonest := -1
	for slot: int in slots.size():
		if slots[slot] != "":
			continue
		var left := seconds_to_refill(slot, dispatch, now)
		if soonest <= 0 or (left > 0 and left < soonest):
			soonest = left
	return soonest


## Seconds from `now` until the Map room reveals `quest`'s unknown challenges; 0 once due, -1 when
## no reveal is coming: no Map room finished by then as the last refill was told, `quest` not on the
## board, or nothing about it unknown.
func seconds_to_reveal(quest: String, dispatch: Dispatch, now: int) -> int:
	var slot := slots.find(quest)
	var at := maxi(maxi(now, dispatch.checked_at), checked_at)
	if quest == "" or slot == -1 or _map_room_from < 0 or _map_room_from > at or dispatch.unknown_challenges(quest).is_empty():
		return -1
	return maxi(0, maxi(filled_at[slot], _map_room_from) + MAP_REVEAL_SECONDS - at)


## Puts the board into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("board", "slots", slots)
	file.set_value("board", "refill_at", refill_at)
	file.set_value("board", "filled_at", filled_at)
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
	# A save from before fill times were kept takes its slots as filled when it was last refilled.
	var unknown_fill := PackedInt64Array()
	unknown_fill.resize(board.slots.size())
	unknown_fill.fill(board.checked_at)
	board.filled_at = file.get_value("board", "filled_at", unknown_fill)
	return board


func _add_slot(due: int) -> void:
	slots.append("")
	refill_at.append(due)
	filled_at.append(0)


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
