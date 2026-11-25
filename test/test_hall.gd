extends GutTest

const Fixtures := preload("res://test/fixtures.gd")

const SAVE_PATH: String = "user://test_hall_save.cfg"


## A hall with the six ground-floor rooms of one saved before guild ranks, at `at`, at a rank that
## opens every room type and Extend.
func _six_room_hall(at: int) -> Hall:
	var hall := Hall.new(at)
	hall.layout = Hall.OLD_LAYOUT
	hall.rank = "D"
	return hall


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_a_new_game_is_a_rank_f_guild_with_three_rooms_bram_and_tobin_100_gold_and_what_its_reception_gives() -> void:
	var hall := Hall.load_or_start(SAVE_PATH, 1_000)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	var gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(hall.rank, "F")
	assert_eq(hall.state("reception", 1_000), Hall.State.USABLE)
	assert_eq(hall.state("side_left", 1_000), Hall.State.DAMAGED)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)
	for slot: String in ["back_right", "side_right", "entrance", "upper_nw", "upper_ne", "upper_sw", "upper_se"]:
		assert_eq(hall.state(slot, 1_000), Hall.State.UNBUILT, slot)
	assert_eq(hall.refusal("back_right", Gold.new(1_000), 1_000), "Not damaged")
	assert_eq(dispatch.adventurers.roster.keys(), ["bram", "tobin"])
	assert_eq(dispatch.adventurers.gear.worn.keys(), ["bram", "tobin"])
	assert_eq(dispatch.adventurers.gear.worn["tobin"], Gear.STARTER_GEAR["tobin"])
	assert_eq(gold.amount, 100)
	# The first restoration is affordable at once.
	assert_eq(hall.next_restore(), {"gold": 60, "seconds": 1})
	assert_eq(hall.refusal("side_left", gold, 1_000), "")
	assert_eq(hall.beds(1_000), 2)
	# As the game takes them from the hall: one candidate slot, two board slots, a stash of six.
	var recruits := Recruits.load_or_start(SAVE_PATH)
	recruits.reception_slots = hall.reception("candidate_slots")
	recruits.refill(dispatch.adventurers, 1_000)
	assert_eq(recruits.candidates.size(), 1)
	var board := Board.load_or_start(SAVE_PATH)
	board.reception_slots = hall.reception("board_slots")
	board.refill(dispatch, 1_000, PackedInt64Array())
	assert_eq(board.slots.size(), 2)
	assert_eq(board.filled(), 2)
	var gear := dispatch.adventurers.gear
	gear.stash_cap = hall.reception("stash")
	for i: int in 6:
		assert_true(gear.stow("belt"))
	assert_false(gear.stow("belt"))
	assert_eq(gear.stash.size(), 6)


func test_a_six_room_hall_has_the_entrance_and_reception_usable_and_other_rooms_damaged() -> void:
	var hall := _six_room_hall(1_000)
	assert_eq(hall.state("entrance", 1_000), Hall.State.USABLE)
	assert_eq(hall.state("reception", 1_000), Hall.State.USABLE)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)


func test_restoring_the_first_damaged_room_takes_60_gold_at_once() -> void:
	var gold := Gold.new(150)
	var hall := _six_room_hall(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_eq(gold.amount, 90)
	assert_eq(hall.state("back_left", 1_000), Hall.State.RESTORING)


func test_each_room_restored_costs_and_takes_at_least_the_last_60g_1s_60g_2s_120g_4s_then_200g_10s() -> void:
	var expected := [[60, 1], [60, 2], [120, 4], [200, 10]]
	var slots: Array[String] = ["back_left", "back_right", "side_left", "side_right"]
	var gold := Gold.new(1_000)
	var hall := _six_room_hall(1_000)
	var now := 1_000
	for i: int in slots.size():
		assert_eq(hall.next_restore(), {"gold": expected[i][0], "seconds": expected[i][1]}, str(i))
		assert_true(hall.restore(slots[i], gold, now))
		assert_eq(hall.job_seconds(), expected[i][1], str(i))
		assert_eq(hall.seconds_left(now), expected[i][1], str(i))
		# The one under way counts: the card offers the one after it.
		if i + 1 < slots.size():
			assert_eq(hall.next_restore()["gold"], expected[i + 1][0], str(i))
		now += expected[i][1]
		assert_eq(hall.state(slots[i], now - 1), Hall.State.RESTORING, str(i))
		assert_eq(hall.state(slots[i], now), Hall.State.RESTORED, str(i))
		hall.checkpoint(now)
	assert_eq(gold.amount, 1_000 - 60 - 60 - 120 - 200)


func test_restoring_is_refused_with_the_shortfall_when_gold_is_short() -> void:
	var gold := Gold.new(40)
	var hall := _six_room_hall(1_000)
	assert_eq(hall.refusal("back_left", gold, 1_000), "Need 20 more gold")
	assert_false(hall.restore("back_left", gold, 1_000))
	assert_eq(gold.amount, 40)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)
	gold.amount += 20
	assert_eq(hall.refusal("back_left", gold, 1_020), "")


func test_restoring_a_second_room_is_refused_with_the_shortfall_for_the_second_price() -> void:
	var gold := Gold.new(100)
	var hall := _six_room_hall(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	hall.checkpoint(1_030)
	assert_eq(gold.amount, 40)
	assert_eq(hall.refusal("back_right", gold, 1_030), "Need 20 more gold")
	assert_false(hall.restore("back_right", gold, 1_030))
	assert_eq(gold.amount, 40)
	assert_eq(hall.state("back_right", 1_030), Hall.State.DAMAGED)
	gold.amount += 20
	assert_eq(hall.refusal("back_right", gold, 1_030), "")
	assert_true(hall.restore("back_right", gold, 1_030))
	assert_eq(gold.amount, 0)


func test_restoring_is_refused_while_the_builder_is_busy_and_allowed_once_free() -> void:
	var gold := Gold.new(1_000)
	var hall := _six_room_hall(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_eq(hall.refusal("back_right", gold, 1_000), "Builder busy")
	assert_false(hall.restore("back_right", gold, 1_000))
	assert_eq(gold.amount, 940)
	assert_eq(hall.state("back_right", 1_000), Hall.State.DAMAGED)
	assert_true(hall.restore("back_right", gold, 1_001))
	assert_eq(hall.state("back_left", 1_001), Hall.State.RESTORED)


func test_restoring_is_refused_for_a_room_that_is_not_damaged() -> void:
	var gold := Gold.new(1_000)
	var hall := _six_room_hall(1_000)
	assert_false(hall.restore("entrance", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_false(hall.restore("back_left", gold, 1_200))
	assert_eq(gold.amount, 940)


func test_the_first_room_is_restored_exactly_1_second_after_starting() -> void:
	var gold := Gold.new(60)
	var hall := _six_room_hall(1_000)
	hall.restore("side_left", gold, 1_000)
	assert_eq(hall.state("side_left", 1_000), Hall.State.RESTORING)
	assert_eq(hall.seconds_left(1_000), 1)
	assert_eq(hall.state("side_left", 1_001), Hall.State.RESTORED)
	assert_eq(hall.seconds_left(1_001), 0)


func test_a_clock_set_back_after_completion_keeps_the_room_restored_and_charges_nothing() -> void:
	var gold := Gold.new(240)
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_200)
	assert_eq(gold.amount, 180)

	hall.checkpoint(900)
	assert_eq(hall.state("back_left", 900), Hall.State.RESTORED)
	assert_eq(hall.seconds_left(900), 0)
	assert_false(hall.finished_since_checkpoint(900))
	assert_eq(gold.amount, 180)
	assert_eq(hall.refusal("back_right", gold, 900), "")


func test_a_clock_set_back_mid_restoration_adds_no_time_to_the_countdown() -> void:
	var gold := Gold.new(180)
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_001)
	# The second restoration takes 2 seconds: from 1_001 to 1_003.
	hall.restore("back_right", gold, 1_001)
	hall.checkpoint(1_002)
	assert_eq(hall.seconds_left(500), 1)
	hall.checkpoint(500)
	assert_eq(hall.seconds_left(500), 1)
	assert_eq(hall.seconds_left(1_003), 0)


func test_a_restoration_in_progress_survives_save_and_load() -> void:
	var gold := Gold.new(500)
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_120)
	hall.restore("side_right", gold, 1_132)
	hall.checkpoint(1_132)
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_eq(loaded.state("back_left", 1_132), Hall.State.RESTORED)
	assert_eq(loaded.state("side_right", 1_132), Hall.State.RESTORING)
	assert_eq(loaded.seconds_left(1_132), 2)
	assert_eq(loaded.state("side_right", 1_134), Hall.State.RESTORED)
	assert_eq(loaded.state("back_right", 1_132), Hall.State.DAMAGED)
	assert_eq(loaded.next_restore(), {"gold": 120, "seconds": 4})
	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 500 - 60 - 60)


func test_a_save_with_gold_only_loads_with_the_gold_kept_and_a_fresh_hall() -> void:
	var file := ConfigFile.new()
	Gold.new(234).write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	assert_eq(hall.state("entrance", 2_000), Hall.State.USABLE)
	assert_eq(hall.state("back_left", 2_000), Hall.State.DAMAGED)
	assert_eq(hall.seconds_left(2_000), 0)
	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 234)


func test_a_restoration_that_finished_while_away_is_reported_on_return_once() -> void:
	var gold := Gold.new(60)
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_000)
	assert_false(hall.finished_since_checkpoint(1_000))
	assert_true(hall.finished_since_checkpoint(1_300))
	hall.checkpoint(1_300)
	assert_false(hall.finished_since_checkpoint(1_400))
	assert_eq(hall.state("back_left", 1_400), Hall.State.RESTORED)


