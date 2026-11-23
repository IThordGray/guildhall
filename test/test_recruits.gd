extends GutTest

const SAVE_PATH: String = "user://test_recruits_save.cfg"
## Unix seconds the candidates in these tests first arrive at.
const START: int = 1_000_000
const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## No candidates yet, with the two slots a guild saved before guild ranks has with no Common room.
func _old_recruits() -> Recruits:
	var recruits := Recruits.new()
	recruits.reception_slots = 2
	return recruits


## The candidates saved at SAVE_PATH, loaded for a guild saved before guild ranks.
func _load_old_recruits() -> Recruits:
	var recruits := Recruits.load_or_start(SAVE_PATH)
	recruits.reception_slots = 2
	return recruits


## Candidates first filled at START for `adventurers`.
func _recruits(adventurers: Adventurers) -> Recruits:
	var recruits := _old_recruits()
	recruits.refill(adventurers, START)
	return recruits


func _names(adventurers: Adventurers) -> Array[String]:
	var names: Array[String] = []
	for who: Dictionary in adventurers.roster.values():
		names.append(who["name"])
	return names


## Hires from `slot` with plenty of gold and beds, at `at`.
func _hire(recruits: Recruits, slot: int, adventurers: Adventurers, at: int) -> void:
	assert_true(recruits.hire(slot, adventurers, Gold.new(1_000), Hall.MAX_ROSTER, at))


func test_a_new_guild_starts_with_one_candidate_and_a_save_from_before_candidates_with_two() -> void:
	var recruits := Recruits.new()
	recruits.refill(Adventurers.new(), START)
	assert_eq(recruits.candidates.size(), 1)
	var old := _recruits(Adventurers.new(EVERYONE))
	assert_eq(old.candidates.size(), 2)
	for candidate: Dictionary in recruits.candidates + old.candidates:
		assert_false(candidate.is_empty())
		assert_eq(candidate["who"]["rank"], "F")
		assert_true(candidate["worn"].has("weapon"))

	var file := ConfigFile.new()
	Gold.new(50).write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	# The save has no hall layout, so its Reception gives what a guild had before guild ranks.
	var loaded := Recruits.load_or_start(SAVE_PATH)
	loaded.reception_slots = Hall.load_or_start(SAVE_PATH, START).reception("candidate_slots")
	loaded.refill(Adventurers.load_or_start(SAVE_PATH), START)
	assert_eq(loaded.candidates, old.candidates)


func test_a_hire_costs_100_gold_adds_the_candidate_last_at_level_1_in_their_weapon_and_empties_the_slot() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	var hired := recruits.candidates[1]
	var gold := Gold.new(130)
	assert_true(recruits.hire(1, adventurers, gold, 6, START + 10))
	assert_eq(gold.amount, 30)
	var id: String = adventurers.roster.keys()[4]
	assert_eq(adventurers.roster[id]["name"], hired["who"]["name"])
	assert_eq(adventurers.roster[id], hired["who"])
	assert_eq(adventurers.levels[id], 1)
	assert_eq(adventurers.gear.worn[id], hired["worn"])
	assert_eq(adventurers.gear.worn[id].keys(), ["weapon"])
	assert_true(recruits.candidates[1].is_empty())
	assert_false(recruits.candidates[0].is_empty())


func test_an_emptied_slot_refills_exactly_60_seconds_after_the_hire_and_not_before() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START + 100)
	assert_eq(recruits.seconds_to_refill(0, START + 100), 60)
	recruits.refill(adventurers, START + 159)
	assert_true(recruits.candidates[0].is_empty())
	assert_eq(recruits.seconds_to_refill(0, START + 159), 1)
	recruits.refill(adventurers, START + 160)
	assert_false(recruits.candidates[0].is_empty())


func test_each_slot_counts_down_on_its_own() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START)
	_hire(recruits, 1, adventurers, START + 20)
	recruits.refill(adventurers, START + 60)
	assert_false(recruits.candidates[0].is_empty())
	assert_true(recruits.candidates[1].is_empty())
	assert_eq(recruits.seconds_to_refill(1, START + 60), 20)
	recruits.refill(adventurers, START + 80)
	assert_false(recruits.candidates[1].is_empty())


