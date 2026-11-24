class_name Auto
extends RefCounted

## Parties with Auto on (Parties.auto) keep questing by themselves. Such a party is ready the moment
## every member is home, at full health, not injured, not training and has no loot waiting; then it
## takes the board quest its rank allows that pays the most gold among those whose shown chance's low
## end (Dispatch.chance_range) is at least LOWEST_LOW_END for its mode, ties going to the higher low
## end, then the earlier slot. With none, it waits and tries again whenever the board changes or it
## is ready again. It all happens in `checkpoint`, from saved timestamps alone: the last
## REPLAY_SECONDS of an absence give the same as watching, and anything before them is settled by
## averages, so a long absence stays quick.

## The lowest low end of a quest's shown chance, in whole percent, a party with Auto on takes, by its
## mode (Parties.mode).
const LOWEST_LOW_END: Dictionary[String, int] = {Parties.SAFE: 70, Parties.BOLD: 40}
## How much of an absence, up to its end, is played out exactly; what comes before is settled by
## averages (`_average`) (stand-in).
const REPLAY_SECONDS: int = 3 * 3_600


## Brings `dispatch` and `board` up to `now`. An absence longer than REPLAY_SECONDS is first settled
## up to REPLAY_SECONDS before `now` (`_settle`). The rest is played out in time order: each party's
## return (Dispatch.checkpoint), each refill, quest leaving and reveal (Board.refill), and at each of
## those moments and each moment an Auto party becomes ready, the sends of the Auto parties ready
## then, in party order, a quest taken by one gone for the next. Each Auto send's outcome is fixed by
## a seed of the party, the quest and the time it leaves, never the global generator, so the same
## save always plays out the same way. Checkpointing once after an absence of up to REPLAY_SECONDS
## gives the same as checkpointing every second through it. The other arguments are as for
## Board.refill and Dispatch.checkpoint.
static func checkpoint(dispatch: Dispatch, board: Board, now: int, quest_halls_done: PackedInt64Array, infirmary_from: int = -1, map_room_from: int = -1, guild_rank: String = Hall.STARTING_RANK) -> void:
	var at := maxi(now, dispatch.checked_at)
	if at - REPLAY_SECONDS > dispatch.checked_at:
		_settle(dispatch, board, at - REPLAY_SECONDS, quest_halls_done, infirmary_from, map_room_from, guild_rank)
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
		# With no Auto party left to go, nothing more is sent, and the board refills to `at` at once.
		var next := _next_change(dispatch, board, time) if _may_send(dispatch, time) else at
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


# Whether an Auto party may still go by time alone: one home that only heals, or one out.
static func _may_send(dispatch: Dispatch, now: int) -> bool:
	var parties := dispatch.adventurers.parties
	for party: Dictionary in parties.parties:
		var out := not dispatch.quest_of(party["members"][0]).is_empty()
		if parties.auto(party["id"]) and (out or seconds_to_ready(dispatch, party["id"], now) >= 0):
			return true
	return false


# Brings `dispatch` and `board` up to `to` with no Auto send: parties out come home as their quests
# decide, at their own time; each Auto party's questing from its first ready moment on is settled by
# `_average`; and the board, with nothing sent, refills to `to` at once. The other arguments are as
# for `checkpoint`.
static func _settle(dispatch: Dispatch, board: Board, to: int, quest_halls_done: PackedInt64Array, infirmary_from: int, map_room_from: int, guild_rank: String) -> void:
	var parties := dispatch.adventurers.parties
	var ready_at: Dictionary[String, int] = {}
	var time := dispatch.checked_at
	# The board learns when the quests out come back before their parties are home.
	board.refill(dispatch, time, quest_halls_done, map_room_from, guild_rank)
	while true:
		dispatch.checkpoint(time, infirmary_from)
		for party: Dictionary in parties.parties:
			var id: String = party["id"]
			if not parties.auto(id) or ready_at.has(id):
				continue
			var left := seconds_to_ready(dispatch, id, time)
			if left >= 0 and time + left <= to:
				ready_at[id] = time + left
		var next := -1
		for outing: Dictionary in dispatch.outings:
			var back := dispatch.back_at(outing)
			if back <= to and (next == -1 or back < next):
				next = back
		if next == -1:
			break
		time = next
	dispatch.checkpoint(to, infirmary_from)
	_average(dispatch, ready_at, to, infirmary_from, guild_rank)
	board.refill(dispatch, to, quest_halls_done, map_room_from, guild_rank)