## A hall at 1_000 with `slot` restored by 1_120 and the builder free, the restoration paid from `gold`.
func _hall_with_empty_room(slot: String, gold: Gold) -> Hall:
	var hall := _six_room_hall(1_000)
	assert_true(hall.restore(slot, gold, 1_000))
	hall.checkpoint(1_120)
	return hall


func test_the_convert_choices_are_every_room_type_each_60_gold_but_a_bunk_room_30_and_2_seconds() -> void:
	assert_eq(Hall.ROOM_TYPES.keys(), ["quest_hall", "infirmary", "bunk_room", "tavern", "map_room", "training_room", "common_room", "storeroom"])
	assert_eq(Hall.ROOM_TYPES["quest_hall"]["name"], "Quest hall")
	assert_eq(Hall.ROOM_TYPES["quest_hall"]["blurb"], "adds a slot to the quest board")
	assert_eq(Hall.ROOM_TYPES["infirmary"]["name"], "Infirmary")
	assert_eq(Hall.ROOM_TYPES["infirmary"]["blurb"], "injuries heal twice as fast")
	assert_eq(Hall.ROOM_TYPES["bunk_room"]["name"], "Bunk room")
	assert_eq(Hall.ROOM_TYPES["bunk_room"]["blurb"], "2 more beds")
	assert_eq(Hall.ROOM_TYPES["tavern"]["name"], "Tavern")
	assert_eq(Hall.ROOM_TYPES["tavern"]["blurb"], "earns gold while you're away")
	assert_eq(Hall.ROOM_TYPES["training_room"]["name"], "Training room")
	assert_eq(Hall.ROOM_TYPES["training_room"]["blurb"], "trains one adventurer at a time")
	for type: String in Hall.ROOM_TYPES:
		assert_eq(Hall.ROOM_TYPES[type]["gold"], 30 if type == "bunk_room" else 60, type)
		assert_eq(Hall.ROOM_TYPES[type]["seconds"], 2, type)


func test_a_new_guild_has_2_beds_and_a_bunk_room_makes_4_and_a_common_room_2_candidate_slots() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_030))
	hall.checkpoint(1_150)
	assert_eq(hall.beds(1_150), 2)
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_150))
	assert_eq(hall.beds(1_151), 2)
	assert_eq(hall.beds(1_152), 4)
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_152))
	hall.checkpoint(1_154)
	assert_eq(hall.beds(1_154), 4)
	# The Common room's slot comes on top of the Reception's one.
	var recruits := Recruits.new()
	recruits.reception_slots = hall.reception("candidate_slots")
	var adventurers := Adventurers.new()
	recruits.refill(adventurers, 1_153, PackedInt64Array())
	assert_eq(recruits.candidates.size(), 1)
	recruits.refill(adventurers, 1_154, PackedInt64Array([hall.first_done_at("common_room")]))
	assert_eq(recruits.candidates.size(), 2)
	assert_false(recruits.candidates[1].is_empty())


func test_a_six_room_hall_has_4_beds_and_each_finished_bunk_room_adds_2_up_to_8() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_eq(hall.beds(1_120), 4)
	assert_true(hall.convert_room("back_left", "bunk_room", gold, 1_120))
	assert_eq(hall.beds(1_121), 4)
	assert_eq(hall.beds(1_122), 6)
	# Other rooms add no beds.
	hall.converted["side_left"] = {"type": "infirmary", "done_at": 1_000}
	assert_eq(hall.beds(1_122), 6)
	hall.converted["back_right"] = {"type": "bunk_room", "done_at": 1_000}
	assert_eq(hall.beds(1_122), 8)
	hall.converted["side_right"] = {"type": "bunk_room", "done_at": 1_000}
	assert_eq(hall.beds(1_122), 8)


func test_converting_an_empty_room_takes_60_gold_at_once_and_finishes_exactly_2_seconds_later() -> void:
	var gold := Gold.new(200)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_eq(hall.convert_refusal("back_left", "quest_hall", gold, 1_200), "")
	assert_true(hall.convert_room("back_left", "quest_hall", gold, 1_200))
	assert_eq(gold.amount, 80)
	assert_eq(hall.state("back_left", 1_201), Hall.State.CONVERTING)
	assert_eq(hall.seconds_left(1_201), 1)
	assert_eq(hall.rooms_done("quest_hall", 1_201), 0)
	assert_eq(hall.state("back_left", 1_202), Hall.State.CONVERTED)
	assert_eq(hall.seconds_left(1_202), 0)
	assert_eq(hall.room_type("back_left"), "quest_hall")
	assert_eq(hall.rooms_done("quest_hall", 1_202), 1)
	assert_eq(hall.rooms_done("infirmary", 1_202), 0)
	hall.checkpoint(1_300)
	assert_eq(hall.state("back_left", 1_300), Hall.State.CONVERTED)
	assert_eq(hall.room_type("back_left"), "quest_hall")
	assert_eq(hall.rooms_done("quest_hall", 1_300), 1)
	assert_eq(gold.amount, 80)


func test_converting_is_refused_with_the_shortfall_when_gold_is_short() -> void:
	var gold := Gold.new(110)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_eq(hall.convert_refusal("back_left", "infirmary", gold, 1_200), "Need 10 more gold")
	assert_false(hall.convert_room("back_left", "infirmary", gold, 1_200))
	assert_eq(gold.amount, 50)
	assert_eq(hall.state("back_left", 1_200), Hall.State.RESTORED)


func test_converting_is_refused_while_a_restoration_runs_and_restoring_while_a_conversion_runs() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_true(hall.restore("back_right", gold, 1_200))
	assert_eq(hall.convert_refusal("back_left", "quest_hall", gold, 1_201), "Builder busy")
	assert_false(hall.convert_room("back_left", "quest_hall", gold, 1_201))
	assert_eq(gold.amount, 880)
	assert_true(hall.convert_room("back_left", "quest_hall", gold, 1_202))
	assert_eq(hall.state("back_right", 1_202), Hall.State.RESTORED)

	assert_eq(hall.refusal("side_left", gold, 1_203), "Builder busy")
	assert_false(hall.restore("side_left", gold, 1_203))
	assert_eq(hall.convert_refusal("back_right", "infirmary", gold, 1_203), "Builder busy")
	assert_false(hall.convert_room("back_right", "infirmary", gold, 1_203))
	assert_eq(gold.amount, 820)
	assert_true(hall.restore("side_left", gold, 1_380))
	assert_eq(gold.amount, 700)


func test_only_an_empty_restored_room_can_be_converted() -> void:
	var gold := Gold.new(1_000)
	var hall := _six_room_hall(1_000)
	for slot: String in ["entrance", "reception", "back_left"]:
		assert_eq(hall.convert_refusal(slot, "quest_hall", gold, 1_000), "Not an empty room", slot)
		assert_false(hall.convert_room(slot, "quest_hall", gold, 1_000), slot)
	hall.restore("back_left", gold, 1_000)
	assert_eq(hall.convert_refusal("back_left", "quest_hall", gold, 1_000), "Not an empty room")
	assert_eq(gold.amount, 940)


func test_a_room_being_converted_or_converted_cannot_be_converted_again() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	hall.convert_room("back_left", "quest_hall", gold, 1_200)
	assert_eq(hall.convert_refusal("back_left", "infirmary", gold, 1_230), "Not an empty room")
	assert_false(hall.convert_room("back_left", "infirmary", gold, 1_260))
	hall.checkpoint(1_400)
	assert_false(hall.convert_room("back_left", "infirmary", gold, 1_400))
	assert_false(hall.convert_room("back_left", "quest_hall", gold, 1_400))
	assert_false(hall.restore("back_left", gold, 1_400))
	assert_eq(hall.room_type("back_left"), "quest_hall")
	assert_eq(gold.amount, 880)


## A hall with back_left converted into a Tavern from 1_200 to 1_202 and back_right restored and
## empty from 1_264, the builder free, paid from `gold`.
func _hall_with_tavern_and_empty_room(gold: Gold) -> Hall:
	var hall := _hall_with_empty_room("back_left", gold)
	assert_true(hall.convert_room("back_left", "tavern", gold, 1_200))
	hall.checkpoint(1_260)
	assert_true(hall.restore("back_right", gold, 1_260))
	hall.checkpoint(1_380)
	return hall


func test_converting_to_a_type_already_built_is_refused_with_nothing_changed() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern_and_empty_room(gold)
	assert_eq(gold.amount, 820)
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_400), "Already built")
	assert_false(hall.convert_room("back_right", "tavern", gold, 1_400))
	assert_eq(gold.amount, 820)
	assert_eq(hall.state("back_right", 1_400), Hall.State.RESTORED)
	assert_eq(hall.rooms_done("tavern", 1_400), 1)
	# Any other type can still go in the empty room.
	assert_eq(hall.convert_refusal("back_right", "infirmary", gold, 1_400), "")
	assert_true(hall.convert_room("back_right", "infirmary", gold, 1_400))


