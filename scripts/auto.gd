class_name Auto
extends RefCounted

## Parties with Auto on (Parties.auto) keep questing by themselves. Such a party is ready the moment
## every member is home, at full health, not injured, not training and has no loot waiting; then it
## takes the board quest its rank allows that pays the most gold among those whose shown chance's low
## end (Dispatch.chance_range) is at least LOWEST_LOW_END for its mode, ties going to the higher low
## end, then the earlier slot. With none, it waits and tries again whenever the board changes or it
## is ready again. It all happens in `checkpoint`, from saved timestamps alone, so being away gives
## the same as watching.

## The lowest low end of a quest's shown chance, in whole percent, a party with Auto on takes, by its
## mode (Parties.mode).
const LOWEST_LOW_END: Dictionary[String, int] = {Parties.SAFE: 70, Parties.BOLD: 40}


## Brings `dispatch` and `board` up to `now` in time order: each party's return (Dispatch.checkpoint),
## each refill, quest leaving and reveal (Board.refill), and at each of those moments and each
## moment an Auto party becomes ready, the sends of the Auto parties ready then, in party order, a
## quest taken by one gone for the next. Each Auto send's outcome is fixed by a seed of the party, the
## quest and the time it leaves, never the global generator, so the same save always plays out the
## same way. Checkpointing once after an absence gives the same as checkpointing every second
## through it. The other arguments are as for Board.refill and Dispatch.checkpoint.
static func checkpoint(dispatch: Dispatch, board: Board, now: int, quest_halls_done: PackedInt64Array, infirmary_from: int = -1, map_room_from: int = -1, guild_rank: String = Hall.STARTING_RANK) -> void:
	var at := maxi(now, dispatch.checked_at)
	var time := dispatch.checked_at
	while true:
		dispatch.checkpoint(time, infirmary_from)
		board.refill(dispatch, time, quest_halls_done, map_room_from, guild_rank)
		var parties := dispatch.adventurers.parties
		for party: Dictionary in parties.parties:
			var id: String = party["id"]
			if not parties.auto(id) or seconds_to_ready(dispatch, id, time) != 0:
				continue
			var quest := pick(dispatch, board, id, time)
			if not quest.is_empty():
				board.send(dispatch, quest, party["members"], hash([id, quest, time]), time, quest_halls_done, infirmary_from, map_room_from, guild_rank)
		if time >= at:
			return
		var next := _next_change(dispatch, board, time)
		time = at if next == -1 or next > at else next


## Seconds from `now` until the party with `id` is ready, as for an Auto party, whether its Auto is on
## or not: 0 when ready; the longest of its members' healing and injuries while that is all it waits
## on; -1 while anyone is out, training or has loot waiting, which time alone doesn't end.
static func seconds_to_ready(dispatch: Dispatch, id: String, now: int) -> int:
	var left := 0
	for adventurer: String in dispatch.adventurers.parties.party(id)["members"]:
		if not dispatch.quest_of(adventurer).is_empty() or dispatch.loot_waiting(adventurer) or dispatch.training.has(adventurer):
			return -1
		left = maxi(left, maxi(dispatch.seconds_to_full(adventurer, now), dispatch.injury_left(adventurer, now)))
	return left


## The quest on `board` the party with `id` takes at `now` with Auto, as its mode has it; "" for none.
static func pick(dispatch: Dispatch, board: Board, id: String, now: int) -> String:
	var parties := dispatch.adventurers.parties
	var members: PackedStringArray = parties.party(id)["members"]
	var lowest: int = LOWEST_LOW_END[parties.mode(id)]
	var picked := ""
	var picked_gold := 0
	var picked_low := 0
	for quest: String in board.slots:
		if quest.is_empty() or not dispatch.party_refusal(quest, members, now).is_empty():
			continue
		var low := dispatch.chance_range(quest, members).x
		var gold: int = Dispatch.QUESTS[quest]["gold"]
		# Strictly better only, so a tie goes to the earlier slot.
		if low >= lowest and (picked.is_empty() or gold > picked_gold or (gold == picked_gold and low > picked_low)):
			picked = quest
			picked_gold = gold
			picked_low = low
	return picked


# The soonest unix seconds after `now` at which anything an Auto party's pick depends on may change by
# time alone: a party's return, the board changing, or an Auto party becoming ready. -1 for none.
static func _next_change(dispatch: Dispatch, board: Board, now: int) -> int:
	var times: Array[int] = [board.next_change(dispatch, now)]
	for outing: Dictionary in dispatch.outings:
		times.append(dispatch.back_at(outing))
	var parties := dispatch.adventurers.parties
	for party: Dictionary in parties.parties:
		var left := seconds_to_ready(dispatch, party["id"], now)
		if parties.auto(party["id"]) and left > 0:
			times.append(now + left)
	var soonest := -1
	for time: int in times:
		if time > now and (soonest == -1 or time < soonest):
			soonest = time
	return soonest
