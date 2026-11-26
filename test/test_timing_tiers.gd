extends GutTest

const Fixtures := preload("res://test/fixtures.gd")

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
const NONE: PackedInt64Array = []


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


## `_hall_with_room` with its room upgraded at 1_005 and 1_009: tier 2 from 1_009, tier 3 from
## 1_019, the second upgrade still under way.
func _hall_at_tier_3(type: String, gold: Gold) -> Hall:
	var hall := _hall_with_room(type, gold)
	assert_true(hall.upgrade("side_left", gold, 1_005))
	hall.checkpoint(1_009)
	assert_true(hall.upgrade("side_left", gold, 1_009))
	return hall


## A guild of the four starters at `at`, nobody out or training.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


## Sends `who` alone on `quest` at `at`, leaving with 1 health, so they come home injured.
func _send_worn_out(dispatch: Dispatch, who: String, quest: String, at: int, infirmary_tiers: PackedInt64Array) -> void:
	assert_true(dispatch.send(quest, Fixtures.party(dispatch, [who]), 1, at, infirmary_tiers), who)
	for outing: Dictionary in dispatch.outings:
		if who in outing["party"]:
			outing["health"][who] = 1


## A board of `quests` in that order, each put there at `at`.
func _board_of(quests: Array[String], at: int) -> Board:
	var board := Board.new()
	board.reception_slots = quests.size()
	board.slots = PackedStringArray(quests)
	board.refill_at.resize(quests.size())
	board.filled_at.resize(quests.size())
	board.filled_at.fill(at)
	board.checked_at = at
	return board


# The board as saved and the quests `dispatch` has revealed. Party names are drawn from the global
# generator, so the rest of the guild is left out.
func _saved(dispatch: Dispatch, board: Board) -> String:
	var file := ConfigFile.new()
	file.set_value("dispatch", "revealed", dispatch.revealed)
	board.write(file)
	return file.encode_to_text()


# --- Hall ---


func test_a_rooms_tier_times_are_when_each_tier_was_reached_an_upgrade_under_way_at_its_finish() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("infirmary", gold)
	assert_eq(hall.tier_times("infirmary"), PackedInt64Array([1_005]))
	assert_true(hall.upgrade("side_left", gold, 1_005))
	assert_eq(hall.tier_times("infirmary"), PackedInt64Array([1_005, 1_009]))
	hall.checkpoint(1_009)
	assert_true(hall.upgrade("side_left", gold, 1_009))
	assert_eq(hall.tier_times("infirmary"), PackedInt64Array([1_005, 1_009, 1_019]))
	hall.checkpoint(1_019)
	assert_eq(hall.tier_times("infirmary"), PackedInt64Array([1_005, 1_009, 1_019]))
	assert_eq(hall.tier_times("map_room"), NONE)


# --- Infirmary ---


func test_healing_runs_2_then_3_then_4_times_as_fast_from_the_moment_the_infirmary_reached_each_tier() -> void:
	var dispatch := _guild(1_000)
	var tiers := PackedInt64Array([1_004, 1_006, 1_008])
	# Bram, 28 at most, back at 1_002 with 1: 2 s at 1×, 2 s at 2×, 2 s at 3×, then 4×, three points
	# per two seconds' worth.
	_send_worn_out(dispatch, "bram", "rats", 1_000, tiers)
	dispatch.checkpoint(1_002, tiers)
	var healths: Array[int] = []
	for at: int in [1_002, 1_004, 1_006, 1_008, 1_009, 1_010]:
		healths.append(dispatch.health("bram", at))
	assert_eq(healths, [1, 4, 10, 19, 25, 28])
	assert_eq(dispatch.seconds_to_full("bram", 1_002), 8)
	assert_eq(dispatch.seconds_to_full("bram", 1_007), 3)
	assert_eq(dispatch.seconds_to_full("bram", 1_010), 0)


func test_an_injury_lasts_10_then_5_3_and_2_seconds_by_the_infirmarys_tier_at_the_return() -> void:
	var tiers := PackedInt64Array([1_010, 1_020, 1_030])
	# Returning at each time, and how long the injury lasts.
	for back: Array in [[1_005, 10], [1_012, 5], [1_020, 3], [1_029, 3], [1_032, 2]]:
		var dispatch := _guild(1_000)
		_send_worn_out(dispatch, "tobin", "rats", back[0] - 2, tiers)
		dispatch.checkpoint(back[0], tiers)
		assert_eq(dispatch.injury_seconds("tobin"), back[1], str(back[0]))
		assert_eq(dispatch.injury_left("tobin", back[0]), back[1], str(back[0]))