func test_converting_to_a_type_being_built_is_refused_with_nothing_changed_and_already_built_once_done() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_true(hall.restore("back_right", gold, 1_120))
	hall.checkpoint(1_240)
	assert_true(hall.convert_room("back_left", "tavern", gold, 1_240))
	assert_eq(gold.amount, 820)
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_241), "Being built")
	assert_false(hall.convert_room("back_right", "tavern", gold, 1_241))
	assert_eq(hall.convert_refusal("back_right", "infirmary", gold, 1_241), "Builder busy")
	assert_eq(gold.amount, 820)
	assert_eq(hall.state("back_right", 1_241), Hall.State.RESTORED)
	# Finished but not yet checkpointed, and after.
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_242), "Already built")
	assert_false(hall.convert_room("back_right", "tavern", gold, 1_242))
	hall.checkpoint(1_242)
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_242), "Already built")
	assert_eq(gold.amount, 820)
	assert_eq(hall.state("back_right", 1_242), Hall.State.RESTORED)


func test_an_old_save_with_two_bunk_rooms_keeps_both_and_8_beds() -> void:
	# What a build before rooms were unique could save: two finished Bunk rooms.
	var file := ConfigFile.new()
	file.set_value("hall", "restored", PackedStringArray(["back_left", "back_right", "side_left"]))
	file.set_value("hall", "converted", {"back_left": {"type": "bunk_room", "done_at": 1_100}, "back_right": {"type": "bunk_room", "done_at": 1_200}})
	file.set_value("hall", "checked_at", 1_300)
	assert_eq(file.save(SAVE_PATH), OK)

	var hall := Hall.load_or_start(SAVE_PATH, 1_400)
	assert_eq(hall.rooms_done("bunk_room", 1_400), 2)
	assert_eq(hall.beds(1_400), 8)
	assert_eq(hall.room_type("back_left"), "bunk_room")
	assert_eq(hall.room_type("back_right"), "bunk_room")
	assert_eq(hall.convert_refusal("side_left", "bunk_room", Gold.new(1_000), 1_400), "Already built")


func test_the_first_infirmary_is_dated_from_when_its_conversion_finishes() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_eq(hall.first_done_at("infirmary"), -1)
	hall.convert_room("back_left", "infirmary", gold, 1_200)
	assert_eq(hall.first_done_at("infirmary"), 1_202)
	assert_eq(hall.first_done_at("quest_hall"), -1)
	hall.checkpoint(1_400)
	hall.restore("back_right", gold, 1_400)
	hall.checkpoint(1_520)
	# A second Infirmary, as a save from before rooms were unique can hold.
	hall.converted["back_right"] = {"type": "infirmary", "done_at": 1_580}
	assert_eq(hall.first_done_at("infirmary"), 1_202)
	hall.checkpoint(1_600)
	assert_eq(hall.first_done_at("infirmary"), 1_202)
	assert_eq(hall.rooms_done("infirmary", 1_600), 2)


func test_a_clock_set_back_after_a_conversion_keeps_the_room_converted_and_charges_nothing() -> void:
	var gold := Gold.new(300)
	var hall := _hall_with_empty_room("back_left", gold)
	hall.convert_room("back_left", "quest_hall", gold, 1_200)
	hall.checkpoint(1_300)
	assert_eq(gold.amount, 180)

	hall.checkpoint(900)
	assert_eq(hall.state("back_left", 900), Hall.State.CONVERTED)
	assert_eq(hall.room_type("back_left"), "quest_hall")
	assert_eq(hall.rooms_done("quest_hall", 900), 1)
	assert_false(hall.finished_since_checkpoint(900))
	assert_eq(gold.amount, 180)
	assert_eq(hall.refusal("back_right", gold, 900), "")
	assert_true(hall.restore("back_right", gold, 900))
	assert_eq(gold.amount, 120)


func test_a_clock_set_back_mid_conversion_adds_no_time_and_does_not_undo_it() -> void:
	var gold := Gold.new(300)
	var hall := _hall_with_empty_room("back_left", gold)
	hall.convert_room("back_left", "infirmary", gold, 1_200)
	hall.checkpoint(1_201)
	hall.checkpoint(500)
	assert_eq(hall.state("back_left", 500), Hall.State.CONVERTING)
	assert_eq(hall.seconds_left(500), 1)
	assert_eq(hall.first_done_at("infirmary"), 1_202)
	assert_eq(hall.seconds_left(1_202), 0)
	assert_eq(gold.amount, 180)


func test_a_conversion_in_progress_and_a_converted_room_survive_save_and_load() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	hall.convert_room("back_left", "infirmary", gold, 1_200)
	hall.checkpoint(1_260)
	hall.restore("side_right", gold, 1_260)
	hall.checkpoint(1_380)
	hall.convert_room("side_right", "quest_hall", gold, 1_400)
	hall.checkpoint(1_401)
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded_gold.amount, 1_000 - 60 - 60 - 60 - 60)
	assert_eq(loaded.state("back_left", 1_401), Hall.State.CONVERTED)
	assert_eq(loaded.room_type("back_left"), "infirmary")
	assert_eq(loaded.first_done_at("infirmary"), 1_202)
	assert_eq(loaded.state("side_right", 1_401), Hall.State.CONVERTING)
	assert_eq(loaded.seconds_left(1_401), 1)
	assert_eq(loaded.convert_refusal("back_right", "quest_hall", loaded_gold, 1_401), "Not an empty room")
	assert_eq(loaded.rooms_done("quest_hall", 1_401), 0)
	assert_eq(loaded.state("side_right", 1_402), Hall.State.CONVERTED)
	assert_eq(loaded.room_type("side_right"), "quest_hall")
	assert_eq(loaded.rooms_done("quest_hall", 1_402), 1)


func _m4_save() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 400)
	file.set_value("hall", "restored", PackedStringArray(["back_left"]))
	file.set_value("hall", "restoring", "side_left")
	file.set_value("hall", "restoring_since", 1_050)
	file.set_value("hall", "checked_at", 1_050)
	file.set_value("dispatch", "outings", [{"quest": "rats", "since": 1_049, "party": PackedStringArray(["bram"]), "seed": 7}])
	file.set_value("dispatch", "injured_until", {"tobin": 1_200})
	file.set_value("dispatch", "last_return", "Goblin camp: failed · +125 gold · Tobin injured")
	file.set_value("dispatch", "checked_at", 1_050)
	assert_eq(file.save(SAVE_PATH), OK)


func test_an_m4_save_loads_with_no_converted_rooms_and_everything_else_as_it_was() -> void:
	_m4_save()
	var gold := Gold.load_or_start(SAVE_PATH)
	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_eq(gold.amount, 400)
	assert_eq(hall.state("back_left", 1_050), Hall.State.RESTORED)
	assert_eq(hall.state("side_left", 1_050), Hall.State.RESTORING)
	assert_eq(hall.seconds_left(1_050), 2)
	assert_eq(hall.state("side_left", 1_052), Hall.State.RESTORED)
	assert_eq(hall.state("back_right", 1_050), Hall.State.DAMAGED)
	assert_true(hall.converted.is_empty())
	assert_eq(hall.rooms_done("quest_hall", 1_052), 0)
	assert_eq(hall.first_done_at("infirmary"), -1)
	assert_eq(dispatch.outings[0]["quest"], "rats")
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_050), 1)
	assert_eq(dispatch.injury_left("tobin", 1_050), 150)
	assert_true(dispatch.waiting_loot.is_empty())
	assert_eq(hall.convert_refusal("back_left", "bunk_room", gold, 1_050), "Builder busy")
	assert_true(hall.convert_room("back_left", "bunk_room", gold, 1_052))
	assert_eq(gold.amount, 370)


## A hall with a Tavern in `slot` converted from 1_200, finishing at 1_202, paid from `gold`.
func _hall_with_tavern(slot: String, gold: Gold) -> Hall:
	var hall := _hall_with_empty_room(slot, gold)
	assert_true(hall.convert_room(slot, "tavern", gold, 1_200))
	return hall


func test_a_tavern_holds_no_gold_until_its_conversion_finishes() -> void:
	var hall := _hall_with_tavern("back_left", Gold.new(1_000))
	assert_eq(hall.tavern_gold("back_left", 1_200), 0)
	assert_eq(hall.tavern_gold("back_left", 1_201), 0)
	assert_eq(hall.tavern_gold("back_left", 1_202), 0)
	assert_eq(hall.tavern_gold("back_left", 1_205), 1)


func test_a_finished_tavern_fills_with_20_gold_a_minute_from_when_it_finished() -> void:
	var hall := _hall_with_tavern("back_left", Gold.new(1_000))
	assert_eq(hall.tavern_gold("back_left", 1_202 + 60), 20)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 51), 17)
	hall.checkpoint(1_202 + 51)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 51), 17)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 90), 30)
	# Other rooms hold none.
	assert_eq(hall.tavern_gold("reception", 1_202 + 90), 0)


func test_a_tavern_stops_filling_at_40_gold() -> void:
	var hall := _hall_with_tavern("back_left", Gold.new(1_000))
	assert_eq(hall.tavern_gold("back_left", 1_202 + 117), 39)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 120), 40)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 123), 40)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 24 * 3_600), 40)


func test_collecting_moves_exactly_the_tavern_gold_into_gold_and_it_fills_again_from_then() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(gold.amount, 880)
	var at := 1_202 + 51
	assert_eq(hall.collect("back_left", gold, at), 17)
	assert_eq(gold.amount, 897)
	assert_eq(hall.tavern_gold("back_left", at), 0)
	assert_eq(hall.tavern_gold("back_left", at + 60), 20)
	assert_eq(hall.tavern_gold("back_left", at + 3_600), 40)


func test_collecting_twice_in_a_row_gives_nothing_the_second_time() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(hall.collect("back_left", gold, 1_202 + 30), 10)
	assert_eq(hall.collect("back_left", gold, 1_202 + 30), 0)
	assert_eq(gold.amount, 890)
	# Collecting an empty room does not restart its filling.
	assert_eq(hall.collect("back_left", gold, 1_202 + 30 + 2), 0)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 30 + 3), 1)