func test_the_next_refill_is_the_soonest_empty_slots_countdown_and_none_while_no_slot_is_empty() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	assert_eq(recruits.seconds_to_next_refill(START), -1)
	# Slot 1 empties first, so it refills before slot 0.
	_hire(recruits, 1, adventurers, START)
	_hire(recruits, 0, adventurers, START + 20)
	assert_eq(recruits.seconds_to_next_refill(START + 33), 27)
	recruits.refill(adventurers, START + 60)
	assert_false(recruits.candidates[1].is_empty())
	assert_eq(recruits.seconds_to_next_refill(START + 60), 20)
	recruits.refill(adventurers, START + 80)
	assert_eq(recruits.seconds_to_next_refill(START + 80), -1)


func test_one_refill_after_an_absence_gives_the_same_candidates_as_refilling_every_second() -> void:
	var watched_guild := Adventurers.new(EVERYONE)
	var watched := _recruits(watched_guild)
	var away_guild := Adventurers.new(EVERYONE)
	var away := _recruits(away_guild)
	# Hires at the same moments; the watched slots are refilled every second between them.
	for hire: Vector2i in [Vector2i(START + 5, 0), Vector2i(START + 700, 1), Vector2i(START + 2_000, 0)]:
		for at: int in range(watched.checked_at, hire.x):
			watched.refill(watched_guild, at)
		_hire(watched, hire.y, watched_guild, hire.x)
		_hire(away, hire.y, away_guild, hire.x)
	for at: int in range(watched.checked_at, START + 6_000):
		watched.refill(watched_guild, at)
	watched.refill(watched_guild, START + 6_000)
	away.refill(away_guild, START + 6_000)
	assert_eq(away.candidates, watched.candidates)
	assert_eq(away.refill_at, watched.refill_at)
	assert_eq(_names(away_guild), _names(watched_guild))
	assert_false(away.candidates[0].is_empty())
	assert_false(away.candidates[1].is_empty())


func test_a_clock_set_back_neither_undoes_a_refill_nor_restarts_a_countdown() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START)
	_hire(recruits, 1, adventurers, START + 30)
	recruits.refill(adventurers, START + 60)
	var refilled := recruits.candidates[0]
	assert_false(refilled.is_empty())

	recruits.refill(adventurers, START)
	assert_eq(recruits.candidates[0], refilled)
	assert_true(recruits.candidates[1].is_empty())
	assert_eq(recruits.seconds_to_refill(1, START), 30)
	recruits.refill(adventurers, START + 90)
	assert_false(recruits.candidates[1].is_empty())


func test_candidates_and_countdowns_survive_save_and_load() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	_hire(recruits, 1, adventurers, START + 50)
	var file := ConfigFile.new()
	recruits.write(file)
	adventurers.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := _load_old_recruits()
	var loaded_guild := Adventurers.load_or_start(SAVE_PATH)
	assert_eq(loaded.candidates, recruits.candidates)
	assert_eq(loaded.refill_at, recruits.refill_at)
	assert_eq(loaded.checked_at, START + 50)
	assert_eq(loaded.seconds_to_refill(1, START + 50), 60)
	loaded.refill(loaded_guild, START + 110)
	recruits.refill(adventurers, START + 110)
	assert_false(loaded.candidates[1].is_empty())
	assert_eq(loaded.candidates, recruits.candidates)


func test_the_same_slot_and_time_always_bring_the_same_candidate_whatever_the_global_generator() -> void:
	seed(1)
	var first := _recruits(Adventurers.new(EVERYONE))
	seed(2)
	randi()
	var second := _recruits(Adventurers.new(EVERYONE))
	assert_eq(second.candidates, first.candidates)
	var later := _old_recruits()
	later.refill(Adventurers.new(EVERYONE), START + 1)
	assert_ne(later.candidates, first.candidates)


func test_a_candidate_is_never_named_after_anyone_in_the_guild_or_the_other_candidate() -> void:
	var only_free := Recruits.NAMES[7]
	var taken := Recruits.NAMES.duplicate()
	taken.remove_at(7)
	for at: int in 20:
		assert_eq(Recruits.candidate_for(0, START + at, taken)["who"]["name"], only_free)

	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	# Hires fill the guild with recruits, each named apart from everyone already in it.
	for at: int in range(START, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS, Recruits.CANDIDATE_REFILL_SECONDS):
		recruits.refill(adventurers, at)
		assert_ne(recruits.candidates[0]["who"]["name"], recruits.candidates[1]["who"]["name"])
		for candidate: Dictionary in recruits.candidates:
			assert_does_not_have(_names(adventurers), candidate["who"]["name"])
		_hire(recruits, 0, adventurers, at)
	assert_eq(adventurers.roster.size(), 8)


