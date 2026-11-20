extends GutTest

const SAVE_PATH: String = "user://test_recruits_save.cfg"
## Unix seconds the candidates in these tests first arrive at.
const START: int = 1_000_000
## The stat each class grows in most.
const MAIN_STAT: Dictionary[String, String] = {"Swordsman": "might", "Mage": "mind", "Scout": "agility", "Healer": "mind", "Shield bearer": "grit"}


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## Candidates first filled at START for `adventurers`.
func _recruits(adventurers: Adventurers) -> Recruits:
	var recruits := Recruits.new()
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


func test_a_new_guild_and_a_save_from_before_candidates_both_start_with_two_candidates() -> void:
	var recruits := _recruits(Adventurers.new())
	assert_eq(recruits.candidates.size(), 2)
	for candidate: Dictionary in recruits.candidates:
		assert_false(candidate.is_empty())
		assert_eq(candidate["who"]["rank"], "F")
		assert_has(Challenges.COVERS.keys(), candidate["who"]["class"])

	var file := ConfigFile.new()
	Gold.new(50).write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Recruits.load_or_start(SAVE_PATH)
	loaded.refill(Adventurers.new(), START)
	assert_eq(loaded.candidates, recruits.candidates)


func test_a_hire_costs_100_gold_adds_the_candidate_last_at_level_1_and_empties_the_slot() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	var hired := recruits.candidates[1]
	var gold := Gold.new(130)
	assert_true(recruits.hire(1, adventurers, gold, 6, START + 10))
	assert_eq(gold.amount, 30)
	var id: String = adventurers.roster.keys()[4]
	assert_eq(adventurers.roster[id]["name"], hired["who"]["name"])
	assert_eq(adventurers.roster[id]["class"], hired["who"]["class"])
	assert_eq(adventurers.levels[id], 1)
	assert_eq(adventurers.gear.worn[id], {})
	assert_true(recruits.candidates[1].is_empty())
	assert_false(recruits.candidates[0].is_empty())


func test_an_emptied_slot_refills_exactly_1800_seconds_after_the_hire_and_not_before() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START + 100)
	assert_eq(recruits.seconds_to_refill(0, START + 100), 1_800)
	recruits.refill(adventurers, START + 1_899)
	assert_true(recruits.candidates[0].is_empty())
	assert_eq(recruits.seconds_to_refill(0, START + 1_899), 1)
	recruits.refill(adventurers, START + 1_900)
	assert_false(recruits.candidates[0].is_empty())


func test_each_slot_counts_down_on_its_own() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START)
	_hire(recruits, 1, adventurers, START + 600)
	recruits.refill(adventurers, START + 1_800)
	assert_false(recruits.candidates[0].is_empty())
	assert_true(recruits.candidates[1].is_empty())
	assert_eq(recruits.seconds_to_refill(1, START + 1_800), 600)
	recruits.refill(adventurers, START + 2_400)
	assert_false(recruits.candidates[1].is_empty())


func test_one_refill_after_an_absence_gives_the_same_candidates_as_refilling_every_second() -> void:
	var watched_guild := Adventurers.new()
	var watched := _recruits(watched_guild)
	var away_guild := Adventurers.new()
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
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START)
	_hire(recruits, 1, adventurers, START + 1_000)
	recruits.refill(adventurers, START + 1_800)
	var refilled := recruits.candidates[0]
	assert_false(refilled.is_empty())

	recruits.refill(adventurers, START)
	assert_eq(recruits.candidates[0], refilled)
	assert_true(recruits.candidates[1].is_empty())
	assert_eq(recruits.seconds_to_refill(1, START), 1_000)
	recruits.refill(adventurers, START + 2_800)
	assert_false(recruits.candidates[1].is_empty())


func test_candidates_and_countdowns_survive_save_and_load() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 1, adventurers, START + 50)
	var file := ConfigFile.new()
	recruits.write(file)
	adventurers.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Recruits.load_or_start(SAVE_PATH)
	var loaded_guild := Adventurers.load_or_start(SAVE_PATH)
	assert_eq(loaded.candidates, recruits.candidates)
	assert_eq(loaded.refill_at, recruits.refill_at)
	assert_eq(loaded.checked_at, START + 50)
	assert_eq(loaded.seconds_to_refill(1, START + 50), 1_800)
	loaded.refill(loaded_guild, START + 1_850)
	recruits.refill(adventurers, START + 1_850)
	assert_false(loaded.candidates[1].is_empty())
	assert_eq(loaded.candidates, recruits.candidates)


func test_the_same_slot_and_time_always_bring_the_same_candidate_whatever_the_global_generator() -> void:
	seed(1)
	var first := _recruits(Adventurers.new())
	seed(2)
	randi()
	var second := _recruits(Adventurers.new())
	assert_eq(second.candidates, first.candidates)
	var later := Recruits.new()
	later.refill(Adventurers.new(), START + 1)
	assert_ne(later.candidates, first.candidates)