func test_a_tavern_finished_since_the_last_checkpoint_can_be_collected() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(hall.collect("back_left", gold, 1_202 + 15), 5)
	assert_eq(gold.amount, 885)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 15 + 60), 20)


func test_two_taverns_fill_and_are_collected_each_on_their_own() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	hall.checkpoint(1_202)
	assert_true(hall.restore("back_right", gold, 1_202))
	hall.checkpoint(1_206)
	# A second Tavern, as a save from before rooms were unique can hold.
	hall.converted["back_right"] = {"type": "tavern", "done_at": 1_211}
	# The second finishes at 1_211, nine seconds after the first.
	var at := 1_211 + 30
	assert_eq(hall.tavern_gold("back_left", at), 13)
	assert_eq(hall.tavern_gold("back_right", at), 10)
	var before := gold.amount
	assert_eq(hall.collect("back_left", gold, at), 13)
	assert_eq(hall.tavern_gold("back_left", at), 0)
	assert_eq(hall.tavern_gold("back_right", at), 10)
	assert_eq(hall.tavern_gold("back_right", at + 3), 11)
	assert_eq(hall.tavern_gold("back_left", at + 3), 1)
	assert_eq(gold.amount, before + 13)


func test_a_clock_set_back_neither_removes_nor_adds_tavern_gold() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	hall.checkpoint(1_202 + 60)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 60), 20)
	hall.checkpoint(500)
	assert_eq(hall.tavern_gold("back_left", 500), 20)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 63), 21)

	assert_eq(hall.collect("back_left", gold, 1_202 + 63), 21)
	hall.checkpoint(500)
	assert_eq(hall.tavern_gold("back_left", 500), 0)
	assert_eq(hall.collect("back_left", gold, 500), 0)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 66), 1)
	# Collected while the clock is set back, it starts filling again from the latest time seen.
	hall.checkpoint(1_202 + 75)
	assert_eq(hall.collect("back_left", gold, 500), 4)
	assert_eq(hall.tavern_gold("back_left", 1_202 + 75), 0)
	assert_eq(gold.amount, 880 + 21 + 4)


func test_one_read_after_an_absence_equals_reading_every_second() -> void:
	var away := _hall_with_tavern("back_left", Gold.new(1_000))
	var watched := _hall_with_tavern("back_left", Gold.new(1_000))
	var seen := 0
	for now: int in range(1_200, 1_202 + 100 + 1):
		watched.checkpoint(now)
		seen = watched.tavern_gold("back_left", now)
	assert_eq(seen, 33)
	assert_eq(away.tavern_gold("back_left", 1_202 + 100), 33)
	var gold := Gold.new(0)
	assert_eq(away.collect("back_left", gold, 1_202 + 100), 33)
	assert_eq(watched.collect("back_left", gold, 1_202 + 100), 33)
	assert_eq(gold.amount, 66)


func test_a_tavern_amount_and_collected_at_survive_save_and_load() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(hall.collect("back_left", gold, 1_202 + 30), 10)
	hall.checkpoint(1_202 + 75)
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded_gold.amount, 890)
	assert_eq(loaded.room_type("back_left"), "tavern")
	assert_eq(loaded.tavern_gold("back_left", 1_202 + 75), 15)
	assert_eq(loaded.tavern_gold("back_left", 1_202 + 78), 16)
	assert_eq(loaded.collect("back_left", loaded_gold, 1_202 + 78), 16)
	assert_eq(loaded_gold.amount, 906)


func test_an_old_save_loads_with_no_tavern_and_its_rooms_hold_no_gold() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 300)
	file.set_value("hall", "restored", PackedStringArray(["back_left", "side_left"]))
	file.set_value("hall", "converted", {"back_left": {"type": "infirmary", "done_at": 1_100}})
	file.set_value("hall", "checked_at", 1_200)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	assert_eq(hall.room_type("back_left"), "infirmary")
	assert_eq(hall.rooms_done("tavern", 99_999), 0)
	for slot: String in ["back_left", "side_left", "reception"]:
		assert_eq(hall.tavern_gold(slot, 99_999), 0, slot)
		assert_eq(hall.collect(slot, gold, 99_999), 0, slot)
	assert_eq(gold.amount, 300)
	# A Tavern needs rank D, which the guild reaches later.
	hall.rank = "D"
	assert_true(hall.convert_room("side_left", "tavern", gold, 2_000))
	assert_eq(hall.tavern_gold("side_left", 2_002 + 60), 20)


func test_at_rank_f_only_a_bunk_room_and_a_common_room_can_be_built_and_any_other_type_is_refused_with_nothing_changed() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_030)
	assert_eq(hall.open_types(), PackedStringArray(["bunk_room", "common_room"]))
	var needs := {"quest_hall": "E", "infirmary": "E", "tavern": "D", "map_room": "D", "training_room": "D"}
	for type: String in needs:
		assert_eq(hall.convert_refusal("side_left", type, gold, 1_030), "Guild rank %s" % needs[type], type)
		assert_false(hall.convert_room("side_left", type, gold, 1_030), type)
	assert_eq(gold.amount, 940)
	assert_eq(hall.state("side_left", 1_030), Hall.State.RESTORED)
	assert_eq(hall.building, "")
	for type: String in ["bunk_room", "common_room"]:
		assert_eq(hall.convert_refusal("side_left", type, gold, 1_030), "", type)
	# Rank E opens its own types, and rank D the rest.
	hall.rank = "E"
	assert_eq(hall.open_types(), PackedStringArray(["quest_hall", "infirmary", "bunk_room", "common_room", "storeroom"]))
	assert_eq(hall.convert_refusal("side_left", "tavern", gold, 1_030), "Guild rank D")
	assert_true(hall.convert_room("side_left", "quest_hall", gold, 1_030))
	hall.rank = "D"
	assert_eq(hall.open_types(), PackedStringArray(Hall.ROOM_TYPES.keys()))


func test_extending_is_refused_at_rank_f_with_nothing_changed() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_restores(3, gold)
	hall.rank = "F"
	assert_eq(hall.extend_refusal(gold, 1_450), "Guild rank D")
	assert_false(hall.extend(gold, 1_450))
	assert_eq(gold.amount, 760)
	assert_eq(hall.building, "")
	assert_false(hall.has_first_floor(99_999))
	hall.rank = "D"
	assert_eq(hall.extend_refusal(gold, 1_450), "")


func test_an_extension_under_way_at_rank_f_still_finishes() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	hall.rank = "F"
	assert_false(hall.has_first_floor(1_519))
	assert_true(hall.has_first_floor(1_520))
	hall.checkpoint(1_520)
	assert_true(hall.first_floor)


## A hall at 1_000 with `restores` ground-floor rooms restored one after another, paid from `gold`
## (60, then 60, then 120), and the builder free at 1_450.
func _hall_with_restores(restores: int, gold: Gold) -> Hall:
	var hall := _six_room_hall(1_000)
	var slots: Array[String] = ["back_left", "back_right", "side_left"]
	var starts: Array[int] = [1_000, 1_030, 1_150]
	for i: int in restores:
		assert_true(hall.restore(slots[i], gold, starts[i]))
	hall.checkpoint(1_450)
	return hall


## A hall with the First floor built from 1_500 to 1_520 and checkpointed at 2_100, paid from `gold`.
func _hall_with_first_floor(gold: Gold) -> Hall:
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	hall.checkpoint(2_100)
	return hall


func test_extending_is_refused_until_3_ground_floor_rooms_are_restored_with_nothing_changed() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_restores(2, gold)
	assert_eq(hall.extend_refusal(gold, 1_450), "Restore the ground floor first")
	assert_false(hall.extend(gold, 1_450))
	assert_eq(gold.amount, 880)
	assert_false(hall.has_first_floor(99_999))
	assert_eq(hall.state("upper_nw", 99_999), Hall.State.UNBUILT)
	assert_eq(hall.seconds_left(1_450), 0)
	# The third restoration counts the moment it finishes, before any checkpoint.
	assert_true(hall.restore("side_left", gold, 1_450))
	assert_eq(hall.extend_refusal(gold, 1_453), "Restore the ground floor first")
	assert_eq(hall.extend_refusal(gold, 1_454), "")


func test_extending_is_refused_while_the_builder_is_busy_with_nothing_changed() -> void:
	var gold := Gold.new(760)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.restore("side_right", gold, 1_500))
	assert_eq(hall.extend_refusal(gold, 1_509), "Builder busy")
	assert_false(hall.extend(gold, 1_509))
	assert_eq(gold.amount, 320)
	assert_eq(hall.building, "side_right")
	assert_false(hall.has_first_floor(99_999))
	# Free again, and the restoration it waited on has spent the gold.
	assert_eq(hall.extend_refusal(gold, 2_100), "Need 80 more gold")


func test_extending_is_refused_with_the_shortfall_when_gold_is_short_with_nothing_changed() -> void:
	var gold := Gold.new(590)
	var hall := _hall_with_restores(3, gold)
	assert_eq(hall.extend_refusal(gold, 1_500), "Need 50 more gold")
	assert_false(hall.extend(gold, 1_500))
	assert_eq(gold.amount, 350)
	assert_eq(hall.seconds_left(1_500), 0)
	assert_false(hall.has_first_floor(99_999))
	gold.amount += 50
	assert_eq(hall.extend_refusal(gold, 1_500), "")


