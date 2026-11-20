class_name Board
extends RefCounted

## How many slots the board has without a Quest hall; each finished one adds one.
const QUESTS_A_REFRESH: int = 3
## How long a slot takes to refill after its quest is sent.
const REFRESH_SECONDS: int = 3_600

## Each slot's quest, a key of Dispatch.QUESTS, or "" while the slot refills.
var slots: PackedStringArray = PackedStringArray()
## Unix seconds each empty slot refills at; unused while the slot is filled.
var refill_at: PackedInt64Array = PackedInt64Array()


## Adds a slot for each Quest hall finished and fills each empty slot whose time has come, in slot
## order, with a quest neither on the board nor out with a party; a slot with none free stays
## empty and takes the first free one at a later call. A new slot fills at once without changing
## the others. Time is read from no earlier than `dispatch` last saw, so a clock set back never
## undoes a refill or restarts a countdown.
func refill(dispatch: Dispatch, now: int, quest_halls: int) -> void:
	var at := maxi(now, dispatch.checked_at)
	while slots.size() < QUESTS_A_REFRESH + quest_halls:
		slots.append("")
		refill_at.append(at)
	for i: int in slots.size():
		if slots[i] == "" and refill_at[i] <= at:
			slots[i] = _pick(i, dispatch)


## Sends `party` on `quest` through `dispatch`, empties its slot and starts that slot's countdown;
## false, with nothing sent, when the board at `now` doesn't show `quest` or `dispatch` refuses the
## party. The other arguments are as for `refill` and `Dispatch.send`.
func send(dispatch: Dispatch, quest: String, party: PackedStringArray, roll_seed: int, gold: Gold, now: int, quest_halls: int, infirmary_from: int = -1) -> bool:
	# A party back by now frees its quest for a slot refilling now.
	dispatch.checkpoint(now, gold, infirmary_from)
	refill(dispatch, now, quest_halls)
	var slot := slots.find(quest)
	if quest == "" or slot == -1:
		return false
	if not dispatch.send(quest, party, roll_seed, gold, now, infirmary_from):
		return false
	slots[slot] = ""
	refill_at[slot] = dispatch.checked_at + REFRESH_SECONDS
	return true


## Seconds from `now` until empty slot `slot` refills; 0 once due, while no quest is free.
func seconds_to_refill(slot: int, dispatch: Dispatch, now: int) -> int:
	return maxi(0, refill_at[slot] - maxi(now, dispatch.checked_at))


## Puts the board into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("board", "slots", slots)
	file.set_value("board", "refill_at", refill_at)


## The board saved at `path`, or one with no slots, which the first `refill` fills, when the save
## has none.
static func load_or_start(path: String) -> Board:
	var board := Board.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section_key("board", "slots"):
		return board
	board.slots = file.get_value("board", "slots")
	board.refill_at = file.get_value("board", "refill_at")
	return board


# A quest for slot `slot`, drawn from those free by a seed of the slot and its refill time, so the
# same save always refills the same way; "" when none is free.
func _pick(slot: int, dispatch: Dispatch) -> String:
	var taken := slots.duplicate()
	for outing: Dictionary in dispatch.outings:
		taken.append(outing["quest"])
	var free := PackedStringArray()
	for quest: String in Dispatch.QUESTS:
		if quest not in taken:
			free.append(quest)
	if free.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([slot, refill_at[slot]])
	return free[rng.randi_range(0, free.size() - 1)]