func test_a_candidate_is_never_named_after_anyone_in_the_guild_or_the_other_candidate() -> void:
	var only_free := Recruits.NAMES[7]
	var taken := Recruits.NAMES.duplicate()
	taken.remove_at(7)
	for at: int in 20:
		assert_eq(Recruits.candidate_for(0, START + at, taken)["who"]["name"], only_free)

	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	# Hires fill the guild with recruits, each named apart from everyone already in it.
	for at: int in range(START, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS, Recruits.CANDIDATE_REFILL_SECONDS):
		recruits.refill(adventurers, at)
		assert_ne(recruits.candidates[0]["who"]["name"], recruits.candidates[1]["who"]["name"])
		for candidate: Dictionary in recruits.candidates:
			assert_does_not_have(_names(adventurers), candidate["who"]["name"])
		_hire(recruits, 0, adventurers, at)
	assert_eq(adventurers.roster.size(), 8)


func test_two_stats_show_before_a_hire_and_all_four_are_known_after() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	var candidate := recruits.candidates[0]
	var line := Recruits.stats_line(candidate)
	assert_eq(line.count("?"), 2, line)
	assert_eq(line.split(" · ").size(), 4, line)
	for stat: String in candidate["shown"]:
		assert_string_contains(line, "%s %d" % [Adventurers.STATS[stat], candidate["stats"][stat]])
	assert_eq(Array(candidate["shown"]).size(), 2)

	_hire(recruits, 0, adventurers, START)
	var id: String = adventurers.roster.keys()[4]
	for stat: String in Adventurers.STATS:
		assert_eq(adventurers.stat_total(id, stat), candidate["stats"][stat], stat)


func test_about_one_in_ten_candidates_is_a_late_bloomer_weaker_but_growing_far_faster_in_their_main_stat() -> void:
	var bloomers := 0
	var bloomer_stats := 0
	var other_stats := 0
	for at: int in 2_000:
		var candidate := Recruits.candidate_for(at % 2, START + at, PackedStringArray())
		var main := MAIN_STAT[candidate["who"]["class"]]
		var total := 0
		for stat: String in Adventurers.STATS:
			total += int(candidate["stats"][stat])
		if candidate["growth"][main] >= 0.9:
			bloomers += 1
			bloomer_stats += total
		else:
			assert_lt(float(candidate["growth"][main]), 0.7, candidate["who"]["class"])
			other_stats += total
	assert_between(bloomers, 140, 260)
	assert_lt(bloomer_stats / float(bloomers), other_stats / float(2_000 - bloomers) - 2.0)


func test_a_hire_is_refused_with_nothing_changed_when_gold_is_short_or_every_bed_is_taken() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	var before := recruits.candidates.duplicate(true)
	var short := Gold.new(99)
	assert_eq(Recruits.refusal(adventurers, short, 6), "Not enough gold")
	assert_false(recruits.hire(0, adventurers, short, 6, START))
	var full := Gold.new(500)
	assert_eq(Recruits.refusal(adventurers, full, 4), "No free bed — convert a Bunk room")
	assert_false(recruits.hire(0, adventurers, full, 4, START))
	assert_eq(short.amount, 99)
	assert_eq(full.amount, 500)
	assert_eq(adventurers.roster.size(), 4)
	assert_eq(recruits.candidates, before)
	# With the gold and a bed, the same hire goes through.
	assert_eq(Recruits.refusal(adventurers, Gold.new(100), 5), "")
	assert_true(recruits.hire(0, adventurers, full, 5, START))
	assert_eq(adventurers.roster.size(), 5)


func test_with_every_bed_taken_a_bunk_room_is_suggested_only_below_the_most_beds_there_can_be() -> void:
	var adventurers := Adventurers.new()
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
	assert_eq(Recruits.refusal(Adventurers.new(), gold, 4), "No free bed — convert a Bunk room")
	assert_eq(Recruits.refusal(Adventurers.new(), gold, 6), "")


func test_a_hired_shield_bearer_can_be_sent_on_a_quest_and_covers_protect() -> void:
	var dispatch := Dispatch.new(START)
	var recruits := Recruits.new()
	var at := START
	recruits.refill(dispatch.adventurers, at)
	while recruits.candidates[0]["who"]["class"] != "Shield bearer":
		at += 1
		recruits = Recruits.new()
		recruits.refill(dispatch.adventurers, at)
	assert_true(recruits.hire(0, dispatch.adventurers, Gold.new(100), 5, at))
	var id: String = dispatch.adventurers.roster.keys()[4]
	var party := PackedStringArray([id])
	assert_eq(Challenges.covered_by("Protect", party, dispatch.adventurers.roster), party)
	assert_eq(Challenges.covered_by("Protect", PackedStringArray(["bram", "ilse", "tobin", "maren"]), dispatch.adventurers.roster), PackedStringArray())
	assert_eq(dispatch.party_refusal("letters", party, at), "")
	assert_true(dispatch.send("letters", party, 7, Gold.new(0), at))
	assert_eq(dispatch.quest_of(id), "letters")


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
		var recruits := Recruits.new()
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
	var adventurers := Adventurers.new()
	var recruits := _with_rooms(adventurers, START + 1_000, [START + 500])
	assert_eq(recruits.candidates.size(), 3)
	assert_false(recruits.candidates[2].is_empty())
	# A hired candidate's id records the slot and the moment they arrived.
	_hire(recruits, 2, adventurers, START + 1_000)
	assert_true(adventurers.roster.has("recruit_2_%d" % (START + 500)), str(adventurers.roster.keys()))


