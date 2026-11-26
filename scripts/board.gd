class_name Board
extends RefCounted

## How long a slot takes to refill after its quest is sent, by the rank of the quest sent from it:
## short for easy quests, longer for hard ones (stand-ins). A slot emptied once a Quest hall has
## reached FAST_REFILL_TIER refills in half that, rounded down (`refill_seconds`).
const REFILL_SECONDS: Dictionary[String, int] = {"F": 20, "E": 60, "D": 120, "C": 180}
const FAST_REFILL_TIER: int = 3
## How long a quest stays on the board once put there, by its rank, before it leaves unsent and its
## slot refills as after a send (stand-ins).
const EXPIRE_SECONDS: Dictionary[String, int] = {"F": 60, "E": 120, "D": 240, "C": 360}
## Once the guild has a Map room, each quest on the board has its unknown challenges revealed this
## long after the later of when it was put on the board and when the Map room reached its tier, by
## that tier, tier 1 first; a quest on the board when the room reaches a higher tier is revealed at
## the earlier of its old time and the new tier's (`_reveal_time`). More Map rooms don't speed it
## (stand-ins).
const MAP_REVEAL_SECONDS: Array[int] = [10, 5, 0]
## How a filling slot picks its quest's rank, by the guild's rank (Hall.rank): weights for one rank
## below it, its own and one above, so most of the board is at the guild's rank. No other rank is
## offered.
const RANK_WEIGHTS: Array[int] = [10, 70, 20]

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
## The unix seconds the guild's Map room reached each tier, as the last refill was told
## (Hall.tier_times); empty for none.
var _map_room_tiers: PackedInt64Array = PackedInt64Array()
## The same for its Quest hall.
var _quest_hall_tiers: PackedInt64Array = PackedInt64Array()


## How many slots hold a quest.
func filled() -> int:
	return slots.size() - slots.count("")


## Brings the board up to `now`: adds a slot for each time in `quest_halls_done` (Hall.added_at:
## when a Quest hall or its tier added it), due then, then, in the order their time comes, fills the
## empty slots and empties each slot whose quest has been on it EXPIRE_SECONDS for its rank, its refill then due
## `refill_seconds` for that rank later, as after a send; at the same second, quests leave before
## slots fill. Each slot is judged at its own time from saved timestamps alone, so refilling once
## after an absence gives the same board as refilling every second through it: it takes a quest
## neither on the board nor out with a party at that moment, or, with none free, the first freed
## after it, by a party's return or by leaving the board; only a quest at most one rank above the
## guild's highest-ranked party; and one whose rank is drawn by RANK_WEIGHTS around
## `guild_rank`, among the ranks with a quest free. Time is read from no earlier than `dispatch` or
## the board last saw, so a clock set back never undoes a refill, brings back a quest that left or
## restarts a countdown. A new board starts with every slot filled. With a Map room that reached
## its tiers at `map_room_tiers` (Hall.tier_times, empty for none), each quest still on the board at
## its reveal time (`_reveal_time`) has its unknown challenges revealed for good, all by `now`. A
## Quest hall's `quest_hall_tiers` (Hall.tier_times) speed refills (`refill_seconds`).
func refill(dispatch: Dispatch, now: int, quest_halls_done: PackedInt64Array, map_room_tiers: PackedInt64Array = PackedInt64Array(), quest_hall_tiers: PackedInt64Array = PackedInt64Array(), guild_rank: String = Hall.STARTING_RANK) -> void:
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
	_map_room_tiers = map_room_tiers
	_quest_hall_tiers = quest_hall_tiers
	# The ranks now stand for every refill due up to `at`: a rank changes only by a player action,
	# and whatever does that refills the board first, so fills due before it use the rank before it.
	var top := _top_rank(dispatch.adventurers)
	while true:
		var next := -1
		var next_time := 0
		for i: int in slots.size():
			var time := _leave_time(i) if slots[i] != "" else _fill_time(i, top, guild_rank)
			if time < 0 or time > at:
				continue
			# At the same second a quest leaving comes first, so a slot filling then can take it;
			# then slots fill in the order they came due.
			var first := next == -1 or time < next_time
			if not first and time == next_time and slots[next] == "":
				first = slots[i] != "" or refill_at[i] < refill_at[next]
			if first:
				next = i
				next_time = time
		if next == -1:
			break
		if slots[next] != "":
			# A quest is revealed only while on the board at its reveal time, before it leaves.
			var reveal := _reveal_time(next)
			if reveal >= 0 and reveal < next_time and not dispatch.unknown_challenges(slots[next]).is_empty():
				dispatch.revealed.append(slots[next])
			refill_at[next] = next_time + refill_seconds(Dispatch.QUESTS[slots[next]]["rank"], next_time)
			slots[next] = ""
		else:
			slots[next] = _pick(next, next_time, top, guild_rank)
			filled_at[next] = next_time
		# A slot filling after this can't fill before it, even with a quest free since earlier.
		checked_at = maxi(checked_at, next_time)
	checked_at = at
	# Every quest that left by `at` was revealed above if its time came first, and every send
	# refills first, so the quests on the board now have been there since their fill time:
	# revealing them here is the same as revealing each the moment its time came.
	for i: int in slots.size():
		if seconds_to_reveal(slots[i], dispatch, at) == 0:
			dispatch.revealed.append(slots[i])