## The four starters sent by a player who, with the Infirmary finished at 1_005, starts its tier-2
## upgrade at 1_005 and sends Bram (back 1_017) and Tobin (back 1_008), then starts tier 3 at 1_009
## (reached at 1_019) and sends Ilse (back 1_019) and Maren (back 1_015), all leaving with 1 health,
## and is away until `end`: checking once then, or every second when `step`.
func _infirmary_run(step: bool, end: int) -> Dispatch:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("infirmary", gold)
	var dispatch := _guild(1_005)
	assert_true(hall.upgrade("side_left", gold, 1_005))
	_send_worn_out(dispatch, "bram", "sealed_door", 1_005, hall.tier_times("infirmary"))
	_send_worn_out(dispatch, "tobin", "well", 1_005, hall.tier_times("infirmary"))
	hall.checkpoint(1_009)
	assert_true(hall.upgrade("side_left", gold, 1_009))
	_send_worn_out(dispatch, "ilse", "wolves", 1_009, hall.tier_times("infirmary"))
	_send_worn_out(dispatch, "maren", "moonherbs", 1_009, hall.tier_times("infirmary"))
	for second: int in range(1_010 if step else end, end + 1):
		hall.checkpoint(second)
		dispatch.checkpoint(second, hall.tier_times("infirmary"))
	return dispatch


# Each starter's health, injury left, injury length and seconds to full health at `at`.
func _recovery(dispatch: Dispatch, at: int) -> Array:
	var seen := []
	for adventurer: String in EVERYONE:
		seen.append([dispatch.health(adventurer, at), dispatch.injury_left(adventurer, at), dispatch.injury_seconds(adventurer), dispatch.seconds_to_full(adventurer, at)])
	return seen


func test_one_checkpoint_after_an_absence_spanning_an_infirmary_upgrade_gives_the_same_health_and_injuries_as_checking_every_second() -> void:
	for end: int in [1_018, 1_020, 1_023]:
		var away := _infirmary_run(false, end)
		assert_eq(_recovery(away, end), _recovery(_infirmary_run(true, end), end), str(end))
	# What it played out at 1_020: Bram back at tier 2 and healing across tier 3, Ilse back at tier 3,
	# Tobin back at tier 1.
	var at_1_020 := _recovery(_infirmary_run(false, 1_020), 1_020)
	var healths := []
	var lengths := []
	for seen: Array in at_1_020:
		healths.append(seen[0])
		lengths.append(seen[2])
	assert_eq(healths, [16, 7, 16, 20])
	assert_eq(lengths, [3, 2, 5, 3])


# --- Map room ---


func test_unknown_challenges_reveal_10_then_5_seconds_after_a_quest_reaches_the_board_then_at_once_by_the_map_rooms_tier() -> void:
	var reached := PackedInt64Array([900, 920, 940])
	for tier: int in [1, 2, 3]:
		var dispatch := _guild(1_000)
		# Each with an unknown challenge until revealed.
		var board := _board_of(["moonherbs", "wolves", "crypt"], 1_000)
		board.refill(dispatch, 1_000, NONE, reached.slice(0, tier))
		var waiting := []
		for quest: String in board.slots:
			waiting.append(board.seconds_to_reveal(quest, dispatch, 1_000))
		assert_eq(waiting, [[10, 10, 10], [5, 5, 5], [-1, -1, -1]][tier - 1], str(tier))
		for quest: String in board.slots:
			assert_eq(dispatch.unknown_challenges(quest).is_empty(), tier == 3, quest)


func test_a_quest_on_the_board_when_the_map_room_reaches_a_higher_tier_reveals_at_the_earlier_of_its_old_time_and_the_new_tiers() -> void:
	# Put on the board at 1_000 with tier 1 from 900: due at 1_010.
	for case: Array in [
		# Tier 2 at 1_003: 1_008, sooner than 1_010.
		[PackedInt64Array([900, 1_003]), 8],
		# Tier 2 at 1_007: 1_012, later, so 1_010 stands.
		[PackedInt64Array([900, 1_007]), 10],
		# Tier 2 at 1_004 (1_009), then tier 3 at 1_006: at once then.
		[PackedInt64Array([900, 1_004, 1_006]), 6],
	]:
		var dispatch := _guild(1_000)
		var board := _board_of(["crypt"], 1_000)
		board.refill(dispatch, 1_000, NONE, case[0])
		assert_eq(board.seconds_to_reveal("crypt", dispatch, 1_000), case[1], str(case[0]))