func test_all_nine_of_a_candidates_own_stats_show_before_a_hire_and_are_theirs_after() -> void:
	var joss := Recruits.candidate_for(0, 1_000_000, PackedStringArray())
	# Joss's Short sword adds Strength +1, which their own stats leave out.
	assert_eq(Recruits.stats_line(joss), "Strength 6 · Agility 3 · Perception 3 · Mind 3 · Spirit 2 · Defence 5 · Endurance 4 · Presence 3 · Luck 4")
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	var candidate := recruits.candidates[0]
	var line := Recruits.stats_line(candidate)
	assert_eq(line.count("?"), 0, line)
	assert_eq(line.split(" · ").size(), 9, line)

	_hire(recruits, 0, adventurers, START)
	var id: String = adventurers.roster.keys()[4]
	for stat: String in Adventurers.STATS:
		assert_eq(adventurers.stats[id][stat], candidate["stats"][stat], stat)


func test_about_one_in_ten_candidates_is_a_late_bloomer_weaker_but_growing_far_faster_in_a_stat_they_lean_to() -> void:
	var bloomers := 0
	var bloomer_stats := 0
	var other_stats := 0
	for at: int in 2_000:
		var candidate := Recruits.candidate_for(at % 2, START + at, PackedStringArray())
		var fastest: float = candidate["growth"].values().max()
		var total := 0
		for stat: String in Adventurers.STATS:
			total += int(candidate["stats"][stat])
		if fastest >= 0.9:
			bloomers += 1
			bloomer_stats += total
		else:
			assert_lt(fastest, 0.7, str(candidate))
			other_stats += total
	assert_between(bloomers, 140, 260)
	assert_lt(bloomer_stats / float(bloomers), other_stats / float(2_000 - bloomers) - 2.0)


func test_a_hire_is_refused_with_nothing_changed_when_gold_is_short_or_every_bed_is_taken() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	var before := recruits.candidates.duplicate(true)
	var short := Gold.new(99)
	assert_eq(Recruits.refusal(adventurers, short, 6), "Not enough gold")
	assert_false(recruits.hire(0, adventurers, short, 6, START))
	var full := Gold.new(500)
	assert_eq(Recruits.refusal(adventurers, full, 4, Recruits.HIRE_GOLD, Hall.new(START)), "No free bed — convert a Bunk room")
	assert_false(recruits.hire(0, adventurers, full, 4, START))
	assert_eq(short.amount, 99)
	assert_eq(full.amount, 500)
	assert_eq(adventurers.roster.size(), 4)
	assert_eq(recruits.candidates, before)
	# With the gold and a bed, the same hire goes through.
	assert_eq(Recruits.refusal(adventurers, Gold.new(100), 5), "")
	assert_true(recruits.hire(0, adventurers, full, 5, START))
	assert_eq(adventurers.roster.size(), 5)


func test_with_every_bed_taken_a_bunk_room_is_suggested_only_while_one_can_still_be_built() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	var gold := Gold.new(1_000)
	for at: int in range(START, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS, Recruits.CANDIDATE_REFILL_SECONDS):
		_hire(recruits, 0, adventurers, at)
	assert_eq(adventurers.roster.size(), 8)
	recruits.refill(adventurers, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS)
	assert_eq(Recruits.refusal(adventurers, gold, 8), "No free bed")
	assert_false(recruits.hire(0, adventurers, gold, 8, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS))
	assert_eq(adventurers.roster.size(), 8)
	assert_eq(gold.amount, 1_000)
	# A new rank-F guild with no Bunk room can build one.
	var hall := Hall.new(START)
	assert_eq(Recruits.refusal(Adventurers.new(EVERYONE), gold, 4, Recruits.HIRE_GOLD, hall), "No free bed — convert a Bunk room")
	assert_eq(Recruits.refusal(Adventurers.new(EVERYONE), gold, 6, Recruits.HIRE_GOLD, hall), "")
	# Once one is being built, and once it is built, it can't be built again.
	hall.restored.append("side_left")
	assert_true(hall.convert_room("side_left", "bunk_room", Gold.new(1_000), START))
	assert_eq(Recruits.refusal(Adventurers.new(EVERYONE), gold, 4, Recruits.HIRE_GOLD, hall), "No free bed")
	hall.checkpoint(START + 3_600)
	assert_eq(hall.rooms_done("bunk_room", START + 3_600), 1)
	assert_eq(Recruits.refusal(Adventurers.new(EVERYONE), gold, 4, Recruits.HIRE_GOLD, hall), "No free bed")