## Replaces the board at `now` with a fresh one drawn from saved state alone, for an absence too
## long to step through: as a new board, every slot the Reception and the Quest halls finished by
## then give is filled at once by `refill`'s rules, with a quest neither on the board nor out, drawn
## by a seed of the slot and `now`. The arguments are as for `refill`.
func redraw(dispatch: Dispatch, now: int, quest_halls_done: PackedInt64Array, map_room_tiers: PackedInt64Array = PackedInt64Array(), quest_hall_tiers: PackedInt64Array = PackedInt64Array(), guild_rank: String = Hall.STARTING_RANK) -> void:
	checked_at = maxi(maxi(now, dispatch.checked_at), checked_at)
	slots.clear()
	refill_at.clear()
	filled_at.clear()
	refill(dispatch, now, quest_halls_done, map_room_tiers, quest_hall_tiers, guild_rank)


## Sends `party` on `quest` through `dispatch`, empties its slot and starts that slot's countdown;
## false, with nothing sent, when the board at `now` doesn't show `quest` or `dispatch` refuses the
## party. The other arguments are as for `refill` and `Dispatch.send`.
func send(dispatch: Dispatch, quest: String, party: PackedStringArray, roll_seed: int, now: int, quest_halls_done: PackedInt64Array, infirmary_tiers: PackedInt64Array = PackedInt64Array(), map_room_tiers: PackedInt64Array = PackedInt64Array(), quest_hall_tiers: PackedInt64Array = PackedInt64Array(), guild_rank: String = Hall.STARTING_RANK) -> bool:
	dispatch.checkpoint(now, infirmary_tiers)
	refill(dispatch, now, quest_halls_done, map_room_tiers, quest_hall_tiers, guild_rank)
	var slot := slots.find(quest)
	if quest == "" or slot == -1:
		return false
	if not dispatch.send(quest, party, roll_seed, now, infirmary_tiers):
		return false
	_note_outings(dispatch)
	slots[slot] = ""
	refill_at[slot] = dispatch.checked_at + refill_seconds(Dispatch.QUESTS[quest]["rank"], dispatch.checked_at)
	return true


## How long a slot emptied at `at` of a quest of `rank` takes to refill: REFILL_SECONDS, halved,
## rounded down, once the Quest hall has reached FAST_REFILL_TIER, as the last refill was told.
func refill_seconds(rank: String, at: int) -> int:
	var fast_from := fast_refill_from(_quest_hall_tiers)
	return slot_refill_seconds(rank, fast_from >= 0 and fast_from <= at)


## How long a slot emptied of a quest of `rank` takes to refill: REFILL_SECONDS, or half of it,
## rounded down, when `fast`.
static func slot_refill_seconds(rank: String, fast: bool) -> int:
	return REFILL_SECONDS[rank] / 2 if fast else REFILL_SECONDS[rank]