func test_extending_costs_400_gold_and_builds_the_first_floor_exactly_20_seconds_later() -> void:
	var gold := Gold.new(640)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	assert_eq(gold.amount, 0)
	assert_eq(hall.job_seconds(), 20)
	assert_eq(hall.seconds_left(1_500), 20)
	assert_false(hall.has_first_floor(1_519))
	assert_eq(hall.state("upper_nw", 1_519), Hall.State.UNBUILT)
	assert_true(hall.has_first_floor(1_520))
	for slot: String in ["upper_nw", "upper_ne", "upper_sw", "upper_se"]:
		assert_eq(hall.state(slot, 1_520), Hall.State.RESTORED, slot)
	# Restore pricing counts restorations only, under way or after.
	assert_eq(hall.next_restore(), {"gold": 200, "seconds": 10})
	hall.checkpoint(1_520)
	assert_true(hall.has_first_floor(1_520))
	assert_eq(hall.next_restore(), {"gold": 200, "seconds": 10})
	assert_eq(hall.state("side_right", 1_520), Hall.State.DAMAGED)


func test_the_first_floor_rooms_start_empty_and_cannot_be_restored_or_converted_before_it_is_built() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_restores(3, gold)
	assert_eq(hall.refusal("upper_nw", gold, 1_500), "Not damaged")
	assert_eq(hall.convert_refusal("upper_nw", "tavern", gold, 1_500), "Not an empty room")
	assert_true(hall.extend(gold, 1_500))
	hall.checkpoint(2_100)
	assert_eq(hall.room_type("upper_nw"), "")
	assert_eq(hall.refusal("upper_nw", gold, 2_100), "Not damaged")
	assert_eq(hall.convert_refusal("upper_nw", "tavern", gold, 2_100), "")


func test_a_bunk_room_quest_hall_and_tavern_on_the_first_floor_count_as_on_the_ground_floor() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_first_floor(gold)
	assert_true(hall.convert_room("upper_nw", "bunk_room", gold, 2_100))
	hall.checkpoint(2_160)
	assert_true(hall.convert_room("upper_sw", "quest_hall", gold, 2_160))
	hall.checkpoint(2_220)
	assert_true(hall.convert_room("upper_se", "tavern", gold, 2_220))
	assert_eq(hall.beds(2_160), 6)
	assert_eq(hall.rooms_done("quest_hall", 2_220), 1)
	assert_eq(hall.converted["upper_sw"], {"type": "quest_hall", "done_at": 2_162})
	assert_eq(hall.state("upper_se", 2_280), Hall.State.CONVERTED)
	assert_eq(hall.tavern_gold("upper_se", 2_222 + 30), 10)
	assert_eq(hall.collect("upper_se", gold, 2_222 + 30), 10)
	assert_eq(gold.amount, 2_000 - 240 - 400 - 30 - 2 * 60 + 10)


func test_the_first_infirmary_done_is_the_one_injured_adventurers_use_on_either_floor() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_first_floor(gold)
	assert_true(hall.convert_room("upper_se", "infirmary", gold, 2_100))
	hall.checkpoint(2_160)
	# A second Infirmary, as a save from before rooms were unique can hold.
	hall.converted["back_left"] = {"type": "infirmary", "done_at": 2_220}
	hall.checkpoint(2_220)
	assert_eq(hall.first_room("infirmary"), "upper_se")
	assert_eq(hall.first_done_at("infirmary"), 2_102)
	assert_eq(hall.first_room("tavern"), "")


func test_the_hall_can_be_extended_only_once() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	assert_eq(hall.extend_refusal(gold, 1_600), "Already extended")
	assert_eq(hall.extend_refusal(gold, 2_100), "Already extended")
	hall.checkpoint(2_100)
	assert_eq(hall.extend_refusal(gold, 2_100), "Already extended")
	assert_false(hall.extend(gold, 2_100))
	assert_eq(gold.amount, 2_000 - 240 - 400)
	assert_eq(hall.seconds_left(2_100), 0)


func test_a_clock_set_back_neither_adds_time_to_the_extension_nor_undoes_it() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	hall.checkpoint(1_510)
	hall.checkpoint(900)
	assert_eq(hall.seconds_left(900), 10)
	assert_false(hall.has_first_floor(900))
	hall.checkpoint(2_100)
	hall.checkpoint(900)
	assert_true(hall.has_first_floor(900))
	assert_eq(hall.state("upper_nw", 900), Hall.State.RESTORED)
	assert_eq(hall.extend_refusal(gold, 900), "Already extended")
	assert_eq(gold.amount, 2_000 - 240 - 400)


func test_an_extension_under_way_and_a_built_first_floor_survive_save_and_load() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	hall.checkpoint(1_510)
	var file := ConfigFile.new()
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_eq(loaded.seconds_left(1_510), 10)
	assert_false(loaded.has_first_floor(1_519))
	assert_eq(loaded.extend_refusal(gold, 1_510), "Already extended")
	assert_eq(loaded.next_restore(), {"gold": 200, "seconds": 10})
	assert_true(loaded.has_first_floor(1_520))

	loaded.checkpoint(2_100)
	assert_true(loaded.convert_room("upper_nw", "bunk_room", gold, 2_100))
	loaded.checkpoint(2_160)
	file = ConfigFile.new()
	loaded.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var reloaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_true(reloaded.has_first_floor(2_160))
	assert_eq(reloaded.state("upper_nw", 2_160), Hall.State.CONVERTED)
	assert_eq(reloaded.state("upper_ne", 2_160), Hall.State.RESTORED)
	assert_eq(reloaded.beds(2_160), 6)
	assert_eq(reloaded.extend_refusal(gold, 2_160), "Already extended")


func test_an_old_save_loads_with_no_first_floor_and_can_extend_once_the_guild_reaches_rank_d() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 500)
	file.set_value("hall", "restored", PackedStringArray(["back_left", "back_right", "side_left"]))
	file.set_value("hall", "converted", {"back_left": {"type": "tavern", "done_at": 1_100}})
	file.set_value("hall", "restoring", "")
	file.set_value("hall", "restoring_since", 0)
	file.set_value("hall", "converting_into", "")
	file.set_value("hall", "checked_at", 1_200)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	assert_false(hall.has_first_floor(99_999))
	assert_eq(hall.state("upper_nw", 99_999), Hall.State.UNBUILT)
	assert_eq(hall.room_type("back_left"), "tavern")
	assert_eq(hall.extend_refusal(gold, 2_000), "Guild rank D")
	assert_false(hall.extend(gold, 2_000))
	assert_eq(gold.amount, 500)
	assert_eq(hall.building, "")
	hall.rank = "D"
	assert_true(hall.extend(gold, 2_000))
	assert_eq(gold.amount, 100)
	assert_true(hall.has_first_floor(2_600))


## A save as a guild from before guild ranks wrote it: six ground-floor rooms, all restored, with a
## Bunk room, a Tavern finished at 1_100 and the First floor built; the four starters, with seven
## items in the stash; two candidates; three quests on the board; checked at 1_200.
func _save_from_before_guild_ranks() -> void:
	var file := ConfigFile.new()
	Gold.new(500).write(file)
	file.set_value("hall", "restored", PackedStringArray(["back_left", "back_right", "side_left", "side_right"]))
	file.set_value("hall", "converted", {"back_left": {"type": "tavern", "done_at": 1_100}, "side_left": {"type": "bunk_room", "done_at": 1_050}})
	file.set_value("hall", "restoring", "")
	file.set_value("hall", "restoring_since", 0)
	file.set_value("hall", "converting_into", "")
	file.set_value("hall", "building_seconds", 0)
	file.set_value("hall", "first_floor", true)
	file.set_value("hall", "checked_at", 1_200)
	var dispatch := Dispatch.new(1_200)
	dispatch.adventurers = Adventurers.new(["bram", "ilse", "tobin", "maren"])
	dispatch.adventurers.gear.stash = PackedStringArray(["belt", "sash", "quiver", "red_cloak", "night_cloak", "iron_cap", "chain_shirt"])
	dispatch.write(file)
	var recruits := Recruits.new()
	recruits.reception_slots = 2
	recruits.refill(dispatch.adventurers, 1_200)
	recruits.write(file)
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, 1_200, PackedInt64Array())
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)


func test_a_save_from_before_guild_ranks_loads_unchanged_with_its_capacity_and_its_tavern_still_fills() -> void:
	_save_from_before_guild_ranks()
	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	var recruits := Recruits.load_or_start(SAVE_PATH)
	var board := Board.load_or_start(SAVE_PATH)
	assert_eq(hall.rank, "F")
	assert_eq(hall.state("entrance", 2_000), Hall.State.USABLE)
	assert_eq(hall.state("reception", 2_000), Hall.State.USABLE)
	for slot: String in ["back_right", "side_right", "upper_nw", "upper_ne", "upper_sw", "upper_se"]:
		assert_eq(hall.state(slot, 2_000), Hall.State.RESTORED, slot)
	assert_eq(hall.room_type("back_left"), "tavern")
	assert_eq(hall.room_type("side_left"), "bunk_room")
	assert_eq(dispatch.adventurers.roster.keys(), ["bram", "ilse", "tobin", "maren"])
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray(["belt", "sash", "quiver", "red_cloak", "night_cloak", "iron_cap", "chain_shirt"]))
	# Four beds and the Bunk room's two, two candidate slots, three board slots and a stash of twenty,
	# as the game takes them.
	assert_eq(hall.beds(2_000), 6)
	recruits.reception_slots = hall.reception("candidate_slots")
	board.reception_slots = hall.reception("board_slots")
	dispatch.adventurers.gear.stash_cap = hall.reception("stash")
	# The save's three quests load; by the time it is loaded they have left the board, and their
	# slots refill as usual.
	assert_eq(board.filled(), 3)
	recruits.refill(dispatch.adventurers, 2_000)
	board.refill(dispatch, 2_000, PackedInt64Array())
	assert_eq(recruits.candidates.size(), 2)
	assert_eq(board.slots.size(), 3)
	for i: int in 13:
		assert_true(dispatch.adventurers.gear.stow("belt"), str(i))
	assert_false(dispatch.adventurers.gear.stow("belt"))
	# A Quest hall or Common room built now adds a slot to the save's, not to what a new game has.
	board.refill(dispatch, 2_000, PackedInt64Array([2_000]))
	assert_eq(board.slots.size(), 4)
	recruits.refill(dispatch.adventurers, 2_000, PackedInt64Array([2_000]))
	assert_eq(recruits.candidates.size(), 3)
	# The Tavern a rank-F guild could not build now still fills, up to its cap.
	assert_eq(hall.tavern_gold("back_left", 1_200), 33)
	assert_eq(hall.tavern_gold("back_left", 2_000), 40)
	var gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(hall.collect("back_left", gold, 2_000), 40)
	assert_eq(gold.amount, 540)