func test_a_hired_fighter_can_be_sent_on_a_quest_with_their_sword_counting() -> void:
	var dispatch := _guild(START)
	var recruits := _old_recruits()
	var at := START
	recruits.refill(dispatch.adventurers, at)
	while Recruits.title(recruits.candidates[0]) != "Fighter":
		at += 1
		recruits = _old_recruits()
		recruits.refill(dispatch.adventurers, at)
	var stats: Dictionary = recruits.candidates[0]["stats"]
	assert_true(recruits.hire(0, dispatch.adventurers, Gold.new(100), 5, at))
	var id: String = dispatch.adventurers.roster.keys()[4]
	var party := PackedStringArray([id])
	assert_eq(dispatch.adventurers.title(id), "Fighter")
	# The short sword's Strength +1 counts twice in Brute force.
	assert_eq(Challenges.party_total("Brute force", party, dispatch.adventurers), 2 * (int(stats["strength"]) + 1) + int(stats["defence"]))
	assert_eq(dispatch.party_refusal("rats", party, at), "")
	assert_true(dispatch.send("rats", party, 7, at))
	assert_eq(dispatch.quest_of(id), "rats")


func test_every_candidate_arrives_wearing_a_standard_weapon_fitting_what_they_lean_to() -> void:
	var titles := {}
	for at: int in 2_000:
		var candidate := Recruits.candidate_for(at % 4, START + at, PackedStringArray())
		var worn: Dictionary = candidate["worn"]
		assert_eq(worn.keys(), ["weapon"])
		var weapon: Dictionary = Gear.ITEMS[worn["weapon"]]
		assert_eq(weapon["slot"], "weapon")
		assert_eq(weapon["quality"], "Standard")
		# Their two highest stats of their own are what they lean to; the weapon adds to one.
		var own: Dictionary = candidate["stats"]
		var order: Array = Adventurers.STATS.keys()
		order.sort_custom(func(a: String, b: String) -> bool: return own[a] > own[b])
		assert_true(weapon["bonus"].has(order[0]) or weapon["bonus"].has(order[1]), str(candidate))
		titles[Recruits.title(candidate)] = true
	# Every leaning comes.
	assert_eq(titles.size(), Recruits.LEANING_WEAPONS.size())


## Recruits first filled at START, then refilled at `at` with Common rooms finished at `rooms`.
func _with_rooms(adventurers: Adventurers, at: int, rooms: Array[int]) -> Recruits:
	var recruits := _recruits(adventurers)
	recruits.refill(adventurers, at, PackedInt64Array(rooms))
	return recruits


## A new guild's candidates, filled at the first time `at` from START on at which, with Common
## rooms finished at `at` plus each of `room_offsets`, slot 0's candidate is rank E; null, with the
## test failed, when none is within 10_000 seconds.
func _rank_e_guild(adventurers: Adventurers, room_offsets: Array[int] = [0]) -> Recruits:
	for at: int in range(START, START + 10_000):
		var rooms := PackedInt64Array()
		for offset: int in room_offsets:
			rooms.append(at + offset)
		var recruits := _old_recruits()
		recruits.refill(adventurers, at, rooms)
		if recruits.candidates[0]["who"]["rank"] == "E":
			return recruits
	fail_test("no rank-E candidate in slot 0 within 10_000 seconds")
	return null


## The Common rooms of `rooms` finished by `at`, as the hall's checkpoint at `at` has them.
func _done_by(rooms: Array[int], at: int) -> PackedInt64Array:
	var done := PackedInt64Array()
	for room: int in rooms:
		if room <= at:
			done.append(room)
	return done


func test_a_common_room_adds_a_slot_whose_first_candidate_arrives_when_the_room_finished() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _with_rooms(adventurers, START + 1_000, [START + 500])
	assert_eq(recruits.candidates.size(), 3)
	assert_false(recruits.candidates[2].is_empty())
	# A hired candidate's id records the slot and the moment they arrived.
	_hire(recruits, 2, adventurers, START + 1_000)
	assert_true(adventurers.roster.has("recruit_2_%d" % (START + 500)), str(adventurers.roster.keys()))