## The unix seconds slots start refilling twice as fast, for a Quest hall that reached its tiers at
## `quest_hall_tiers` (Hall.tier_times): when it reached FAST_REFILL_TIER; -1 when it hasn't.
static func fast_refill_from(quest_hall_tiers: PackedInt64Array) -> int:
	return quest_hall_tiers[FAST_REFILL_TIER - 1] if quest_hall_tiers.size() >= FAST_REFILL_TIER else -1


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


## Seconds from `now` until `quest` leaves the board unsent; -1 when it is not on the board.
func seconds_to_leave(quest: String, dispatch: Dispatch, now: int) -> int:
	var slot := slots.find(quest)
	if quest == "" or slot == -1:
		return -1
	return maxi(0, _leave_time(slot) - maxi(maxi(now, dispatch.checked_at), checked_at))


## Seconds from `now` until the Map room reveals `quest`'s unknown challenges; 0 once due, -1 when
## no reveal is coming: no Map room finished by then as the last refill was told, `quest` not on the
## board, or nothing about it unknown.
func seconds_to_reveal(quest: String, dispatch: Dispatch, now: int) -> int:
	var slot := slots.find(quest)
	var at := maxi(maxi(now, dispatch.checked_at), checked_at)
	if quest == "" or slot == -1 or _map_room_tiers.is_empty() or _map_room_tiers[0] > at or dispatch.unknown_challenges(quest).is_empty():
		return -1
	return maxi(0, _reveal_time(slot) - at)


## The soonest unix seconds after `now` at which the board may change by time alone, as the last
## refill left it: a quest leaving, a slot's countdown ending or the Map room revealing a quest; -1
## when none is coming. A slot due with no quest free fills at a party's return instead, which
## whoever asks knows of.
func next_change(dispatch: Dispatch, now: int) -> int:
	var at := maxi(maxi(now, dispatch.checked_at), checked_at)
	var soonest := -1
	for slot: int in slots.size():
		var times: Array[int] = [refill_at[slot]]
		if slots[slot] != "":
			times = [_leave_time(slot)]
			if not dispatch.unknown_challenges(slots[slot]).is_empty():
				times.append(_reveal_time(slot))
		for time: int in times:
			if time > at and (soonest == -1 or time < soonest):
				soonest = time
	return soonest


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


# When the quest in filled slot `slot` leaves the board unsent.
func _leave_time(slot: int) -> int:
	return filled_at[slot] + EXPIRE_SECONDS[Dispatch.QUESTS[slots[slot]]["rank"]]


# When the Map room reveals the quest in filled slot `slot`, as the last refill was told of it: the
# soonest, over the tiers it has reached or will, of the later of the fill time and the tier's time,
# plus that tier's MAP_REVEAL_SECONDS; -1 with no Map room.
func _reveal_time(slot: int) -> int:
	var soonest := -1
	for index: int in _map_room_tiers.size():
		var time := maxi(filled_at[slot], _map_room_tiers[index]) + MAP_REVEAL_SECONDS[index]
		if soonest == -1 or time < soonest:
			soonest = time
	return soonest


# The highest rank of `adventurers`' parties (Parties.rank), only parties going on quests; F with no
# party.
static func _top_rank(adventurers: Adventurers) -> String:
	var top := 0
	for party: Dictionary in adventurers.parties.parties:
		top = maxi(top, Challenges.RANKS.find(adventurers.parties.rank(party["id"], adventurers.roster)))
	return Challenges.RANKS[top]


# When empty slot `slot` fills, for a guild of `guild_rank` whose highest-ranked party is
# `top`: its refill time, or no earlier than the board was last refilled to, as it found nothing
# free before then; else the first party's return after that frees a quest. -1 when the slot is
# filled or no return to come frees one. A quest leaving the board frees one too, which `refill`
# handles as a time of its own.
func _fill_time(slot: int, top: String, guild_rank: String) -> int:
	if slots[slot] != "":
		return -1
	var from := maxi(refill_at[slot], checked_at)
	var times: Array[int] = [from]
	for back: int in back_at.values():
		if back > from:
			times.append(back)
	times.sort()
	for time: int in times:
		if not _free(time, top, guild_rank).is_empty():
			return time
	return -1