func test_a_new_game_survives_save_and_load() -> void:
	var gold := Gold.load_or_start(SAVE_PATH)
	var hall := Hall.load_or_start(SAVE_PATH, 1_000)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 1_000)
	assert_eq(loaded.layout, hall.layout)
	assert_eq(loaded.rank, "F")
	assert_eq(loaded.building, "side_left")
	assert_eq(loaded.seconds_left(1_000), 1)
	for slot: String in ["reception", "side_left", "back_left", "back_right", "side_right", "entrance", "upper_nw"]:
		assert_eq(loaded.state(slot, 1_000), hall.state(slot, 1_000), slot)
	for capacity: String in ["beds", "candidate_slots", "board_slots", "stash"]:
		assert_eq(loaded.reception(capacity), hall.reception(capacity), capacity)
	assert_eq(loaded.reception("beds"), 2)
	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 40)
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_eq(loaded_dispatch.adventurers.roster, dispatch.adventurers.roster)
	assert_eq(loaded_dispatch.adventurers.gear.worn, dispatch.adventurers.gear.worn)


# Plays a new game from 1_000 to 4_000 with plenty of gold, checkpointing every `step` seconds as
# well as at each action, or with 0 only at the actions and the end: the side room is restored and
# made a Bunk room, Bram is sent on a quest and the candidate hired. What the guild has at the end.
func _new_game_played(step: int) -> Array:
	var gold := Gold.new(1_000)
	var hall := Hall.load_or_start(SAVE_PATH, 1_000)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	var board := Board.new()
	board.reception_slots = hall.reception("board_slots")
	var recruits := Recruits.new()
	recruits.reception_slots = hall.reception("candidate_slots")
	var actions := [1_000, 1_030, 1_100, 1_200, 4_000]
	var now := 1_000
	for at: int in actions:
		while step > 0 and now + step < at:
			now += step
			hall.checkpoint(now)
			dispatch.checkpoint(now)
			board.refill(dispatch, now, PackedInt64Array())
			recruits.refill(dispatch.adventurers, now)
		now = at
		hall.checkpoint(now)
		dispatch.checkpoint(now)
		board.refill(dispatch, now, PackedInt64Array())
		recruits.refill(dispatch.adventurers, now)
		match at:
			1_000:
				assert_true(hall.restore("side_left", gold, now))
			1_030:
				assert_true(hall.convert_room("side_left", "bunk_room", gold, now))
			1_100:
				assert_true(board.send(dispatch, board.slots[0], Fixtures.party(dispatch, ["bram"]), 1, now, PackedInt64Array()))
			1_200:
				assert_true(recruits.hire(0, dispatch.adventurers, gold, hall.beds(now), now))
	return [hall.restored, hall.converted, hall.beds(now), board.slots, board.refill_at, recruits.candidates, recruits.refill_at, dispatch.adventurers.roster.keys(), gold.amount]


func test_one_checkpoint_after_an_absence_in_a_new_game_equals_checkpointing_every_second() -> void:
	var watched := _new_game_played(1)
	var away := _new_game_played(0)
	assert_eq(away, watched)
	# The candidate's slot refilled 60 seconds after the hire, and the Bunk room gave the bed.
	assert_eq(away[2], 4)
	assert_eq(away[7].size(), 3)
	assert_false(away[5][0].is_empty())


func test_a_restoration_keeps_the_length_it_started_with_when_the_rule_tables_read_differently_later() -> void:
	var gold := Gold.new(500)
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	# Another room counted as restored would make today's table give the second room's 2 seconds.
	hall.restored.append("side_left")
	assert_eq(hall.job_seconds(), 1)
	assert_eq(hall.seconds_left(1_000), 1)
	assert_eq(hall.state("back_left", 1_001), Hall.State.RESTORED)


func test_a_job_under_way_loads_with_the_length_saved_when_it_started_and_one_saved_without_it_uses_todays_rule() -> void:
	var gold := Gold.new(1_000)
	var restoring := _six_room_hall(1_000)
	restoring.restore("back_left", gold, 1_000)
	var converting := _hall_with_empty_room("back_left", gold)
	converting.convert_room("back_left", "infirmary", gold, 1_200)
	var extending := _hall_with_empty_room("back_left", gold)
	for slot: String in ["side_left", "side_right"]:
		extending.restore(slot, gold, extending.checked_at)
		extending.checkpoint(extending.checked_at + 600)
	assert_true(extending.extend(Gold.new(400), extending.checked_at))
	var jobs: Array[Array] = [[restoring, 1], [converting, 2], [extending, 20]]
	for job: Array in jobs:
		var hall: Hall = job[0]
		var file := ConfigFile.new()
		hall.write(file)
		assert_eq(file.get_value("hall", "building_seconds"), job[1])
		assert_eq(file.save(SAVE_PATH), OK)
		assert_eq(Hall.load_or_start(SAVE_PATH, 0).job_seconds(), job[1])
		# Started when the tables gave it 1_000 seconds.
		file.set_value("hall", "building_seconds", 1_000)
		assert_eq(file.save(SAVE_PATH), OK)
		var stretched := Hall.load_or_start(SAVE_PATH, 0)
		assert_eq(stretched.job_seconds(), 1_000)
		assert_eq(stretched.seconds_left(hall.building_since), 1_000)
		assert_true(stretched.finished_since_checkpoint(hall.building_since + 1_000))
		assert_false(stretched.finished_since_checkpoint(hall.building_since + 999))
		# A save from before lengths were kept.
		file.erase_section_key("hall", "building_seconds")
		assert_eq(file.save(SAVE_PATH), OK)
		var old := Hall.load_or_start(SAVE_PATH, 0)
		assert_eq(old.job_seconds(), job[1])
		assert_eq(old.seconds_left(hall.building_since), job[1])


func test_a_finished_job_leaves_the_next_one_its_own_length() -> void:
	var gold := Gold.new(500)
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_030)
	hall.restore("side_left", gold, 1_030)
	assert_eq(hall.seconds_left(1_030), 2)
	assert_eq(hall.state("side_left", 1_031), Hall.State.RESTORING)
	assert_eq(hall.state("side_left", 1_032), Hall.State.RESTORED)


func test_a_new_games_two_rank_f_restores_cost_60_each_then_120_200_300_and_a_bunk_room_costs_30_and_a_common_room_60() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	assert_eq(gold.amount, 940)
	hall.checkpoint(1_001)
	assert_true(hall.restore("back_left", gold, 1_001))
	assert_eq(gold.amount, 880)
	hall.checkpoint(1_003)
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_003))
	assert_eq(gold.amount, 850)
	hall.checkpoint(1_005)
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_005))
	assert_eq(gold.amount, 790)
	# The restorations after a new game's two, in a hall that has the rooms for them.
	var six := _hall_with_restores(2, gold)
	var spent: Array[int] = []
	for slot: String in ["side_left", "side_right"]:
		var before := gold.amount
		assert_true(six.restore(slot, gold, six.checked_at))
		spent.append(before - gold.amount)
		six.checkpoint(six.checked_at + 60)
	assert_eq(spent, [120, 200])
	assert_eq(six.next_restore()["gold"], 300)


## A new game's hall at 1_000 with its side room a finished Bunk room at tier 1 from 1_005 and its
## backroom restored and empty, the builder free, paid from `gold`: 60, 60 and 30.
func _hall_with_bunk_room(gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_001)
	assert_true(hall.restore("back_left", gold, 1_001))
	hall.checkpoint(1_003)
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_003))
	hall.checkpoint(1_005)
	return hall