func test_common_rooms_add_slots_up_to_four_in_all() -> void:
	assert_eq(_with_rooms(Adventurers.new(EVERYONE), START + 1_000, [START + 100, START + 200]).candidates.size(), 4)
	var many := _with_rooms(Adventurers.new(EVERYONE), START + 1_000, [START + 300, START + 100, START + 200, START + 400])
	assert_eq(many.candidates.size(), 4)
	for candidate: Dictionary in many.candidates:
		assert_false(candidate.is_empty())


func test_about_a_quarter_of_candidates_arriving_once_a_common_room_finished_are_rank_e_and_none_before() -> void:
	var room_done := START + 1_000
	var rank_e := 0
	for at: int in 2_000:
		var arrives := START + at
		var candidate := Recruits.candidate_for(at % 4, arrives, PackedStringArray(), room_done)
		var plain := Recruits.candidate_for(at % 4, arrives, PackedStringArray())
		assert_eq(plain["who"]["rank"], "F")
		if arrives < room_done:
			assert_eq(candidate["who"]["rank"], "F")
		elif candidate["who"]["rank"] == "E":
			rank_e += 1
		# Only the rank, and a rank-E one's level and stats, can differ from the same candidate
		# without a Common room.
		if candidate["who"]["rank"] == "E":
			candidate.erase("level")
			candidate["stats"] = plain["stats"]
		candidate["who"]["rank"] = "F"
		assert_eq(candidate, plain)
	assert_between(rank_e, 200, 300)


func test_rank_e_starts_from_the_first_common_room_not_a_later_one() -> void:
	# Rooms finished 10 seconds before and 1_000 seconds after slot 0's candidate arrives.
	var recruits := _rank_e_guild(Adventurers.new(EVERYONE), [-10, 1_000])
	if recruits == null:
		return
	assert_eq(recruits.candidates[0]["who"]["rank"], "E")
	assert_lt(recruits.refill_at[0], recruits.refill_at[3])


func test_no_two_candidates_share_a_name_with_four_slots_filled() -> void:
	for at: int in range(START, START + 300):
		var adventurers := Adventurers.new(EVERYONE)
		var recruits := _old_recruits()
		recruits.refill(adventurers, at, PackedInt64Array([at, at]))
		var names: Array[String] = []
		for candidate: Dictionary in recruits.candidates:
			assert_does_not_have(names, candidate["who"]["name"], str(at))
			assert_does_not_have(_names(adventurers), candidate["who"]["name"], str(at))
			names.append(candidate["who"]["name"])
		assert_eq(names.size(), 4)


func test_a_rank_e_candidate_costs_180_gold_and_is_refused_with_nothing_changed_when_short() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _rank_e_guild(adventurers)
	if recruits == null:
		return
	var at := recruits.checked_at
	var rooms := PackedInt64Array([at])
	assert_eq(Recruits.hire_gold(recruits.candidates[0]), 180)
	var before := recruits.candidates.duplicate(true)
	var short := Gold.new(179)
	assert_eq(Recruits.refusal(adventurers, short, 6, Recruits.hire_gold(recruits.candidates[0])), "Not enough gold")
	assert_false(recruits.hire(0, adventurers, short, 6, at, rooms))
	var gold := Gold.new(180)
	assert_false(recruits.hire(0, adventurers, gold, 4, at, rooms))
	assert_eq(short.amount, 179)
	assert_eq(gold.amount, 180)
	assert_eq(adventurers.roster.size(), 4)
	assert_eq(recruits.candidates, before)

	assert_true(recruits.hire(0, adventurers, gold, 6, at, rooms))
	assert_eq(gold.amount, 0)
	assert_eq(adventurers.roster[adventurers.roster.keys()[4]]["rank"], "E")
	assert_eq(Recruits.hire_gold({"who": {"rank": "F"}}), 100)