## A new board from 1_000 for a guild whose `type` room is finished at 1_005 and upgraded by a
## player there at each time in `upgrades`, then away until `end`: refilled at those moments and
## at `end`, or every second when `step`. The guild and the board.
func _board_run(type: String, upgrades: Array, step: bool, end: int) -> Array:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room(type, gold)
	var dispatch := _guild(1_000)
	var board := Board.new()
	board.reception_slots = hall.reception("board_slots")
	for second: int in range(1_000, end + 1):
		if not (step or second == 1_000 or second == end or second in upgrades):
			continue
		hall.checkpoint(second)
		if second in upgrades:
			assert_true(hall.upgrade("side_left", gold, second), str(second))
		dispatch.checkpoint(second, hall.tier_times("infirmary"))
		board.refill(dispatch, second, hall.added_at("board_slots"), hall.tier_times("map_room"), hall.tier_times("quest_hall"))
	return [dispatch, board]


func test_one_refill_after_an_absence_spanning_a_map_room_upgrade_reveals_the_same_as_refilling_every_second() -> void:
	var upgrades := [1_005, 1_009]
	for end: int in [1_014, 1_200]:
		var away := _board_run("map_room", upgrades, false, end)
		var watched := _board_run("map_room", upgrades, true, end)
		assert_eq(_saved(away[0], away[1]), _saved(watched[0], watched[1]), str(end))
	# The quests put on the board at 1_000 would reveal at 1_015 at tier 1; tier 2 from 1_009 reveals
	# them at 1_014.
	var at_tier_1 := _board_run("map_room", [], false, 1_014)
	var at_tier_2 := _board_run("map_room", upgrades, false, 1_014)
	var with_unknowns := 0
	for quest: String in at_tier_2[1].slots:
		if Dispatch.QUESTS[quest]["challenges"].size() > 1:
			with_unknowns += 1
			assert_false(at_tier_1[0].unknown_challenges(quest).is_empty(), quest)
			assert_true(at_tier_2[0].unknown_challenges(quest).is_empty(), quest)
	assert_gt(with_unknowns, 0)


# --- Quest hall ---


func test_at_tier_3_a_quest_hall_halves_every_board_slots_refill_from_the_moment_tier_3_was_reached() -> void:
	# Sent at each time, and how long its slot takes to refill: 20 s for rank F, 60 for E, halved
	# from 1_019.
	for case: Array in [[1_018, "rats", 20], [1_019, "rats", 10], [1_019, "wolves", 30]]:
		var gold := Gold.new(10_000)
		var hall := _hall_at_tier_3("quest_hall", gold)
		var dispatch := _guild(1_000)
		var board := _board_of(["rats", "wolves"], 1_000)
		hall.checkpoint(case[0])
		assert_true(board.send(dispatch, case[1], Fixtures.party(dispatch, ["bram"]), 1, case[0], hall.added_at("board_slots"), NONE, NONE, hall.tier_times("quest_hall")), str(case))
		var slot := 0 if case[1] == "rats" else 1
		assert_eq(board.seconds_to_refill(slot, dispatch, case[0]), case[2], str(case))
	# A quest leaving the board unsent: rats, put there at 1_000, leaves at 1_060 and its slot
	# refills 10 s later.
	var gold := Gold.new(10_000)
	var hall := _hall_at_tier_3("quest_hall", gold)
	var dispatch := _guild(1_000)
	var board := _board_of(["rats"], 1_000)
	board.refill(dispatch, 1_065, NONE, NONE, hall.tier_times("quest_hall"))
	assert_eq(board.slots[0], "")
	assert_eq(board.seconds_to_refill(0, dispatch, 1_065), 5)


func test_one_refill_after_an_absence_spanning_a_quest_hall_reaching_tier_3_gives_the_same_board_as_refilling_every_second() -> void:
	var upgrades := [1_005, 1_009]
	var away := _board_run("quest_hall", upgrades, false, 1_400)
	var watched := _board_run("quest_hall", upgrades, true, 1_400)
	assert_eq(_saved(away[0], away[1]), _saved(watched[0], watched[1]))
	# The faster refill changed the board: tier 2 alone gives another.
	var at_tier_2 := _board_run("quest_hall", [1_005], false, 1_400)
	assert_ne(away[1].refill_at, at_tier_2[1].refill_at)


# --- Common room ---


func test_at_tier_3_a_common_room_halves_every_candidate_slots_refill_from_the_moment_tier_3_was_reached() -> void:
	for case: Array in [[1_018, 60], [1_019, 30]]:
		var gold := Gold.new(10_000)
		var hall := _hall_at_tier_3("common_room", gold)
		var adventurers := Adventurers.new(EVERYONE)
		var recruits := Recruits.new()
		hall.checkpoint(case[0])
		assert_true(recruits.hire(0, adventurers, gold, 99, case[0], hall.added_at("candidate_slots"), "", -1, hall.tier_times("common_room")), str(case))
		assert_eq(recruits.seconds_to_refill(0, case[0]), case[1], str(case))


