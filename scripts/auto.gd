class_name Auto
extends RefCounted

## Parties with Auto on (Parties.auto) keep questing by themselves. Such a party is ready the moment
## every member is home, at full health, not injured, not training and has no loot waiting; then it
## takes the board quest its rank allows that pays the most gold among those whose shown chance's low
## end (Dispatch.chance_range) is at least LOWEST_LOW_END for its mode, ties going to the higher low
## end, then the earlier slot. With none, it waits and tries again whenever the board changes or it
## is ready again. It all happens in `checkpoint`, from saved timestamps alone: the last
## REPLAY_SECONDS of an absence give the same as watching, and anything before them is settled by
## averages that track what playing gives, and the board drawn afresh, so a long absence stays
## quick.

## The lowest low end of a quest's shown chance, in whole percent, a party with Auto on takes, by its
## mode (Parties.mode).
const LOWEST_LOW_END: Dictionary[String, int] = {Parties.SAFE: 70, Parties.BOLD: 40}
## How much of an absence, up to its end, is played out exactly; what comes before is settled by
## averages (`_average`) (stand-in).
const REPLAY_SECONDS: int = 3 * 3_600


## Brings `dispatch` and `board` up to `now`. An absence longer than REPLAY_SECONDS is first settled
## up to REPLAY_SECONDS before `now` (`_settle`), with or without Auto parties. The rest is played
## out in time order: each party's
## return (Dispatch.checkpoint), each refill, quest leaving and reveal (Board.refill), and at each of
## those moments and each moment an Auto party becomes ready, the sends of the Auto parties ready
## then, in party order, a quest taken by one gone for the next. Each Auto send's outcome is fixed by
## a seed of the party, the quest and the time it leaves, never the global generator, so the same
## save always plays out the same way. Checkpointing once after an absence of up to REPLAY_SECONDS
## gives the same as checkpointing every second through it. Until the guild has unlocked Auto
## (`unlocked` false, see Goals), no party goes by itself, exactly or averaged, whatever its Auto. The
## other arguments are as for Board.send.
static func checkpoint(dispatch: Dispatch, board: Board, now: int, quest_halls_done: PackedInt64Array, infirmary_tiers: PackedInt64Array = PackedInt64Array(), map_room_tiers: PackedInt64Array = PackedInt64Array(), quest_hall_tiers: PackedInt64Array = PackedInt64Array(), guild_rank: String = Hall.STARTING_RANK, unlocked: bool = true) -> void:
	var at := maxi(now, dispatch.checked_at)
	if at - REPLAY_SECONDS > dispatch.checked_at:
		_settle(dispatch, board, at - REPLAY_SECONDS, quest_halls_done, infirmary_tiers, map_room_tiers, quest_hall_tiers, guild_rank, unlocked)
	var time := dispatch.checked_at
	while true:
		dispatch.checkpoint(time, infirmary_tiers)
		board.refill(dispatch, time, quest_halls_done, map_room_tiers, quest_hall_tiers, guild_rank)
		var parties := dispatch.adventurers.parties
		for party: Dictionary in parties.parties:
			var id: String = party["id"]
			if not unlocked or not parties.auto(id) or seconds_to_ready(dispatch, id, time) != 0:
				continue
			var quest := pick(dispatch, board, id, time)
			if not quest.is_empty():
				board.send(dispatch, quest, party["members"], hash([id, quest, time]), time, quest_halls_done, infirmary_tiers, map_room_tiers, quest_hall_tiers, guild_rank)
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