# Settles, by expected values, the questing of each party in `ready_at`, from the unix seconds it is
# first ready there up to `to`, in a guild of `guild_rank` whose first Infirmary is finished at
# `infirmary_from` (-1 for none). Each party takes as many average cycles (`_cycle`) as fit, healing
# twice as fast from the Infirmary on; it earns their gold and each member their XP, and adds their
# tries, revealing the quests tried. Its loot is the expected number of items, each drawn by a seed
# of the party, its first ready moment and the cycle, put into the stash in time order across parties
# until it is full; the first that doesn't fit waits for the player and ends that party's questing
# from that cycle on. The averages deal no damage, so its members, ready when they began, end home,
# at full health and uninjured; nobody is injured, dies or levels up in them.
static func _average(dispatch: Dispatch, ready_at: Dictionary[String, int], to: int, infirmary_from: int, guild_rank: String) -> void:
	var plans: Array[Dictionary] = []
	for id: String in ready_at:
		var plan := _cycle(dispatch, id, guild_rank)
		if plan.is_empty():
			continue
		var start: int = ready_at[id]
		var fast_from := to if infirmary_from < 0 else clampi(infirmary_from, start, to)
		plan["id"] = id
		plan["start"] = start
		plan["cycles"] = (fast_from - start) / plan["seconds"] + (to - fast_from) / plan["fast_seconds"]
		plans.append(plan)
	var gear := dispatch.adventurers.gear
	# However the drops fall, no party's drop after the stash's room plus one is ever reached.
	var room := maxi(0, gear.stash_cap - gear.stash.size())
	# Each drop as [unix seconds, index in plans, cycle].
	var drops: Array[Array] = []
	for index: int in plans.size():
		var plan := plans[index]
		var cycles: float = plan["cycles"]
		var per_cycle: float = plan["drops"]
		for drop: int in range(1, mini(roundi(cycles * per_cycle), room + 1) + 1):
			var cycle := mini(ceili(drop / per_cycle), ceili(cycles))
			drops.append([plan["start"] + roundi(cycle * (to - plan["start"]) / cycles), index, cycle])
	drops.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for drop: Array in drops:
		var plan := plans[drop[1]]
		if plan.has("stopped"):
			continue
		var item := Gear.loot_item(hash([plan["id"], plan["start"], drop[2]]), plan["luck"])
		if not gear.stow(item):
			dispatch.waiting_loot.append({"quest": plan["quest"], "party": plan["members"], "item": item})
			plan["cycles"] = float(drop[2])
			plan["stopped"] = true
	for plan: Dictionary in plans:
		var cycles: float = plan["cycles"]
		dispatch.gold.amount += roundi(cycles * plan["gold"])
		for member: String in plan["members"]:
			dispatch.adventurers.gain_xp(member, roundi(cycles * plan["xp"]))
		var share: Dictionary = plan["share"]
		for quest: String in share:
			var tried := roundi(cycles * share[quest])
			if tried > 0:
				dispatch.tries[quest] = int(dispatch.tries.get(quest, 0)) + tried
				if not dispatch.unknown_challenges(quest).is_empty():
					dispatch.revealed.append(quest)


# The average cycle of the party with `id` with Auto on, in a guild of `guild_rank`: it takes one of
# the quests its rank allows that the board offers (Board.offered_quests), among those whose shown
# chance's low end its mode takes, each as likely as the board draws it, then heals back to full from
# that quest's expected damage. {} when no quest will do; else {"members", "luck": the party's,
# "seconds": the cycle's expected length, "fast_seconds": the same with the Infirmary's healing,
# "gold", "xp": each member's, "drops": items, all expected per cycle, "share": {quest: its part of
# the cycles}, "quest": the likeliest}.
static func _cycle(dispatch: Dispatch, id: String, guild_rank: String) -> Dictionary:
	var parties := dispatch.adventurers.parties
	var members: PackedStringArray = parties.party(id)["members"]
	var offered := Board.offered_quests(parties.rank(id, dispatch.adventurers.roster), guild_rank)
	var share := {}
	var total := 0.0
	for index: int in offered.size():
		for quest: String in offered[index]:
			if dispatch.chance_range(quest, members).x >= LOWEST_LOW_END[parties.mode(id)]:
				# A rank is drawn by its weight, then each of its quests as likely.
				share[quest] = Board.RANK_WEIGHTS[index] / float(offered[index].size())
				total += share[quest]
	if share.is_empty():
		return {}
	var spirit := dispatch.party_stat(members, "spirit")
	var luck := dispatch.party_stat(members, "luck")
	var cycle := {"members": members, "luck": luck, "seconds": 0.0, "fast_seconds": 0.0, "gold": 0.0, "xp": 0.0, "drops": 0.0, "share": share, "quest": ""}
	for quest: String in share:
		share[quest] /= total
		var part: float = share[quest]
		var info: Dictionary = Dispatch.QUESTS[quest]
		var chance := dispatch.success_chance(quest, members) / 100.0
		var heal := _expected_damage(chance, Outcome.MOST_DAMAGE[info["rank"]], spirit, luck) * Dispatch.HEAL_SECONDS / Dispatch.HEAL_POINTS
		cycle["seconds"] += part * (info["seconds"] + heal)
		cycle["fast_seconds"] += part * (info["seconds"] + heal / 2.0)
		cycle["gold"] += part * (chance * info["gold"] + (1.0 - chance) * Dispatch.failure_gold(quest))
		cycle["xp"] += part * (chance * Dispatch.xp_share(info["xp"], true, members.size()) + (1.0 - chance) * Dispatch.xp_share(info["xp"], false, members.size()))
		cycle["drops"] += part * Gear.loot_percent(info["rank"], luck) / 100.0
		if cycle["quest"] == "" or part > share[cycle["quest"]]:
			cycle["quest"] = quest
	return cycle


# The damage each member of a party with `spirit` and `luck` in all can expect from a quest that
# deals at most `most`, succeeding at `chance` (0 to 1), as Outcome.roll deals it.
static func _expected_damage(chance: float, most: int, spirit: int, luck: int) -> float:
	var half := floori(most / 2.0)
	var kept := (100 - mini(Outcome.MOST_SPIRIT_CUT, Outcome.SPIRIT_CUT_PER_POINT * spirit)) / 100.0
	var failure_kept := kept * (100 - mini(Outcome.MOST_LUCK_CUT, Outcome.LUCK_CUT_PER_POINT * luck)) / 100.0
	return chance * half / 2.0 * kept + (1.0 - chance) * (half + most) / 2.0 * failure_kept