func test_one_refill_after_an_absence_equals_refilling_every_second_with_common_rooms_finishing_during_it() -> void:
	var rooms: Array[int] = [START + 300, START + 2_500]
	var watched_guild := Adventurers.new(EVERYONE)
	var watched := _recruits(watched_guild)
	var away_guild := Adventurers.new(EVERYONE)
	var away := _recruits(away_guild)
	var hires: Array[Vector2i] = [Vector2i(START + 5, 0), Vector2i(START + 710, 1), Vector2i(START + 2_600, 2), Vector2i(START + 2_700, 3)]
	for hire: Vector2i in hires:
		for at: int in range(watched.checked_at, hire.x):
			watched.refill(watched_guild, at, _done_by(rooms, at))
		assert_true(watched.hire(hire.y, watched_guild, Gold.new(1_000), Hall.MAX_ROSTER, hire.x, _done_by(rooms, hire.x)))
		assert_true(away.hire(hire.y, away_guild, Gold.new(1_000), Hall.MAX_ROSTER, hire.x, _done_by(rooms, hire.x)))
	for at: int in range(watched.checked_at, START + 6_000):
		watched.refill(watched_guild, at, _done_by(rooms, at))
	watched.refill(watched_guild, START + 6_000, PackedInt64Array(rooms))
	away.refill(away_guild, START + 6_000, PackedInt64Array(rooms))
	assert_eq(away.candidates, watched.candidates)
	assert_eq(away.refill_at, watched.refill_at)
	assert_eq(_names(away_guild), _names(watched_guild))
	assert_eq(away.candidates.size(), 4)
	# Some candidates came after the first Common room finished as rank E, so ranks were compared.
	var ranks: Array[String] = []
	for who: Dictionary in away_guild.roster.values():
		ranks.append(who["rank"])
	for candidate: Dictionary in away.candidates:
		ranks.append(candidate["who"]["rank"])
	assert_has(ranks, "E")


func test_a_clock_set_back_neither_removes_a_common_room_slot_nor_restarts_its_countdown() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var rooms := PackedInt64Array([START + 500])
	var recruits := _with_rooms(adventurers, START + 1_000, [START + 500])
	_hire(recruits, 2, adventurers, START + 1_000)
	recruits.refill(adventurers, START, rooms)
	assert_eq(recruits.candidates.size(), 3)
	assert_true(recruits.candidates[2].is_empty())
	assert_eq(recruits.seconds_to_refill(2, START), 60)
	recruits.refill(adventurers, START + 1_060, rooms)
	assert_false(recruits.candidates[2].is_empty())


func test_common_room_slots_and_rank_e_candidates_survive_save_and_load() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _rank_e_guild(adventurers)
	if recruits == null:
		return
	var rooms := PackedInt64Array([recruits.checked_at, recruits.checked_at + 10])
	recruits.refill(adventurers, recruits.checked_at + 20, rooms)
	var file := ConfigFile.new()
	recruits.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := _load_old_recruits()
	assert_eq(loaded.candidates.size(), 4)
	assert_eq(loaded.candidates, recruits.candidates)
	assert_eq(loaded.candidates[0]["who"]["rank"], "E")
	assert_eq(loaded.refill_at, recruits.refill_at)
	loaded.refill(adventurers, loaded.checked_at, rooms)
	assert_eq(loaded.candidates, recruits.candidates)


func test_a_save_with_two_slots_and_no_common_room_loads_with_two_slots_and_a_later_room_adds_one() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var file := ConfigFile.new()
	_recruits(adventurers).write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := _load_old_recruits()
	loaded.refill(adventurers, START + 5_000)
	assert_eq(loaded.candidates.size(), 2)
	for candidate: Dictionary in loaded.candidates:
		assert_eq(candidate["who"]["rank"], "F")
	loaded.refill(adventurers, START + 5_000, PackedInt64Array([START + 5_000]))
	assert_eq(loaded.candidates.size(), 3)


func test_a_rank_e_candidate_arrives_at_level_3_with_each_stat_at_least_the_same_candidate_as_rank_f() -> void:
	var rank_e := 0
	var stronger := 0
	for at: int in 2_000:
		var candidate := Recruits.candidate_for(at % 4, START + at, PackedStringArray(), START)
		if candidate["who"]["rank"] != "E":
			assert_false(candidate.has("level"))
			continue
		rank_e += 1
		var plain := Recruits.candidate_for(at % 4, START + at, PackedStringArray())
		assert_eq(candidate["level"], 3)
		var gained := 0
		for stat: String in Adventurers.STATS:
			assert_gte(candidate["stats"][stat], plain["stats"][stat], stat)
			gained += candidate["stats"][stat] - plain["stats"][stat]
		if gained > 0:
			stronger += 1
	assert_gt(rank_e, 400)
	# Two level-ups of up to 8 points each leave almost nobody as they were.
	assert_gt(stronger * 20, rank_e * 19)
	# The gains come from the candidate's own seed, whatever the global generator.
	seed(1)
	var first := Recruits.candidate_for(1, START + 5, PackedStringArray(), START)
	seed(2)
	randi()
	assert_eq(Recruits.candidate_for(1, START + 5, PackedStringArray(), START), first)