# Brings `dispatch` and `board` up to `to` with no Auto send: parties out come home as their quests
# decide, at their own time; each Auto party's questing from its first ready moment on is settled by
# `_average`, while Auto is `unlocked`, with the slower refill up to the moment the Quest hall
# reaches Board.FAST_REFILL_TIER and the faster from then on; and the board is drawn afresh at `to`
# (Board.redraw). The other arguments are as for `checkpoint`.
static func _settle(dispatch: Dispatch, board: Board, to: int, quest_halls_done: PackedInt64Array, infirmary_tiers: PackedInt64Array, map_room_tiers: PackedInt64Array, quest_hall_tiers: PackedInt64Array, guild_rank: String, unlocked: bool) -> void:
	var parties := dispatch.adventurers.parties
	var ready_at: Dictionary[String, int] = {}
	var time := dispatch.checked_at
	while true:
		dispatch.checkpoint(time, infirmary_tiers)
		for party: Dictionary in parties.parties:
			var id: String = party["id"]
			if not unlocked or not parties.auto(id) or ready_at.has(id):
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
	dispatch.checkpoint(to, infirmary_tiers)
	var slots := board.reception_slots + quest_halls_done.size()
	var fast_from := Board.fast_refill_from(quest_hall_tiers)
	if fast_from < 0 or fast_from >= to:
		_average(dispatch, slots, ready_at, to, infirmary_tiers, guild_rank, false)
	else:
		_average(dispatch, slots, ready_at, fast_from, infirmary_tiers, guild_rank, false)
		# Questing on from then, but for a party its loot now waits on.
		var ready_later: Dictionary[String, int] = {}
		for id: String in ready_at:
			if seconds_to_ready(dispatch, id, to) >= 0:
				ready_later[id] = maxi(ready_at[id], fast_from)
		_average(dispatch, slots, ready_later, to, infirmary_tiers, guild_rank, true)
	board.redraw(dispatch, to, quest_halls_done, map_room_tiers, quest_hall_tiers, guild_rank)


# Settles, by expected values, the questing of each party in `ready_at`, from the unix seconds it is
# first ready there up to `to`, with a board of `slots` slots refilling twice as fast when
# `fast_refill`, in a guild of `guild_rank` whose Infirmary reached its tiers at `infirmary_tiers`
# (Hall.tier_times). In party order, each party takes its part of what the board offers (`_offered`)
# of the quests it would take (`_takes`): a cycle is a quest and the healing after it (faster from
# each Infirmary tier on, Dispatch.INFIRMARY_HEAL_RATES), then a wait for the next such quest to
# come up. It takes each quest as often as it comes up, and what it takes is gone for the parties
# after it. Quests taken count as learned (`_takes`). It earns the cycles' gold, the guild their
# expected reputation rounded down (never taking it below 0), and each member their XP, each cycle's
# as the Kitchen's tier then has it (Dispatch.kitchen_tiers), and their expected successes by quest
# rank, each rounded down, and adds their tries,
# revealing the quests tried. Its loot is the expected number of items, each drawn by a seed of the
# party, its first ready moment and the cycle, put into the stash in time order across parties until
# it is full; the first that doesn't fit waits for the player and ends that party's questing from
# that cycle on. The averages deal no damage, so its
# members, ready when they began, end home, at full health and uninjured; nobody is injured, dies or
# levels up in them.
static func _average(dispatch: Dispatch, slots: int, ready_at: Dictionary[String, int], to: int, infirmary_tiers: PackedInt64Array, guild_rank: String, fast_refill: bool) -> void:
	var parties := dispatch.adventurers.parties
	var takes := {}
	var taken := {}
	# A quest some party takes is soon learned, its challenges known and its tries counted in full,
	# which can change what the parties take: worked out again a few times over.
	for again: int in 3:
		var learned := taken
		taken = {}
		for id: String in ready_at:
			takes[id] = _takes(dispatch, id, guild_rank, learned)
			taken.merge(takes[id])
	var offered := _offered(dispatch, slots, taken, guild_rank, fast_refill)
	var plans: Array[Dictionary] = []
	for party: Dictionary in parties.parties:
		var id: String = party["id"]
		if not takes.has(id):
			continue
		var take: Dictionary = takes[id]
		var start: int = ready_at[id]
		# How many quests it would take come up a second.
		var rate := 0.0
		for quest: String in take:
			rate += offered.get(quest, 0.0)
		if rate == 0.0 or start >= to:
			continue
		# A cycle is a try, then a wait for the next quest it would take to come up: over each span
		# between Infirmary and Kitchen tiers, the seconds a try takes on average, as they come up,
		# healing at that span's rate; and how many of the cycles fall at each Kitchen tier.
		var cycles := 0.0
		var kitchen_cycles: Array[float] = []
		kitchen_cycles.resize(Dispatch.KITCHEN_XP_PERCENT.size() + 1)
		kitchen_cycles.fill(0.0)
		var breaks: Array[int] = []
		for time: int in infirmary_tiers + dispatch.kitchen_tiers:
			breaks.append(time)
		breaks.sort()
		breaks.append(to)
		var since := start
		for at: int in breaks:
			var until := clampi(at, since, to)
			var infirmary := Dispatch.tier_at(infirmary_tiers, since)
			var heal_rate: int = 1 if infirmary == 0 else Dispatch.INFIRMARY_HEAL_RATES[infirmary - 1]
			var seconds := 0.0
			for quest: String in take:
				seconds += offered.get(quest, 0.0) * (take[quest]["seconds"] + take[quest]["heal"] / heal_rate)
			var span := (until - since) / (seconds / rate + 1.0 / rate)
			cycles += span
			kitchen_cycles[Dispatch.tier_at(dispatch.kitchen_tiers, since)] += span
			since = until
		var plan := {"id": id, "start": start, "members": party["members"], "luck": dispatch.party_stat(party["members"], "luck"), "cycles": cycles, "share": {}, "quest": "", "gold": 0.0, "xp": 0.0, "drops": 0.0, "reputation": 0.0, "successes": {}}
		var share: Dictionary = plan["share"]
		# It takes each quest as often as it comes up, and what it takes is gone for the parties
		# after it.
		var used := cycles / (to - start) / rate
		# A cycle's XP at each Kitchen tier.
		var xp_by_tier: Array[float] = []
		xp_by_tier.resize(kitchen_cycles.size())
		xp_by_tier.fill(0.0)
		for quest: String in take:
			var each: float = offered.get(quest, 0.0)
			if each == 0.0:
				continue
			offered[quest] = each * (1.0 - used)
			share[quest] = each / rate
			for key: String in ["gold", "drops", "reputation"]:
				plan[key] += share[quest] * take[quest][key]
			for tier: int in xp_by_tier.size():
				xp_by_tier[tier] += share[quest] * take[quest]["xp"][tier]
			var rank: String = Dispatch.QUESTS[quest]["rank"]
			plan["successes"][rank] = plan["successes"].get(rank, 0.0) + share[quest] * take[quest]["chance"]
			if plan["quest"] == "" or share[quest] > share[plan["quest"]]:
				plan["quest"] = quest
		# Each cycle's XP is as the Kitchen's tier then has it, averaged over the cycles.
		for tier: int in xp_by_tier.size():
			plan["xp"] += kitchen_cycles[tier] / cycles * xp_by_tier[tier]
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
		dispatch.reputation = maxi(0, dispatch.reputation + floori(cycles * plan["reputation"]))
		for member: String in plan["members"]:
			dispatch.adventurers.gain_xp(member, roundi(cycles * plan["xp"]))
			for rank: String in plan["successes"]:
				dispatch.adventurers.add_successes(member, rank, floori(cycles * plan["successes"][rank]))
		var share: Dictionary = plan["share"]
		for quest: String in share:
			var tried := roundi(cycles * share[quest])
			if tried > 0:
				dispatch.tries[quest] = int(dispatch.tries.get(quest, 0)) + tried
				if not dispatch.unknown_challenges(quest).is_empty():
					dispatch.revealed.append(quest)


