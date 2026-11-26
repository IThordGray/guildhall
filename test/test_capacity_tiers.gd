extends GutTest

const SAVE_PATH: String = "user://test_capacity_tiers_save.cfg"
const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
## The moments the player is there to act on the hall in `_act`, and the end of the run.
const PRESENT: Array[int] = [1_000, 1_001, 1_050, 1_100, 1_200, 1_600]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A new game's hall at 1_000, ranked D, with its side room a finished `type` from 1_005 and its
## backroom restored and empty, the builder free, paid from `gold`.
func _hall_with_room(type: String, gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	hall.rank = "D"
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_001)
	assert_true(hall.restore("back_left", gold, 1_001))
	hall.checkpoint(1_003)
	assert_true(hall.convert_room("side_left", type, gold, 1_003), type)
	hall.checkpoint(1_005)
	return hall


## Upgrades the side room of `hall`, as `_hall_with_room` left it, to tier 2, reached at 1_009,
## and tier 3, reached at 1_019; what `read` gives on the way at 1_005 (tier 1), 1_008 (under
## way), 1_009 (tier 2), 1_018 (under way) and 1_019 (tier 3).
func _upgrade_twice(hall: Hall, gold: Gold, read: Callable) -> Array:
	var seen := [read.call(1_005)]
	assert_true(hall.upgrade("side_left", gold, 1_005))
	seen.append_array([read.call(1_008), read.call(1_009)])
	hall.checkpoint(1_009)
	assert_true(hall.upgrade("side_left", gold, 1_009))
	seen.append_array([read.call(1_018), read.call(1_019)])
	return seen


func test_a_bunk_room_gives_2_then_4_then_8_beds_by_tier_and_a_second_one_adds_its_own() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("bunk_room", gold)
	# The Reception's 2 beds and the Bunk room's, at each of `_upgrade_twice`'s times.
	assert_eq(_upgrade_twice(hall, gold, hall.beds), [4, 4, 6, 6, 10])
	hall.checkpoint(1_019)
	assert_true(hall.convert_room("back_left", "bunk_room", gold, 1_019))
	assert_eq(hall.beds(1_020), 10)
	assert_eq(hall.beds(1_021), 12)


func test_the_roster_grows_past_8_to_as_many_as_there_are_beds_and_a_hire_with_every_bed_taken_is_refused() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("bunk_room", gold)
	_upgrade_twice(hall, gold, hall.beds)
	hall.checkpoint(1_019)
	var beds := hall.beds(1_019)
	assert_eq(beds, 10)
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := Recruits.new()
	var at := 1_019
	while adventurers.roster.size() < beds:
		at += Recruits.CANDIDATE_REFILL_SECONDS
		assert_true(recruits.hire(0, adventurers, gold, beds, at), str(at))
	assert_eq(adventurers.roster.size(), 10)
	at += Recruits.CANDIDATE_REFILL_SECONDS
	var paid := gold.amount
	assert_false(recruits.hire(0, adventurers, gold, beds, at))
	assert_eq(adventurers.roster.size(), 10)
	assert_eq(gold.amount, paid)
	# A tier-3 Bunk room below rank D: nothing more to build or upgrade.
	hall.rank = "E"
	assert_eq(Recruits.refusal(adventurers, gold, beds, Recruits.HIRE_GOLD, hall), "No free bed")


func test_with_every_bed_taken_the_refusal_points_at_a_bunk_room_then_its_upgrade_then_a_second_one_then_nothing() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var gold := Gold.new(10_000)
	var hall := Hall.new(1_000)
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed — convert a Bunk room")
	assert_eq(Recruits.bed_refusal(adventurers, 5, hall), "")
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_001)
	assert_true(hall.restore("back_left", gold, 1_001))
	hall.checkpoint(1_003)
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_003))
	# Being built: nothing to do but wait.
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed")
	hall.checkpoint(1_005)
	assert_eq(hall.rank, "F")
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed — upgrade the Bunk room")
	assert_true(hall.upgrade("side_left", gold, 1_005))
	# Being upgraded at rank F: no second one yet.
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed")
	hall.checkpoint(1_009)
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed — upgrade the Bunk room")
	assert_true(hall.upgrade("side_left", gold, 1_009))
	hall.checkpoint(1_019)
	assert_eq(hall.tier("side_left", 1_019), 3)
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed")
	hall.rank = "D"
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed — convert a second Bunk room")
	assert_true(hall.convert_room("back_left", "bunk_room", gold, 1_019))
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed")
	hall.checkpoint(1_021)
	assert_eq(Recruits.bed_refusal(adventurers, 4, hall), "No free bed — upgrade the Bunk room")