## A Common room finished at 1_005, upgraded by the player at 1_005 and 1_009 (tier 3 from 1_019),
## who hires from slot 0 at 1_009 and slot 1 at 1_020 and is then away until `end`: candidates
## refilled at those moments and at `end`, or every second when `step`.
func _candidates_run(step: bool, end: int) -> Recruits:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("common_room", gold)
	var adventurers := Adventurers.new(EVERYONE)
	var recruits := Recruits.new()
	var hires := {1_009: 0, 1_020: 1}
	for second: int in range(1_005, end + 1):
		if not (step or second == 1_005 or second == end or hires.has(second)):
			continue
		hall.checkpoint(second)
		if second == 1_005 or second == 1_009:
			assert_true(hall.upgrade("side_left", gold, second))
		recruits.refill(adventurers, second, hall.added_at("candidate_slots"))
		if hires.has(second):
			assert_true(recruits.hire(hires[second], adventurers, gold, 99, second, hall.added_at("candidate_slots"), "", -1, hall.tier_times("common_room")))
	return recruits


func test_one_refill_after_an_absence_gives_the_same_candidates_as_refilling_every_second_with_a_tier_3_common_room() -> void:
	var away := _candidates_run(false, 1_200)
	var watched := _candidates_run(true, 1_200)
	assert_eq(away.candidates, watched.candidates)
	assert_eq(away.refill_at, watched.refill_at)
	# Slot 0 emptied at tier 2 took 60 s; slot 1 emptied at tier 3, 30.
	assert_eq(away.refill_at[0], 1_069)
	assert_eq(away.refill_at[1], 1_050)


# --- Auto's averaged settle ---


## A guild with Bram and Tobin on Auto, Bold, and room in the stash for anything, whose questing
## over ten days from 1_000 is settled by averages, its Infirmary and Quest hall reaching their tiers
## at `infirmary_tiers` and `quest_hall_tiers`: how many quests it came back from.
func _ten_days_averaged(infirmary_tiers: PackedInt64Array, quest_hall_tiers: PackedInt64Array) -> int:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, dispatch))
	assert_true(parties.move("maren", parties.party_of("ilse"), dispatch))
	var first := parties.party_of("bram")
	parties.set_auto(first, true)
	parties.set_mode(first, Parties.BOLD)
	dispatch.adventurers.gear.stash_cap = 100_000
	var board := Board.new()
	board.reception_slots = 3
	var halls := PackedInt64Array([1_000, 1_000])
	board.refill(dispatch, 1_000, halls)
	Auto.checkpoint(dispatch, board, 1_000 + 10 * 86_400, halls, infirmary_tiers, NONE, quest_hall_tiers)
	var done := 0
	for quest: String in dispatch.tries:
		done += dispatch.tries[quest]
	return done


func test_autos_averaged_settle_uses_the_faster_refill_once_the_quest_hall_reaches_tier_3() -> void:
	var slow := _ten_days_averaged(NONE, PackedInt64Array([1_000, 1_000]))
	var halfway := _ten_days_averaged(NONE, PackedInt64Array([1_000, 1_000, 1_000 + 5 * 86_400]))
	var fast := _ten_days_averaged(NONE, PackedInt64Array([1_000, 1_000, 1_000]))
	assert_gt(halfway, slow)
	assert_gt(fast, halfway)


func test_autos_averaged_settle_heals_faster_at_each_infirmary_tier() -> void:
	var done := []
	for tiers: PackedInt64Array in [PackedInt64Array([1_000]), PackedInt64Array([1_000, 1_000]), PackedInt64Array([1_000, 1_000, 1_000])]:
		done.append(_ten_days_averaged(tiers, NONE))
	assert_gt(done[1], done[0])
	assert_gt(done[2], done[1])


# --- Upgrade cards ---


func test_the_upgrade_cards_say_the_infirmary_heals_faster_the_map_room_reveals_sooner_then_at_once_and_tier_3_refills_twice_as_fast() -> void:
	var says: Dictionary[String, Array] = {
		"infirmary": ["Heals faster, shorter injuries", "Heals faster, shorter injuries"],
		"map_room": ["Reveals sooner", "Reveals at once"],
		"quest_hall": ["", "Slots refill twice as fast"],
		"common_room": ["", "Slots refill twice as fast"],
	}
	for type: String in says:
		var gold := Gold.new(10_000)
		var hall := _hall_with_room(type, gold)
		assert_eq(hall.next_upgrade("side_left", 1_005).get("blurb", ""), says[type][0], type)
		assert_true(hall.upgrade("side_left", gold, 1_005), type)
		hall.checkpoint(1_009)
		assert_eq(hall.next_upgrade("side_left", 1_009).get("blurb", ""), says[type][1], type)