func test_common_rooms_add_slots_up_to_four_in_all() -> void:
	assert_eq(_with_rooms(Adventurers.new(), START + 1_000, [START + 100, START + 200]).candidates.size(), 4)
	var many := _with_rooms(Adventurers.new(), START + 1_000, [START + 300, START + 100, START + 200, START + 400])
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
		# Only the rank can differ from the same candidate without a Common room.
		candidate["who"]["rank"] = "F"
		assert_eq(candidate, plain)
	assert_between(rank_e, 200, 300)


func test_rank_e_starts_from_the_first_common_room_not_a_later_one() -> void:
	# Rooms finished 10 seconds before and 1_000 seconds after slot 0's candidate arrives.
	var recruits := _rank_e_guild(Adventurers.new(), [-10, 1_000])
	if recruits == null:
		return
	assert_eq(recruits.candidates[0]["who"]["rank"], "E")
	assert_lt(recruits.refill_at[0], recruits.refill_at[3])


func test_no_two_candidates_share_a_name_with_four_slots_filled() -> void:
	for at: int in range(START, START + 300):
		var adventurers := Adventurers.new()
		var recruits := Recruits.new()
		recruits.refill(adventurers, at, PackedInt64Array([at, at]))
		var names: Array[String] = []
		for candidate: Dictionary in recruits.candidates:
			assert_does_not_have(names, candidate["who"]["name"], str(at))
			assert_does_not_have(_names(adventurers), candidate["who"]["name"], str(at))
			names.append(candidate["who"]["name"])
		assert_eq(names.size(), 4)


func test_a_rank_e_candidate_costs_180_gold_and_is_refused_with_nothing_changed_when_short() -> void:
	var adventurers := Adventurers.new()
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
	var watched_guild := Adventurers.new()
	var watched := _recruits(watched_guild)
	var away_guild := Adventurers.new()
	var away := _recruits(away_guild)
	var hires: Array[Vector2i] = [Vector2i(START + 5, 0), Vector2i(START + 700, 1), Vector2i(START + 2_600, 2), Vector2i(START + 2_700, 3)]
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
	var adventurers := Adventurers.new()
	var rooms := PackedInt64Array([START + 500])
	var recruits := _with_rooms(adventurers, START + 1_000, [START + 500])
	_hire(recruits, 2, adventurers, START + 1_000)
	recruits.refill(adventurers, START, rooms)
	assert_eq(recruits.candidates.size(), 3)
	assert_true(recruits.candidates[2].is_empty())
	assert_eq(recruits.seconds_to_refill(2, START), 1_800)
	recruits.refill(adventurers, START + 2_800, rooms)
	assert_false(recruits.candidates[2].is_empty())


func test_common_room_slots_and_rank_e_candidates_survive_save_and_load() -> void:
	var adventurers := Adventurers.new()
	var recruits := _rank_e_guild(adventurers)
	if recruits == null:
		return
	var rooms := PackedInt64Array([recruits.checked_at, recruits.checked_at + 10])
	recruits.refill(adventurers, recruits.checked_at + 20, rooms)
	var file := ConfigFile.new()
	recruits.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Recruits.load_or_start(SAVE_PATH)
	assert_eq(loaded.candidates.size(), 4)
	assert_eq(loaded.candidates, recruits.candidates)
	assert_eq(loaded.candidates[0]["who"]["rank"], "E")
	assert_eq(loaded.refill_at, recruits.refill_at)
	loaded.refill(adventurers, loaded.checked_at, rooms)
	assert_eq(loaded.candidates, recruits.candidates)


func test_a_save_with_two_slots_and_no_common_room_loads_with_two_slots_and_a_later_room_adds_one() -> void:
	var adventurers := Adventurers.new()
	var file := ConfigFile.new()
	_recruits(adventurers).write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Recruits.load_or_start(SAVE_PATH)
	loaded.refill(adventurers, START + 5_000)
	assert_eq(loaded.candidates.size(), 2)
	for candidate: Dictionary in loaded.candidates:
		assert_eq(candidate["who"]["rank"], "F")
	loaded.refill(adventurers, START + 5_000, PackedInt64Array([START + 5_000]))
	assert_eq(loaded.candidates.size(), 3)