# The quests the party with `id` would take with Auto in a guild of `guild_rank`: those the board
# offers that its rank allows and whose shown chance's low end its mode takes, each quest in
# `learned` counted with its challenges known and the most try points (Dispatch.MOST_TRY_POINTS).
# Each with what a try at it can be expected to bring: {"seconds": the quest's, "heal": the healing
# back to full from its expected damage with no Infirmary, in seconds, "gold", "xp": each member's
# by the Kitchen's tier, none first (Dispatch.xp_share), "drops": items, "reputation": the guild's
# (Dispatch.REPUTATION), "chance": of success, 0 to 1}.
static func _takes(dispatch: Dispatch, id: String, guild_rank: String, learned: Dictionary) -> Dictionary:
	var parties := dispatch.adventurers.parties
	var members: PackedStringArray = parties.party(id)["members"]
	var party_rank := parties.rank(id, dispatch.adventurers.roster)
	var spirit := dispatch.party_stat(members, "spirit")
	var luck := dispatch.party_stat(members, "luck")
	var takes := {}
	for quest: String in Dispatch.QUESTS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		if Board.draw_chance(quest, dispatch.adventurers, guild_rank) == 0.0 or not Challenges.can_join(party_rank, info["rank"]):
			continue
		var low := dispatch.chance_range(quest, members).x
		var percent := dispatch.success_chance(quest, members)
		if learned.has(quest):
			var challenges := dispatch.challenge_chances(quest, members)
			low = Outcome.chance_range(challenges, 0, Dispatch.MOST_TRY_POINTS).x
			percent = Outcome.chance_percent(challenges, Dispatch.MOST_TRY_POINTS)
		if low < LOWEST_LOW_END[parties.mode(id)]:
			continue
		var chance := percent / 100.0
		var heal := _expected_damage(chance, Outcome.MOST_DAMAGE[info["rank"]], spirit, luck) * Dispatch.HEAL_SECONDS / Dispatch.HEAL_POINTS
		var xp: Array[float] = []
		for kitchen: int in Dispatch.KITCHEN_XP_PERCENT.size() + 1:
			xp.append(chance * Dispatch.xp_share(info["xp"], true, members.size(), kitchen) + (1.0 - chance) * Dispatch.xp_share(info["xp"], false, members.size(), kitchen))
		takes[quest] = {
			"seconds": info["seconds"],
			"heal": heal,
			"gold": chance * info["gold"] + (1.0 - chance) * Dispatch.failure_gold(quest),
			"xp": xp,
			"drops": Gear.loot_percent(info["rank"], luck) / 100.0,
			"reputation": chance * Dispatch.REPUTATION[info["rank"]] - (1.0 - chance) * Dispatch.FAILURE_REPUTATION,
			"chance": chance,
		}
	return takes