func test_the_stash_holds_6_then_12_then_20_more_by_storeroom_tier() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("storeroom", gold)
	assert_eq(hall.reception("stash"), 6)
	# At each of `_upgrade_twice`'s times.
	assert_eq(_upgrade_twice(hall, gold, hall.stash_cap), [12, 12, 18, 18, 26])


func test_a_common_room_and_a_quest_hall_add_1_then_2_then_2_slots_each_from_the_moment_its_tier_was_reached() -> void:
	for room: Array in [["common_room", "candidate_slots"], ["quest_hall", "board_slots"]]:
		var gold := Gold.new(10_000)
		var hall := _hall_with_room(room[0], gold)
		assert_eq(hall.added_at(room[1]), PackedInt64Array([1_005]), room[0])
		var base := hall.reception(room[1])
		# At each of `_upgrade_twice`'s times.
		var seen := _upgrade_twice(hall, gold, func(at: int) -> int: return hall.capacity(room[1], at) - base)
		assert_eq(seen, [1, 1, 2, 2, 2], room[0])
		assert_eq(hall.added_at(room[1]), PackedInt64Array([1_005, 1_009]), room[0])
		hall.checkpoint(1_019)
		assert_eq(hall.tier("side_left", 1_019), 3, room[0])
		assert_eq(hall.added_at(room[1]), PackedInt64Array([1_005, 1_009]), room[0])
		assert_eq(hall.capacity(room[1], 1_019), hall.reception(room[1]) + 2, room[0])
		# The other capacity, and every other room's, gains nothing.
		var other: String = "board_slots" if room[1] == "candidate_slots" else "candidate_slots"
		assert_eq(hall.added_at(other), PackedInt64Array(), room[0])
		assert_eq(hall.added_at("beds"), PackedInt64Array(), room[0])


## What the player does to `hall` at `at`, a time in PRESENT, paying from `gold`: builds a `type`
## (restored at 1_001, finished at 1_003), and upgrades it at 1_100 (tier 2 at 1_104) and at 1_200
## (tier 3 at 1_210).
func _act(hall: Hall, type: String, gold: Gold, at: int) -> void:
	match at:
		1_000:
			assert_true(hall.restore("side_left", gold, at))
		1_001:
			assert_true(hall.convert_room("side_left", type, gold, at))
		1_100, 1_200:
			assert_true(hall.upgrade("side_left", gold, at))


func test_after_an_absence_spanning_a_quest_halls_upgrades_the_board_is_as_if_refilled_every_second() -> void:
	var watched_hall := Hall.new(1_000)
	var away_hall := Hall.new(1_000)
	var watched := Board.new()
	var away := Board.new()
	var watched_dispatch := Dispatch.new(1_000)
	var away_dispatch := Dispatch.new(1_000)
	var gold := Gold.new(10_000)
	var sizes := {}
	for hall: Hall in [watched_hall, away_hall]:
		hall.rank = "D"
	for at: int in range(1_000, 1_601):
		_act(watched_hall, "quest_hall", gold, at)
		watched_hall.checkpoint(at)
		watched.refill(watched_dispatch, at, watched_hall.added_at("board_slots"))
		sizes[at] = watched.slots.size()
		if at in PRESENT:
			_act(away_hall, "quest_hall", gold, at)
			away_hall.checkpoint(at)
			away.refill(away_dispatch, at, away_hall.added_at("board_slots"))
	# The Reception's 2, the Quest hall's from 1_003 and its tier 2's from 1_104, never earlier.
	for at: Array in [[1_002, 2], [1_003, 3], [1_103, 3], [1_104, 4], [1_600, 4]]:
		assert_eq(sizes[at[0]], at[1], str(at[0]))
	assert_eq(away.slots, watched.slots)
	assert_eq(away.refill_at, watched.refill_at)
	assert_eq(away.filled_at, watched.filled_at)
	assert_eq(away.slots.count(""), 0)