func test_a_finished_bunk_room_upgrades_to_tier_2_then_3_paid_at_the_start_and_its_beds_rise_only_once_each_job_finishes() -> void:
	var gold := Gold.new(500)
	var hall := _hall_with_bunk_room(gold)
	assert_eq(gold.amount, 350)
	# The Reception's 2 beds and the Bunk room's.
	assert_eq(hall.beds(1_005), 4)
	assert_eq(hall.upgrade_refusal("side_left", gold, 1_005), "")
	assert_true(hall.upgrade("side_left", gold, 1_005))
	assert_eq(gold.amount, 290)
	assert_eq(hall.seconds_left(1_005), 4)
	# Still a Bunk room in use while the builder works on it.
	assert_eq(hall.state("side_left", 1_006), Hall.State.CONVERTED)
	assert_eq(hall.room_type("side_left"), "bunk_room")
	assert_eq(hall.beds(1_008), 4)
	assert_eq(hall.beds(1_009), 5)
	hall.checkpoint(1_009)
	assert_eq(hall.tier("side_left", 1_009), 2)
	assert_eq(hall.beds(1_009), 5)
	assert_true(hall.upgrade("side_left", gold, 1_009))
	assert_eq(gold.amount, 170)
	assert_eq(hall.seconds_left(1_009), 10)
	assert_eq(hall.beds(1_018), 5)
	# Finished, not yet checkpointed: the beds and the tier count already.
	assert_eq(hall.beds(1_019), 6)
	assert_eq(hall.tier("side_left", 1_019), 3)
	assert_eq(hall.upgrade_refusal("side_left", gold, 1_019), "Highest tier")
	assert_false(hall.upgrade("side_left", gold, 1_019))
	hall.checkpoint(1_019)
	assert_eq(hall.upgrade_refusal("side_left", gold, 1_019), "Highest tier")
	assert_false(hall.upgrade("side_left", gold, 1_019))
	assert_eq(gold.amount, 170)
	assert_eq(hall.building, "")
	assert_eq(hall.beds(1_019), 6)


func test_every_upgrade_refusal_changes_nothing_builder_busy_short_gold_highest_tier_and_not_upgradable() -> void:
	var gold := Gold.new(500)
	var hall := _hall_with_bunk_room(gold)
	gold.amount = 59
	_assert_upgrade_refused(hall, "side_left", gold, 1_005, "Need 1 more gold")
	gold.amount = 60
	assert_true(hall.upgrade("side_left", gold, 1_005))
	assert_eq(gold.amount, 0)
	gold.amount = 1_000
	_assert_upgrade_refused(hall, "side_left", gold, 1_006, "Builder busy")
	# One builder: an upgrade under way keeps every other job waiting too.
	assert_eq(hall.convert_refusal("back_left", "common_room", gold, 1_006), "Builder busy")
	assert_false(hall.convert_room("back_left", "common_room", gold, 1_006))
	assert_eq(gold.amount, 1_000)
	hall.checkpoint(1_009)
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_009))
	hall.checkpoint(1_011)
	_assert_upgrade_refused(hall, "back_left", gold, 1_011, "Not upgradable")
	_assert_upgrade_refused(hall, "reception", gold, 1_011, "Not upgradable")
	assert_true(hall.upgrade("side_left", gold, 1_011))
	hall.checkpoint(1_021)
	_assert_upgrade_refused(hall, "side_left", gold, 1_021, "Highest tier")
	assert_eq(hall.beds(1_021), 6)


# Asserts upgrading `slot` at `now` is refused for `reason`, and that trying leaves the gold, the
# builder and the beds as they were.
func _assert_upgrade_refused(hall: Hall, slot: String, gold: Gold, now: int, reason: String) -> void:
	var before := [gold.amount, hall.building, hall.building_since, hall.beds(now), hall.tier(slot, now)]
	assert_eq(hall.upgrade_refusal(slot, gold, now), reason, slot)
	assert_false(hall.upgrade(slot, gold, now), slot)
	assert_eq([gold.amount, hall.building, hall.building_since, hall.beds(now), hall.tier(slot, now)], before, slot)


func test_a_bunk_rooms_tier_and_an_upgrade_under_way_survive_save_and_load() -> void:
	var gold := Gold.new(500)
	var hall := _hall_with_bunk_room(gold)
	assert_true(hall.upgrade("side_left", gold, 1_005))
	hall.checkpoint(1_009)
	assert_true(hall.upgrade("side_left", gold, 1_009))
	hall.checkpoint(1_012)
	var file := ConfigFile.new()
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_eq(loaded.tier("side_left", 1_012), 2)
	assert_eq(loaded.beds(1_012), 5)
	assert_eq(loaded.building, "side_left")
	assert_eq(loaded.seconds_left(1_012), 7)
	assert_eq(loaded.state("side_left", 1_012), Hall.State.CONVERTED)
	assert_eq(loaded.upgrade_refusal("side_left", Gold.new(1_000), 1_012), "Builder busy")
	assert_eq(loaded.beds(1_018), 5)
	assert_eq(loaded.beds(1_019), 6)
	loaded.checkpoint(1_019)
	file = ConfigFile.new()
	loaded.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var reloaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_eq(reloaded.tier("side_left", 1_019), 3)
	assert_eq(reloaded.beds(1_019), 6)
	assert_eq(reloaded.building, "")
	assert_eq(reloaded.upgrade_refusal("side_left", Gold.new(1_000), 1_019), "Highest tier")


func test_a_save_without_tiers_loads_its_bunk_rooms_at_tier_1_with_the_same_beds_and_a_conversion_under_way_as_one() -> void:
	# What a build before tiers saved: a finished Bunk room and a Common room being built.
	var file := ConfigFile.new()
	file.set_value("hall", "layout", Hall.NEW_LAYOUT)
	file.set_value("hall", "restored", PackedStringArray(["side_left", "back_left"]))
	file.set_value("hall", "converted", {"side_left": {"type": "bunk_room", "done_at": 1_100}})
	file.set_value("hall", "restoring", "back_left")
	file.set_value("hall", "restoring_since", 1_200)
	file.set_value("hall", "converting_into", "common_room")
	file.set_value("hall", "building_seconds", 2)
	file.set_value("hall", "checked_at", 1_201)
	assert_eq(file.save(SAVE_PATH), OK)

	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	assert_eq(hall.tier("side_left", 1_201), 1)
	assert_eq(hall.beds(1_201), 4)
	assert_eq(hall.state("back_left", 1_201), Hall.State.CONVERTING)
	assert_eq(hall.state("back_left", 1_202), Hall.State.CONVERTED)
	hall.checkpoint(1_202)
	assert_eq(hall.room_type("back_left"), "common_room")
	assert_eq(hall.tier("side_left", 1_202), 1)
	assert_eq(hall.beds(1_202), 4)
	var gold := Gold.new(60)
	assert_true(hall.upgrade("side_left", gold, 1_202))
	assert_eq(gold.amount, 0)
	assert_eq(hall.beds(1_206), 5)


func test_on_the_hall_an_upgradable_bunk_rooms_icon_opens_the_confirm_card_and_confirming_starts_the_upgrade() -> void:
	var gold := Gold.new(500)
	var hall := _hall_with_bunk_room(gold)
	# On a layer above GUT's own output window, with Touch as main.tscn has it.
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child_autofree(layer)
	layer.add_child(Touch.new())
	var hall_view := (load("res://screens/hall_view.tscn") as PackedScene).instantiate() as HallView
	layer.add_child(hall_view)
	hall_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hall_view.size = Vector2(1000, 700)
	var sheet := (load("res://screens/confirm_sheet.tscn") as PackedScene).instantiate() as ConfirmSheet
	layer.add_child(sheet)
	# The same as main.gd does with the signals.
	var upgrading := [""]
	hall_view.upgrade_pressed.connect(func(slot: String) -> void:
		upgrading[0] = slot
		var next := hall.next_upgrade(slot, 1_005)
		sheet.offer("Upgrade " + Hall.ROOM_TYPES[hall.room_type(slot)]["name"], next["gold"], next["seconds"], "Upgrade", hall.upgrade_refusal(slot, gold, 1_005), "+1 bed"))
	sheet.confirmed.connect(func() -> void:
		hall.upgrade(upgrading[0], gold, 1_005)
		sheet.close())
	hall_view.show_state(hall, Dispatch.new(1_005), 0, 1_005)
	await wait_process_frames(1)

	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_true(sheet.visible)
	assert_eq((sheet.get_node("Sheet/Box/Title") as Label).text, "Upgrade Bunk room")
	assert_eq((sheet.get_node("Sheet/Box/Price/Cost") as Label).text, "60g")
	var note := sheet.get_node("Sheet/Box/Note") as Label
	assert_true(note.is_visible_in_tree())
	assert_eq(note.text, "+1 bed")
	var action := sheet.get_node("Sheet/Box/Buttons/Action") as Button
	assert_eq(action.text, "Upgrade")
	assert_eq(hall.building, "")
	_tap(action.get_global_rect().get_center())
	await wait_process_frames(1)
	assert_false(sheet.visible)
	assert_eq(hall.building, "side_left")
	assert_eq(gold.amount, 350 - 60)


func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click.xformed_by(get_viewport().get_final_transform()))
		Input.flush_buffered_events()


func test_the_rank_up_checklist_reports_reputation_rooms_in_use_counting_only_rooms_that_take_a_job_and_gold_each_with_whether_it_is_met() -> void:
	var hall := Hall.new(1_000)
	assert_eq(hall.rank_up_checklist(9, 120, 1_000), [
		{"what": "reputation", "has": 9, "needs": 15, "met": false},
		{"what": "rooms", "has": 0, "needs": 2, "met": false},
		{"what": "gold", "has": 120, "needs": 150, "met": false},
	])
	# The side room becomes a Bunk room, finished at 1_007; the backroom a Common room, under way
	# until 1_009.
	var gold := Gold.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_001))
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_005))
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_007))
	assert_eq(hall.rank_up_checklist(15, 150, 1_008), [
		{"what": "reputation", "has": 15, "needs": 15, "met": true},
		{"what": "rooms", "has": 1, "needs": 2, "met": false},
		{"what": "gold", "has": 150, "needs": 150, "met": true},
	])
	# Finished, though no checkpoint has recorded it yet.
	assert_eq(hall.rank_up_checklist(14, 149, 1_009), [
		{"what": "reputation", "has": 14, "needs": 15, "met": false},
		{"what": "rooms", "has": 2, "needs": 2, "met": true},
		{"what": "gold", "has": 149, "needs": 150, "met": false},
	])