# The quests neither on the board nor out at `time` that a guild of `guild_rank` whose
# highest-ranked party is `top` can be offered: no story quest (Dispatch.is_story), floor
# (Dispatch.is_floor) or elite (Dispatch.is_elite), of a rank
# RANK_WEIGHTS weighs, and one that party can take (Challenges.can_join). In Dispatch.QUESTS order.
func _free(time: int, top: String, guild_rank: String) -> PackedStringArray:
	var free := PackedStringArray()
	for quest: String in Dispatch.QUESTS:
		var rank: String = Dispatch.QUESTS[quest]["rank"]
		if not Dispatch.is_story(quest) and not Dispatch.is_floor(quest) and not Dispatch.is_elite(quest) and quest not in slots and back_at.get(quest, 0) <= time and _weight_index(rank, guild_rank) != -1 and Challenges.can_join(top, rank):
			free.append(quest)
	return free


## The chance that a slot filling for `adventurers`' guild, of `guild_rank`, draws `quest` while
## every quest is free: its rank's share of RANK_WEIGHTS among the ranks offered, split evenly among
## that rank's quests (as `_pick` draws). 0 for a quest the board doesn't offer the guild, a story
## quest, a floor or an elite among them.
static func draw_chance(quest: String, adventurers: Adventurers, guild_rank: String) -> float:
	if Dispatch.is_story(quest) or Dispatch.is_floor(quest) or Dispatch.is_elite(quest):
		return 0.0
	var top := _top_rank(adventurers)
	var rank: String = Dispatch.QUESTS[quest]["rank"]
	var weights := {}
	var same_rank := 0
	for each: String in Dispatch.QUESTS:
		var each_rank: String = Dispatch.QUESTS[each]["rank"]
		var index := _weight_index(each_rank, guild_rank)
		if not Dispatch.is_story(each) and not Dispatch.is_floor(each) and not Dispatch.is_elite(each) and index != -1 and Challenges.can_join(top, each_rank):
			weights[each_rank] = RANK_WEIGHTS[index]
			same_rank += 1 if each_rank == rank else 0
	if same_rank == 0:
		return 0.0
	var total := 0
	for weight: int in weights.values():
		total += weight
	return weights[rank] / float(total) / same_rank


# Where `rank` is in RANK_WEIGHTS for a guild of `guild_rank`; -1 when it is not weighed.
static func _weight_index(rank: String, guild_rank: String) -> int:
	var index := Challenges.RANKS.find(rank) - Challenges.RANKS.find(guild_rank) + 1
	return index if index >= 0 and index < RANK_WEIGHTS.size() else -1


# A quest for `slot` from those free at `time`, as `_free` has them: first a rank, by RANK_WEIGHTS
# among the ranks with a quest free, then one of that rank's, each as likely. Drawn by a seed of the
# slot and its refill time, so the same save always refills the same way.
func _pick(slot: int, time: int, top: String, guild_rank: String) -> String:
	var by_rank: Array[Array] = []
	for index: int in RANK_WEIGHTS.size():
		by_rank.append([])
	for quest: String in _free(time, top, guild_rank):
		by_rank[_weight_index(Dispatch.QUESTS[quest]["rank"], guild_rank)].append(quest)
	var total := 0
	for index: int in RANK_WEIGHTS.size():
		if not by_rank[index].is_empty():
			total += RANK_WEIGHTS[index]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([slot, refill_at[slot]])
	var roll := rng.randi_range(1, total)
	for index: int in RANK_WEIGHTS.size():
		if by_rank[index].is_empty():
			continue
		roll -= RANK_WEIGHTS[index]
		if roll <= 0:
			return by_rank[index][rng.randi_range(0, by_rank[index].size() - 1)]
	return ""