func test_after_an_absence_spanning_a_common_rooms_upgrades_the_candidates_are_as_if_refilled_every_second() -> void:
	var watched_hall := Hall.new(1_000)
	var away_hall := Hall.new(1_000)
	var watched := Recruits.new()
	var away := Recruits.new()
	var watched_guild := Adventurers.new()
	var away_guild := Adventurers.new()
	var gold := Gold.new(10_000)
	var sizes := {}
	for hall: Hall in [watched_hall, away_hall]:
		hall.rank = "D"
	for at: int in range(1_000, 1_601):
		_act(watched_hall, "common_room", gold, at)
		watched_hall.checkpoint(at)
		watched.refill(watched_guild, at, watched_hall.added_at("candidate_slots"))
		if at == 1_050:
			assert_true(watched.hire(1, watched_guild, gold, 100, at, watched_hall.added_at("candidate_slots")))
		sizes[at] = watched.candidates.size()
		if at in PRESENT:
			_act(away_hall, "common_room", gold, at)
			away_hall.checkpoint(at)
			away.refill(away_guild, at, away_hall.added_at("candidate_slots"))
			if at == 1_050:
				assert_true(away.hire(1, away_guild, gold, 100, at, away_hall.added_at("candidate_slots")))
	# The Reception's 1, the Common room's from 1_003 and its tier 2's from 1_104, never earlier.
	for at: Array in [[1_002, 1], [1_003, 2], [1_103, 2], [1_104, 3], [1_600, 3]]:
		assert_eq(sizes[at[0]], at[1], str(at[0]))
	assert_eq(away.candidates, watched.candidates)
	assert_eq(away.refill_at, watched.refill_at)
	assert_eq(away_guild.roster, watched_guild.roster)
	# The tier-2 slot's first candidate arrived when tier 2 was reached.
	assert_false(away.candidates[2].is_empty())
	assert_eq(away.refill_at[2], 1_104)


func test_an_old_save_loads_with_the_same_rooms_and_tiers_and_a_tier_2_bunk_room_now_gives_4_beds() -> void:
	# What a build before tier times saved: a tier-2 Bunk room and a tier-3 Storeroom.
	var file := ConfigFile.new()
	file.set_value("hall", "layout", Hall.NEW_LAYOUT)
	file.set_value("hall", "restored", PackedStringArray(["side_left", "back_left"]))
	file.set_value("hall", "converted", {
		"side_left": {"type": "bunk_room", "done_at": 1_100, "tier": 2},
		"back_left": {"type": "storeroom", "done_at": 1_200, "tier": 3},
	})
	file.set_value("hall", "checked_at", 1_300)
	assert_eq(file.save(SAVE_PATH), OK)

	var hall := Hall.load_or_start(SAVE_PATH, 1_400)
	assert_eq([hall.room_type("side_left"), hall.tier("side_left", 1_400)], ["bunk_room", 2])
	assert_eq([hall.room_type("back_left"), hall.tier("back_left", 1_400)], ["storeroom", 3])
	# The Reception's 2 beds and a tier-2 Bunk room's 4; its 6 stash slots and a tier-3 Storeroom's 20.
	assert_eq(hall.beds(1_400), 6)
	assert_eq(hall.stash_cap(1_400), 26)
	file = ConfigFile.new()
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var reloaded := Hall.load_or_start(SAVE_PATH, 1_400)
	assert_eq(reloaded.converted, hall.converted)
	assert_eq(reloaded.beds(1_400), 6)
	assert_eq(reloaded.stash_cap(1_400), 26)