func test_the_rank_up_checklist_of_a_six_room_hall_counts_its_four_rooms_and_a_guild_at_its_last_rank_has_none() -> void:
	var hall := Hall.new(1_000)
	hall.layout = Hall.OLD_LAYOUT
	assert_eq(hall.rank_up_checklist(0, 0, 1_000)[1], {"what": "rooms", "has": 0, "needs": 4, "met": false})
	hall.rank = "E"
	assert_eq(hall.rank_up_checklist(100, 10_000, 1_000), [])


## A new game's hall at 1_000 with its side room a Bunk room and its backroom a Common room, both
## finished by 1_009 and checkpointed at 1_010, paid from `gold` (60, 60, 30 and 60).
func _rank_f_hall_in_use(gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_001))
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_005))
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_007))
	hall.checkpoint(1_010)
	return hall


func _assert_rank_up_refused(hall: Hall, reputation: int, gold: Gold, now: int, reason: String) -> void:
	var held := gold.amount
	var rank := hall.rank
	assert_eq(hall.rank_up_refusal(reputation, gold, now), reason)
	assert_false(hall.rank_up(reputation, gold, now), reason)
	assert_eq(gold.amount, held, reason)
	assert_eq(hall.rank, rank, reason)
	assert_true(hall.ranked_at.is_empty(), reason)
	assert_eq(hall.state("front_right", now), Hall.State.UNBUILT, reason)


func test_each_rank_up_refusal_changes_nothing_reputation_first_then_every_room_in_use_then_gold_and_none_past_the_last_rank() -> void:
	var hall := Hall.new(1_000)
	_assert_rank_up_refused(hall, 9, Gold.new(100), 1_000, "Need 6 more reputation")
	_assert_rank_up_refused(hall, 15, Gold.new(100), 1_000, "Every room in use first")
	hall = _rank_f_hall_in_use(Gold.new(1_000))
	_assert_rank_up_refused(hall, 15, Gold.new(120), 1_010, "Need 30 more gold")
	hall.rank = "E"
	_assert_rank_up_refused(hall, 100, Gold.new(10_000), 1_010, "Highest rank for now")


func test_ranking_up_pays_150_sets_rank_e_records_when_and_grows_the_wing_damaged_beside_a_usable_entrance_hall() -> void:
	var hall := _rank_f_hall_in_use(Gold.new(1_000))
	var gold := Gold.new(200)
	assert_eq(hall.rank_up_refusal(15, gold, 1_020), "")
	assert_true(hall.rank_up(15, gold, 1_020))
	assert_eq(gold.amount, 50)
	assert_eq(hall.rank, "E")
	assert_eq(hall.ranked_at, {"E": 1_020})
	# The rooms it had keep their state; the wing's start damaged, the entrance hall usable.
	assert_eq(hall.state("reception", 1_020), Hall.State.USABLE)
	assert_eq(hall.room_type("side_left"), "bunk_room")
	assert_eq(hall.room_type("back_left"), "common_room")
	assert_eq(hall.state("side_left", 1_020), Hall.State.CONVERTED)
	assert_eq(hall.state("back_left", 1_020), Hall.State.CONVERTED)
	assert_eq(hall.state("entrance", 1_020), Hall.State.USABLE)
	for slot: String in ["back_right", "side_right", "front_right"]:
		assert_eq(hall.state(slot, 1_020), Hall.State.DAMAGED, slot)
	assert_eq(hall.state("upper_nw", 1_020), Hall.State.UNBUILT)
	# The Reception gives what it gave at rank F.
	assert_eq(hall.beds(1_020), 4)
	assert_eq([hall.reception("beds"), hall.reception("candidate_slots"), hall.reception("board_slots"), hall.reception("stash")], [2, 1, 2, 6])
	# The game's third, fourth and fifth restores.
	var restoring := Gold.new(620)
	assert_eq(hall.next_restore(), {"gold": 120, "seconds": 4})
	assert_true(hall.restore("back_right", restoring, 1_020))
	hall.checkpoint(1_030)
	assert_eq(hall.next_restore(), {"gold": 200, "seconds": 10})
	assert_true(hall.restore("side_right", restoring, 1_030))
	hall.checkpoint(1_040)
	assert_eq(hall.next_restore(), {"gold": 300, "seconds": 20})
	assert_true(hall.restore("front_right", restoring, 1_040))
	assert_eq(restoring.amount, 0)


func test_a_hall_from_before_guild_ranks_ranks_up_gaining_only_the_front_room_and_keeping_its_capacity() -> void:
	var file := ConfigFile.new()
	file.set_value("hall", "restored", PackedStringArray(["back_left", "back_right", "side_left", "side_right"]))
	file.set_value("hall", "converted", {"back_left": {"type": "tavern", "done_at": 1_100}, "side_left": {"type": "bunk_room", "done_at": 1_050}, "back_right": {"type": "infirmary", "done_at": 1_060}, "side_right": {"type": "quest_hall", "done_at": 1_070}})
	file.set_value("hall", "checked_at", 1_200)
	assert_eq(file.save(SAVE_PATH), OK)
	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	var gold := Gold.new(150)
	assert_true(hall.rank_up(15, gold, 2_000))
	assert_eq(gold.amount, 0)
	assert_eq(hall.rank, "E")
	assert_eq(hall.state("front_right", 2_000), Hall.State.DAMAGED)
	for slot: String in ["entrance", "reception"]:
		assert_eq(hall.state(slot, 2_000), Hall.State.USABLE, slot)
	for slot: String in ["back_left", "side_left", "back_right", "side_right"]:
		assert_eq(hall.state(slot, 2_000), Hall.State.CONVERTED, slot)
	assert_eq(hall.room_type("back_right"), "infirmary")
	assert_eq(hall.beds(2_000), 6)
	assert_eq([hall.reception("beds"), hall.reception("candidate_slots"), hall.reception("board_slots"), hall.reception("stash")], [4, 2, 3, 20])
	assert_eq(hall.stash_cap(2_000), 20)


func test_a_ranked_up_hall_survives_save_and_load() -> void:
	var old := _six_room_hall(1_000)
	old.rank = "F"
	for slot: String in ["back_left", "back_right", "side_left", "side_right"]:
		old.restored.append(slot)
	old.converted.assign({"back_left": {"type": "bunk_room", "done_at": 1_000}, "back_right": {"type": "common_room", "done_at": 1_000}, "side_left": {"type": "tavern", "done_at": 1_000}, "side_right": {"type": "infirmary", "done_at": 1_000}})
	for start: Hall in [_rank_f_hall_in_use(Gold.new(1_000)), old]:
		assert_true(start.rank_up(15, Gold.new(150), 1_020))
		var file := ConfigFile.new()
		start.write(file)
		assert_eq(file.save(SAVE_PATH), OK)
		var loaded := Hall.load_or_start(SAVE_PATH, 1_030)
		assert_eq(loaded.rank, "E")
		assert_eq(loaded.ranked_at, {"E": 1_020})
		assert_eq(loaded.layout, start.layout)
		for slot: String in ["back_left", "back_right", "side_left", "reception", "side_right", "entrance", "front_right", "upper_nw"]:
			assert_eq(loaded.state(slot, 1_030), start.state(slot, 1_030), slot)
		for capacity: String in ["beds", "candidate_slots", "board_slots", "stash"]:
			assert_eq(loaded.reception(capacity), start.reception(capacity), capacity)
		assert_eq(loaded.rank_up_refusal(100, Gold.new(10_000), 1_030), "Highest rank for now")
	assert_eq(old.reception("stash"), 20)


func test_a_storeroom_can_be_built_only_at_rank_e_and_once_finished_adds_6_to_the_stash_cap() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_030)
	assert_eq(Hall.ROOM_TYPES["storeroom"]["name"], "Storeroom")
	assert_eq(Hall.ROOM_TYPES["storeroom"]["blurb"], "6 more stash slots")
	assert_eq(hall.convert_refusal("side_left", "storeroom", gold, 1_030), "Guild rank E")
	assert_false(hall.convert_room("side_left", "storeroom", gold, 1_030))
	assert_eq(gold.amount, 940)
	assert_eq(hall.state("side_left", 1_030), Hall.State.RESTORED)
	hall.rank = "E"
	assert_eq(hall.stash_cap(1_030), 6)
	assert_true(hall.convert_room("side_left", "storeroom", gold, 1_030))
	assert_eq(gold.amount, 880)
	assert_eq(hall.stash_cap(1_031), 6)
	assert_eq(hall.stash_cap(1_032), 12)
	hall.checkpoint(1_040)
	assert_eq(hall.stash_cap(1_040), 12)
	var gear := Gear.new()
	gear.stash_cap = hall.stash_cap(1_040)
	for i: int in 12:
		assert_true(gear.stow("belt"), str(i))
	assert_false(gear.stow("belt"))


func test_extending_is_refused_at_rank_e_with_nothing_changed_and_allowed_at_rank_d() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_restores(3, gold)
	hall.rank = "E"
	assert_eq(hall.extend_refusal(gold, 1_450), "Guild rank D")
	assert_false(hall.extend(gold, 1_450))
	assert_eq(gold.amount, 760)
	assert_eq(hall.building, "")
	hall.rank = "D"
	assert_true(hall.extend(gold, 1_450))
	assert_eq(gold.amount, 360)