# Each quest the board offers a guild of `guild_rank` with `slots` slots, refilling twice as fast
# when `fast_refill`, by how many come up a second. A slot draws each with its Board.draw_chance; one
# in `taken`, which some party takes, goes at once and its slot refills after
# Board.slot_refill_seconds, while any other sits until it leaves, after EXPIRE_SECONDS, then
# refills. A slot draws only among quests not on the other slots, which mostly
# hold quests nobody takes, sitting there: so within a rank, the quests taken come up more often.
static func _offered(dispatch: Dispatch, slots: int, taken: Dictionary, guild_rank: String, fast_refill: bool) -> Dictionary:
	var chances := {}
	# Each rank's quests offered and, of them, taken.
	var ranks := {}
	for quest: String in Dispatch.QUESTS:
		var chance := Board.draw_chance(quest, dispatch.adventurers, guild_rank)
		if chance == 0.0:
			continue
		var rank: String = Dispatch.QUESTS[quest]["rank"]
		chances[quest] = chance
		ranks[rank] = ranks.get(rank, Vector2i()) + Vector2i(1, 1 if taken.has(quest) else 0)
	# How many of the other slots hold a quest of each rank that nobody takes, on average.
	var sitting := {}
	var slot_seconds := _slot_seconds(chances, taken, fast_refill)
	for quest: String in chances:
		var rank: String = Dispatch.QUESTS[quest]["rank"]
		if not taken.has(quest):
			sitting[rank] = sitting.get(rank, 0.0) + (slots - 1) * chances[quest] * Board.EXPIRE_SECONDS[rank] / slot_seconds
	var offered := {}
	for quest: String in chances:
		var rank: String = Dispatch.QUESTS[quest]["rank"]
		var count: Vector2i = ranks[rank]
		var rank_chance: float = chances[quest] * count.x
		var free := maxf(count.x - sitting.get(rank, 0.0), maxf(count.y, 1.0))
		offered[quest] = rank_chance / free if taken.has(quest) else rank_chance * (1.0 - count.y / free) / (count.x - count.y)
	slot_seconds = _slot_seconds(offered, taken, fast_refill)
	for quest: String in offered:
		offered[quest] *= slots / slot_seconds
	return offered


# The seconds a slot takes on average from one draw to the next, drawing each quest with its
# chance in `chances`, those in `taken` going at once, refilling twice as fast when `fast_refill`.
static func _slot_seconds(chances: Dictionary, taken: Dictionary, fast_refill: bool) -> float:
	var seconds := 0.0
	for quest: String in chances:
		var rank: String = Dispatch.QUESTS[quest]["rank"]
		seconds += chances[quest] * (Board.slot_refill_seconds(rank, fast_refill) + (0 if taken.has(quest) else Board.EXPIRE_SECONDS[rank]))
	return seconds


# The damage each member of a party with `spirit` and `luck` in all can expect from a quest that
# deals at most `most`, succeeding at `chance` (0 to 1), as Outcome.roll deals it.
static func _expected_damage(chance: float, most: int, spirit: int, luck: int) -> float:
	var half := floori(most / 2.0)
	var kept := (100 - mini(Outcome.MOST_SPIRIT_CUT, Outcome.SPIRIT_CUT_PER_POINT * spirit)) / 100.0
	var failure_kept := kept * (100 - mini(Outcome.MOST_LUCK_CUT, Outcome.LUCK_CUT_PER_POINT * luck)) / 100.0
	return chance * half / 2.0 * kept + (1.0 - chance) * (half + most) / 2.0 * failure_kept