func test_a_rank_f_candidate_is_drawn_the_same_with_or_without_a_common_room_and_with_a_face() -> void:
	var joss := Recruits.candidate_for(0, 1_000_000, PackedStringArray())
	assert_true(joss["who"].has("face_seed"))
	joss["who"].erase("face_seed")
	assert_eq(joss, {
		"who": {"name": "Joss", "rank": "F"},
		"stats": {"strength": 6, "agility": 3, "perception": 3, "mind": 3, "spirit": 2, "defence": 5, "endurance": 4, "presence": 3, "luck": 4},
		"growth": {"strength": 0.6, "agility": 0.25, "perception": 0.25, "mind": 0.25, "spirit": 0.25, "defence": 0.6, "endurance": 0.25, "presence": 0.25, "luck": 0.25},
		"shown": PackedStringArray(["endurance", "defence", "spirit", "perception"]),
		"worn": {"weapon": "short_sword"},
	})
	var rank_f := 0
	for at: int in range(1_000_500, 1_000_540):
		var with_room := Recruits.candidate_for(3, at, PackedStringArray(), 1_000_000)
		if with_room["who"]["rank"] == "F":
			rank_f += 1
			assert_eq(with_room, Recruits.candidate_for(3, at, PackedStringArray()))
	assert_gt(rank_f, 0)


func test_a_candidates_stats_count_what_they_wear_and_their_health_is_as_an_adventurers_at_their_level() -> void:
	# Joss: Strength 6 and Defence 5, in a Short sword, Strength +1.
	var joss := Recruits.candidate_for(0, 1_000_000, PackedStringArray())
	assert_eq(Recruits.totals(joss), {"strength": 7, "agility": 3, "perception": 3, "mind": 3, "spirit": 2, "defence": 5, "endurance": 4, "presence": 3, "luck": 4})
	# 10 + 2 × Defence 5, at level 1.
	assert_eq(Recruits.max_health(joss), 20)
	# Chapel plate's Defence +4 adds 8; two levels past the first add 3 each.
	joss["worn"]["armour"] = "chapel_plate"
	joss["level"] = 3
	assert_eq(Recruits.totals(joss)["defence"], 9)
	assert_eq(Recruits.max_health(joss), 34)
	# Hired, they heal up to the same.
	var adventurers := Adventurers.new(EVERYONE)
	Recruits.join(adventurers, "joss", joss)
	assert_eq(adventurers.max_health("joss"), 34)


func test_a_candidate_saved_with_the_four_old_stats_loads_with_nine_filled_by_their_class_and_their_weapon() -> void:
	var recruits := _recruits(Adventurers.new(EVERYONE))
	# The build before nine stats drew candidates by class.
	recruits.candidates[0] = {
		"who": {"name": "Corwin", "class": "Healer", "rank": "F", "face_seed": 7},
		"stats": {"might": 2, "agility": 3, "mind": 6, "grit": 5},
		"growth": {"might": 0.2, "agility": 0.3, "mind": 0.55, "grit": 0.5},
		"shown": PackedStringArray(["grit", "mind"]),
	}
	var file := ConfigFile.new()
	recruits.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := _load_old_recruits()
	var corwin := loaded.candidates[0]
	assert_eq(corwin["who"], {"name": "Corwin", "rank": "F", "face_seed": 7})
	# Might is Strength and Grit Defence; a Healer gets high Spirit and a little Luck.
	assert_eq(corwin["stats"], {"strength": 2, "agility": 3, "mind": 6, "defence": 5, "perception": 3, "spirit": 7, "endurance": 3, "presence": 3, "luck": 1})
	assert_eq(corwin["growth"].size(), 9)
	assert_almost_eq(float(corwin["growth"]["defence"]), 0.5, 0.0001)
	assert_eq(corwin["shown"], PackedStringArray(["defence", "mind"]))
	assert_eq(corwin["worn"], {"weapon": "bell_mace"})
	assert_eq(Recruits.title(corwin), "Mystic")
	assert_string_contains(Recruits.stats_line(corwin), "Defence 5")
	# The other candidate, saved with nine, is as it was.
	assert_eq(loaded.candidates[1], recruits.candidates[1])
	# And they are hired as they show.
	var adventurers := Adventurers.new(EVERYONE)
	assert_true(loaded.hire(0, adventurers, Gold.new(100), 6, START))
	var id: String = adventurers.roster.keys()[4]
	assert_eq(adventurers.stats[id], corwin["stats"])
	assert_eq(adventurers.gear.worn[id], {"weapon": "bell_mace"})


func test_a_candidates_face_seed_is_the_face_they_have_once_hired_and_after_save_and_load() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	var face_seed: int = recruits.candidates[1]["who"]["face_seed"]
	assert_ne(face_seed, recruits.candidates[0]["who"]["face_seed"])
	_hire(recruits, 1, adventurers, START + 10)
	var id: String = adventurers.roster.keys()[4]
	assert_eq(Faces.seed_of(id, adventurers.roster[id]), face_seed)
	assert_ne(face_seed, hash(id))
	var waiting: int = recruits.candidates[0]["who"]["face_seed"]
	var file := ConfigFile.new()
	recruits.write(file)
	adventurers.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded_guild := Adventurers.load_or_start(SAVE_PATH)
	var loaded := _load_old_recruits()
	assert_eq(Faces.seed_of(id, loaded_guild.roster[id]), face_seed)
	assert_eq(loaded.candidates[0]["who"]["face_seed"], waiting)
	_hire(loaded, 0, loaded_guild, START + 20)
	var later: String = loaded_guild.roster.keys()[5]
	assert_eq(Faces.seed_of(later, loaded_guild.roster[later]), waiting)


func test_a_save_from_before_faces_loads_with_faces_from_each_adventurers_id_and_keeps_a_candidates_face_on_hire() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _recruits(adventurers)
	_hire(recruits, 1, adventurers, START + 10)
	var id: String = adventurers.roster.keys()[4]
	# The previous build kept each face as the name of its art and drew no face seeds.
	for who: Dictionary in adventurers.roster.values():
		who.erase("face_seed")
	adventurers.roster["bram"]["face"] = "bram"
	recruits.candidates[0]["who"].erase("face_seed")
	recruits.candidates[0]["who"]["face"] = ""
	var file := ConfigFile.new()
	recruits.write(file)
	adventurers.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded_guild := Adventurers.load_or_start(SAVE_PATH)
	var loaded := _load_old_recruits()
	assert_eq(loaded_guild.roster.keys(), adventurers.roster.keys())
	for adventurer: String in ["bram", "maren", id]:
		assert_eq(Faces.seed_of(adventurer, loaded_guild.roster[adventurer]), hash(adventurer))
	var waiting: int = loaded.candidates[0]["who"]["face_seed"]
	# The waiting candidate has the face they would arrive with now, however often the save loads.
	assert_eq(waiting, Recruits.candidate_for(0, START, PackedStringArray())["who"]["face_seed"])
	assert_eq(_load_old_recruits().candidates[0]["who"]["face_seed"], waiting)
	_hire(loaded, 0, loaded_guild, START + 20)
	var later: String = loaded_guild.roster.keys()[5]
	assert_eq(Faces.seed_of(later, loaded_guild.roster[later]), waiting)


func test_hiring_a_rank_e_candidate_brings_them_in_at_level_3_with_0_xp_and_their_stats() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _rank_e_guild(adventurers)
	if recruits == null:
		return
	var hired := recruits.candidates[0].duplicate(true)
	assert_true(recruits.hire(0, adventurers, Gold.new(180), 6, recruits.checked_at, PackedInt64Array([recruits.checked_at])))
	var id: String = adventurers.roster.keys()[4]
	assert_eq(adventurers.roster[id]["rank"], "E")
	assert_eq(adventurers.levels[id], 3)
	assert_eq(adventurers.xp[id], 0)
	assert_eq(adventurers.stats[id], hired["stats"])
	assert_eq(adventurers.xp_needed(id), 40)


func test_a_rank_e_candidate_saved_before_they_arrived_levelled_loads_and_is_hired_as_saved_at_level_1() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := _rank_e_guild(adventurers)
	if recruits == null:
		return
	var at := recruits.checked_at
	recruits.candidates[0].erase("level")
	var saved := recruits.candidates[0].duplicate(true)
	var file := ConfigFile.new()
	recruits.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := _load_old_recruits()
	loaded.refill(adventurers, at, PackedInt64Array([at]))
	assert_eq(loaded.candidates[0], saved)
	assert_true(loaded.hire(0, adventurers, Gold.new(180), 6, at, PackedInt64Array([at])))
	var id: String = adventurers.roster.keys()[4]
	assert_eq(adventurers.roster[id]["rank"], "E")
	assert_eq(adventurers.levels[id], 1)
	assert_eq(adventurers.stats[id], saved["stats"])
