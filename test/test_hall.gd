extends GutTest

const SAVE_PATH: String = "user://test_hall_save.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_a_new_hall_has_the_entrance_and_reception_usable_and_other_rooms_damaged() -> void:
	var hall := Hall.new(1_000)
	assert_eq(hall.state("entrance", 1_000), Hall.State.USABLE)
	assert_eq(hall.state("reception", 1_000), Hall.State.USABLE)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)


func test_restoring_the_first_damaged_room_takes_60_gold_at_once() -> void:
	var gold := Gold.new(150)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_eq(gold.amount, 90)
	assert_eq(hall.state("back_left", 1_000), Hall.State.RESTORING)


func test_each_room_restored_costs_and_takes_more_than_the_last_60g_30s_120g_2m_200g_5m_then_300g_10m() -> void:
	var expected := [[60, 30], [120, 120], [200, 300], [300, 600]]
	var slots: Array[String] = ["back_left", "back_right", "side_left", "side_right"]
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
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
	assert_eq(gold.amount, 1_000 - 60 - 120 - 200 - 300)


func test_restoring_is_refused_with_the_shortfall_when_gold_is_short() -> void:
	var gold := Gold.new(40)
	var hall := Hall.new(1_000)
	assert_eq(hall.refusal("back_left", gold, 1_000), "Need 20 more gold")
	assert_false(hall.restore("back_left", gold, 1_000))
	assert_eq(gold.amount, 40)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)
	gold.amount += 20
	assert_eq(hall.refusal("back_left", gold, 1_020), "")


func test_restoring_a_second_room_is_refused_with_the_shortfall_for_the_second_price() -> void:
	var gold := Gold.new(100)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	hall.checkpoint(1_030)
	assert_eq(gold.amount, 40)
	assert_eq(hall.refusal("back_right", gold, 1_030), "Need 80 more gold")
	assert_false(hall.restore("back_right", gold, 1_030))
	assert_eq(gold.amount, 40)
	assert_eq(hall.state("back_right", 1_030), Hall.State.DAMAGED)
	gold.amount += 80
	assert_eq(hall.refusal("back_right", gold, 1_030), "")
	assert_true(hall.restore("back_right", gold, 1_030))
	assert_eq(gold.amount, 0)


func test_restoring_is_refused_while_the_builder_is_busy_and_allowed_once_free() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_eq(hall.refusal("back_right", gold, 1_010), "Builder busy")
	assert_false(hall.restore("back_right", gold, 1_010))
	assert_eq(gold.amount, 940)
	assert_eq(hall.state("back_right", 1_010), Hall.State.DAMAGED)
	assert_true(hall.restore("back_right", gold, 1_030))
	assert_eq(hall.state("back_left", 1_030), Hall.State.RESTORED)


func test_restoring_is_refused_for_a_room_that_is_not_damaged() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	assert_false(hall.restore("entrance", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_false(hall.restore("back_left", gold, 1_200))
	assert_eq(gold.amount, 940)


func test_the_first_room_is_restored_exactly_30_seconds_after_starting() -> void:
	var gold := Gold.new(60)
	var hall := Hall.new(1_000)
	hall.restore("side_left", gold, 1_000)
	assert_eq(hall.state("side_left", 1_029), Hall.State.RESTORING)
	assert_eq(hall.seconds_left(1_029), 1)
	assert_eq(hall.state("side_left", 1_030), Hall.State.RESTORED)
	assert_eq(hall.seconds_left(1_030), 0)


func test_a_clock_set_back_after_completion_keeps_the_room_restored_and_charges_nothing() -> void:
	var gold := Gold.new(240)
	var hall := Hall.new(1_000)
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
	var gold := Gold.new(60)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_015)
	assert_eq(hall.seconds_left(500), 15)
	hall.checkpoint(500)
	assert_eq(hall.seconds_left(500), 15)
	assert_eq(hall.seconds_left(1_020), 10)


func test_a_restoration_in_progress_survives_save_and_load() -> void:
	var gold := Gold.new(500)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_120)
	hall.restore("side_right", gold, 1_130)
	hall.checkpoint(1_150)
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_eq(loaded.state("back_left", 1_150), Hall.State.RESTORED)
	assert_eq(loaded.state("side_right", 1_150), Hall.State.RESTORING)
	assert_eq(loaded.seconds_left(1_150), 100)
	assert_eq(loaded.state("side_right", 1_250), Hall.State.RESTORED)
	assert_eq(loaded.state("back_right", 1_150), Hall.State.DAMAGED)
	assert_eq(loaded.next_restore(), {"gold": 200, "seconds": 300})
	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 500 - 60 - 120)


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
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_010)
	assert_false(hall.finished_since_checkpoint(1_020))
	assert_true(hall.finished_since_checkpoint(1_300))
	hall.checkpoint(1_300)
	assert_false(hall.finished_since_checkpoint(1_400))
	assert_eq(hall.state("back_left", 1_400), Hall.State.RESTORED)


## A hall at 1_000 with `slot` restored by 1_120 and the builder free, the restoration paid from `gold`.
func _hall_with_empty_room(slot: String, gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	assert_true(hall.restore(slot, gold, 1_000))
	hall.checkpoint(1_120)
	return hall


func test_the_convert_choices_are_every_room_type_each_60_gold_and_a_minute() -> void:
	assert_eq(Hall.ROOM_TYPES.keys(), ["quest_hall", "infirmary", "bunk_room", "tavern", "map_room", "training_room", "common_room"])
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
		assert_eq(Hall.ROOM_TYPES[type]["gold"], 60, type)
		assert_eq(Hall.ROOM_TYPES[type]["seconds"], 60, type)


func test_the_guild_has_4_beds_and_each_finished_bunk_room_adds_2_up_to_8() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_eq(hall.beds(1_120), 4)
	assert_true(hall.convert_room("back_left", "bunk_room", gold, 1_120))
	assert_eq(hall.beds(1_179), 4)
	assert_eq(hall.beds(1_180), 6)
	# Other rooms add no beds.
	hall.converted["side_left"] = {"type": "infirmary", "done_at": 1_000}
	assert_eq(hall.beds(1_180), 6)
	hall.converted["back_right"] = {"type": "bunk_room", "done_at": 1_000}
	assert_eq(hall.beds(1_180), 8)
	hall.converted["side_right"] = {"type": "bunk_room", "done_at": 1_000}
	assert_eq(hall.beds(1_180), 8)


func test_converting_an_empty_room_takes_60_gold_at_once_and_finishes_exactly_60_seconds_later() -> void:
	var gold := Gold.new(200)
	var hall := _hall_with_empty_room("back_left", gold)
	assert_eq(hall.convert_refusal("back_left", "quest_hall", gold, 1_200), "")
	assert_true(hall.convert_room("back_left", "quest_hall", gold, 1_200))
	assert_eq(gold.amount, 80)
	assert_eq(hall.state("back_left", 1_259), Hall.State.CONVERTING)
	assert_eq(hall.seconds_left(1_259), 1)
	assert_eq(hall.rooms_done("quest_hall", 1_259), 0)
	assert_eq(hall.state("back_left", 1_260), Hall.State.CONVERTED)
	assert_eq(hall.seconds_left(1_260), 0)
	assert_eq(hall.room_type("back_left"), "quest_hall")
	assert_eq(hall.rooms_done("quest_hall", 1_260), 1)
	assert_eq(hall.rooms_done("infirmary", 1_260), 0)
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
	assert_eq(hall.convert_refusal("back_left", "quest_hall", gold, 1_250), "Builder busy")
	assert_false(hall.convert_room("back_left", "quest_hall", gold, 1_250))
	assert_eq(gold.amount, 820)
	assert_true(hall.convert_room("back_left", "quest_hall", gold, 1_320))
	assert_eq(hall.state("back_right", 1_320), Hall.State.RESTORED)

	assert_eq(hall.refusal("side_left", gold, 1_330), "Builder busy")
	assert_false(hall.restore("side_left", gold, 1_330))
	assert_eq(hall.convert_refusal("back_right", "infirmary", gold, 1_330), "Builder busy")
	assert_false(hall.convert_room("back_right", "infirmary", gold, 1_330))
	assert_eq(gold.amount, 760)
	assert_true(hall.restore("side_left", gold, 1_380))
	assert_eq(gold.amount, 560)


func test_only_an_empty_restored_room_can_be_converted() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	for slot: String in ["entrance", "reception", "back_left"]:
		assert_eq(hall.convert_refusal(slot, "quest_hall", gold, 1_000), "Not an empty room", slot)
		assert_false(hall.convert_room(slot, "quest_hall", gold, 1_000), slot)
	hall.restore("back_left", gold, 1_000)
	assert_eq(hall.convert_refusal("back_left", "quest_hall", gold, 1_020), "Not an empty room")
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


## A hall with back_left converted into a Tavern from 1_200 to 1_260 and back_right restored and
## empty from 1_380, the builder free, paid from `gold`.
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
	assert_eq(gold.amount, 760)
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_400), "Already built")
	assert_false(hall.convert_room("back_right", "tavern", gold, 1_400))
	assert_eq(gold.amount, 760)
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
	assert_eq(gold.amount, 760)
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_299), "Being built")
	assert_false(hall.convert_room("back_right", "tavern", gold, 1_299))
	assert_eq(hall.convert_refusal("back_right", "infirmary", gold, 1_299), "Builder busy")
	assert_eq(gold.amount, 760)
	assert_eq(hall.state("back_right", 1_299), Hall.State.RESTORED)
	# Finished but not yet checkpointed, and after.
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_300), "Already built")
	assert_false(hall.convert_room("back_right", "tavern", gold, 1_300))
	hall.checkpoint(1_300)
	assert_eq(hall.convert_refusal("back_right", "tavern", gold, 1_300), "Already built")
	assert_eq(gold.amount, 760)
	assert_eq(hall.state("back_right", 1_300), Hall.State.RESTORED)


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
	assert_eq(hall.first_done_at("infirmary"), 1_260)
	assert_eq(hall.first_done_at("quest_hall"), -1)
	hall.checkpoint(1_400)
	hall.restore("back_right", gold, 1_400)
	hall.checkpoint(1_520)
	# A second Infirmary, as a save from before rooms were unique can hold.
	hall.converted["back_right"] = {"type": "infirmary", "done_at": 1_580}
	assert_eq(hall.first_done_at("infirmary"), 1_260)
	hall.checkpoint(1_600)
	assert_eq(hall.first_done_at("infirmary"), 1_260)
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
	assert_eq(gold.amount, 60)


func test_a_clock_set_back_mid_conversion_adds_no_time_and_does_not_undo_it() -> void:
	var gold := Gold.new(300)
	var hall := _hall_with_empty_room("back_left", gold)
	hall.convert_room("back_left", "infirmary", gold, 1_200)
	hall.checkpoint(1_230)
	hall.checkpoint(500)
	assert_eq(hall.state("back_left", 500), Hall.State.CONVERTING)
	assert_eq(hall.seconds_left(500), 30)
	assert_eq(hall.first_done_at("infirmary"), 1_260)
	assert_eq(hall.seconds_left(1_250), 10)
	assert_eq(gold.amount, 180)


func test_a_conversion_in_progress_and_a_converted_room_survive_save_and_load() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room("back_left", gold)
	hall.convert_room("back_left", "infirmary", gold, 1_200)
	hall.checkpoint(1_260)
	hall.restore("side_right", gold, 1_260)
	hall.checkpoint(1_380)
	hall.convert_room("side_right", "quest_hall", gold, 1_400)
	hall.checkpoint(1_420)
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded_gold.amount, 1_000 - 60 - 60 - 120 - 60)
	assert_eq(loaded.state("back_left", 1_420), Hall.State.CONVERTED)
	assert_eq(loaded.room_type("back_left"), "infirmary")
	assert_eq(loaded.first_done_at("infirmary"), 1_260)
	assert_eq(loaded.state("side_right", 1_420), Hall.State.CONVERTING)
	assert_eq(loaded.seconds_left(1_420), 40)
	assert_eq(loaded.convert_refusal("back_right", "quest_hall", loaded_gold, 1_420), "Not an empty room")
	assert_eq(loaded.rooms_done("quest_hall", 1_459), 0)
	assert_eq(loaded.state("side_right", 1_460), Hall.State.CONVERTED)
	assert_eq(loaded.room_type("side_right"), "quest_hall")
	assert_eq(loaded.rooms_done("quest_hall", 1_460), 1)


func _m4_save() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 400)
	file.set_value("hall", "restored", PackedStringArray(["back_left"]))
	file.set_value("hall", "restoring", "side_left")
	file.set_value("hall", "restoring_since", 1_000)
	file.set_value("hall", "checked_at", 1_050)
	file.set_value("dispatch", "outings", [{"quest": "rats", "since": 1_020, "party": PackedStringArray(["bram"]), "seed": 7}])
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
	assert_eq(hall.seconds_left(1_050), 70)
	assert_eq(hall.state("side_left", 1_120), Hall.State.RESTORED)
	assert_eq(hall.state("back_right", 1_050), Hall.State.DAMAGED)
	assert_true(hall.converted.is_empty())
	assert_eq(hall.rooms_done("quest_hall", 1_120), 0)
	assert_eq(hall.first_done_at("infirmary"), -1)
	assert_eq(dispatch.outings[0]["quest"], "rats")
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_050), 30)
	assert_eq(dispatch.injury_left("tobin", 1_050), 150)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(hall.convert_refusal("back_left", "quest_hall", gold, 1_050), "Builder busy")
	assert_true(hall.convert_room("back_left", "quest_hall", gold, 1_120))
	assert_eq(gold.amount, 340)


## A hall with a Tavern in `slot` converted from 1_200, finishing at 1_260, paid from `gold`.
func _hall_with_tavern(slot: String, gold: Gold) -> Hall:
	var hall := _hall_with_empty_room(slot, gold)
	assert_true(hall.convert_room(slot, "tavern", gold, 1_200))
	return hall


func test_a_tavern_holds_no_gold_until_its_conversion_finishes() -> void:
	var hall := _hall_with_tavern("back_left", Gold.new(1_000))
	assert_eq(hall.tavern_gold("back_left", 1_200), 0)
	assert_eq(hall.tavern_gold("back_left", 1_259), 0)
	assert_eq(hall.tavern_gold("back_left", 1_260), 0)
	assert_eq(hall.tavern_gold("back_left", 1_290), 1)


func test_a_finished_tavern_fills_with_2_gold_a_minute_from_when_it_finished() -> void:
	var hall := _hall_with_tavern("back_left", Gold.new(1_000))
	assert_eq(hall.tavern_gold("back_left", 1_260 + 60), 2)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 17 * 60), 34)
	hall.checkpoint(1_260 + 17 * 60)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 17 * 60), 34)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 30 * 60), 60)
	# Other rooms hold none.
	assert_eq(hall.tavern_gold("reception", 1_260 + 30 * 60), 0)


func test_a_tavern_stops_filling_at_120_gold() -> void:
	var hall := _hall_with_tavern("back_left", Gold.new(1_000))
	assert_eq(hall.tavern_gold("back_left", 1_260 + 59 * 60), 118)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 60 * 60), 120)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 61 * 60), 120)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 24 * 3_600), 120)


func test_collecting_moves_exactly_the_tavern_gold_into_gold_and_it_fills_again_from_then() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(gold.amount, 880)
	var at := 1_260 + 17 * 60
	assert_eq(hall.collect("back_left", gold, at), 34)
	assert_eq(gold.amount, 914)
	assert_eq(hall.tavern_gold("back_left", at), 0)
	assert_eq(hall.tavern_gold("back_left", at + 60), 2)
	assert_eq(hall.tavern_gold("back_left", at + 70 * 60), 120)


func test_collecting_twice_in_a_row_gives_nothing_the_second_time() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(hall.collect("back_left", gold, 1_260 + 10 * 60), 20)
	assert_eq(hall.collect("back_left", gold, 1_260 + 10 * 60), 0)
	assert_eq(gold.amount, 900)
	# Collecting an empty room does not restart its filling.
	assert_eq(hall.collect("back_left", gold, 1_260 + 10 * 60 + 29), 0)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 10 * 60 + 30), 1)


func test_a_tavern_finished_since_the_last_checkpoint_can_be_collected() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(hall.collect("back_left", gold, 1_260 + 5 * 60), 10)
	assert_eq(gold.amount, 890)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 6 * 60), 2)


func test_two_taverns_fill_and_are_collected_each_on_their_own() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	hall.checkpoint(1_260)
	assert_true(hall.restore("back_right", gold, 1_260))
	hall.checkpoint(1_380)
	# A second Tavern, as a save from before rooms were unique can hold.
	hall.converted["back_right"] = {"type": "tavern", "done_at": 1_440}
	# The second finishes at 1_440, three minutes after the first.
	var at := 1_440 + 10 * 60
	assert_eq(hall.tavern_gold("back_left", at), 26)
	assert_eq(hall.tavern_gold("back_right", at), 20)
	var before := gold.amount
	assert_eq(hall.collect("back_left", gold, at), 26)
	assert_eq(hall.tavern_gold("back_left", at), 0)
	assert_eq(hall.tavern_gold("back_right", at), 20)
	assert_eq(hall.tavern_gold("back_right", at + 60), 22)
	assert_eq(hall.tavern_gold("back_left", at + 60), 2)
	assert_eq(gold.amount, before + 26)


func test_a_clock_set_back_neither_removes_nor_adds_tavern_gold() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	hall.checkpoint(1_260 + 20 * 60)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 20 * 60), 40)
	hall.checkpoint(500)
	assert_eq(hall.tavern_gold("back_left", 500), 40)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 21 * 60), 42)

	assert_eq(hall.collect("back_left", gold, 1_260 + 21 * 60), 42)
	hall.checkpoint(500)
	assert_eq(hall.tavern_gold("back_left", 500), 0)
	assert_eq(hall.collect("back_left", gold, 500), 0)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 22 * 60), 2)
	# Collected while the clock is set back, it starts filling again from the latest time seen.
	hall.checkpoint(1_260 + 25 * 60)
	assert_eq(hall.collect("back_left", gold, 500), 8)
	assert_eq(hall.tavern_gold("back_left", 1_260 + 25 * 60), 0)
	assert_eq(gold.amount, 880 + 42 + 8)


func test_one_read_after_an_absence_equals_reading_every_second() -> void:
	var away := _hall_with_tavern("back_left", Gold.new(1_000))
	var watched := _hall_with_tavern("back_left", Gold.new(1_000))
	var seen := 0
	for now: int in range(1_200, 1_260 + 50 * 60 + 1):
		watched.checkpoint(now)
		seen = watched.tavern_gold("back_left", now)
	assert_eq(seen, 100)
	assert_eq(away.tavern_gold("back_left", 1_260 + 50 * 60), 100)
	var gold := Gold.new(0)
	assert_eq(away.collect("back_left", gold, 1_260 + 50 * 60), 100)
	assert_eq(watched.collect("back_left", gold, 1_260 + 50 * 60), 100)
	assert_eq(gold.amount, 200)


func test_a_tavern_amount_and_collected_at_survive_save_and_load() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_tavern("back_left", gold)
	assert_eq(hall.collect("back_left", gold, 1_260 + 10 * 60), 20)
	hall.checkpoint(1_260 + 25 * 60)
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded_gold.amount, 900)
	assert_eq(loaded.room_type("back_left"), "tavern")
	assert_eq(loaded.tavern_gold("back_left", 1_260 + 25 * 60), 30)
	assert_eq(loaded.tavern_gold("back_left", 1_260 + 26 * 60), 32)
	assert_eq(loaded.collect("back_left", loaded_gold, 1_260 + 26 * 60), 32)
	assert_eq(loaded_gold.amount, 932)


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
	assert_true(hall.convert_room("side_left", "tavern", gold, 2_000))
	assert_eq(hall.tavern_gold("side_left", 2_060 + 60), 2)


## A hall at 1_000 with `restores` ground-floor rooms restored one after another, paid from `gold`
## (60, then 120, then 200), and the builder free at 1_450.
func _hall_with_restores(restores: int, gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	var slots: Array[String] = ["back_left", "back_right", "side_left"]
	var starts: Array[int] = [1_000, 1_030, 1_150]
	for i: int in restores:
		assert_true(hall.restore(slots[i], gold, starts[i]))
	hall.checkpoint(1_450)
	return hall


## A hall with the First floor built from 1_500 to 2_100 and checkpointed then, paid from `gold`.
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
	assert_eq(gold.amount, 820)
	assert_false(hall.has_first_floor(99_999))
	assert_eq(hall.state("upper_nw", 99_999), Hall.State.UNBUILT)
	assert_eq(hall.seconds_left(1_450), 0)
	# The third restoration counts the moment it finishes, before any checkpoint.
	assert_true(hall.restore("side_left", gold, 1_450))
	assert_eq(hall.extend_refusal(gold, 1_749), "Restore the ground floor first")
	assert_eq(hall.extend_refusal(gold, 1_750), "")


func test_extending_is_refused_while_the_builder_is_busy_with_nothing_changed() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.restore("side_right", gold, 1_500))
	assert_eq(hall.extend_refusal(gold, 1_600), "Builder busy")
	assert_false(hall.extend(gold, 1_600))
	assert_eq(gold.amount, 320)
	assert_eq(hall.building, "side_right")
	assert_false(hall.has_first_floor(99_999))
	# Free again, and the restoration it waited on has spent the gold.
	assert_eq(hall.extend_refusal(gold, 2_100), "Need 80 more gold")


func test_extending_is_refused_with_the_shortfall_when_gold_is_short_with_nothing_changed() -> void:
	var gold := Gold.new(730)
	var hall := _hall_with_restores(3, gold)
	assert_eq(hall.extend_refusal(gold, 1_500), "Need 50 more gold")
	assert_false(hall.extend(gold, 1_500))
	assert_eq(gold.amount, 350)
	assert_eq(hall.seconds_left(1_500), 0)
	assert_false(hall.has_first_floor(99_999))
	gold.amount += 50
	assert_eq(hall.extend_refusal(gold, 1_500), "")


func test_extending_costs_400_gold_and_builds_the_first_floor_exactly_600_seconds_later() -> void:
	var gold := Gold.new(780)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	assert_eq(gold.amount, 0)
	assert_eq(hall.job_seconds(), 600)
	assert_eq(hall.seconds_left(1_500), 600)
	assert_false(hall.has_first_floor(2_099))
	assert_eq(hall.state("upper_nw", 2_099), Hall.State.UNBUILT)
	assert_true(hall.has_first_floor(2_100))
	for slot: String in ["upper_nw", "upper_ne", "upper_sw", "upper_se"]:
		assert_eq(hall.state(slot, 2_100), Hall.State.RESTORED, slot)
	# Restore pricing counts restorations only, under way or after.
	assert_eq(hall.next_restore(), {"gold": 300, "seconds": 600})
	hall.checkpoint(2_100)
	assert_true(hall.has_first_floor(2_100))
	assert_eq(hall.next_restore(), {"gold": 300, "seconds": 600})
	assert_eq(hall.state("side_right", 2_100), Hall.State.DAMAGED)


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
	assert_eq(hall.converted["upper_sw"], {"type": "quest_hall", "done_at": 2_220})
	assert_eq(hall.state("upper_se", 2_280), Hall.State.CONVERTED)
	assert_eq(hall.tavern_gold("upper_se", 2_280 + 10 * 60), 20)
	assert_eq(hall.collect("upper_se", gold, 2_280 + 10 * 60), 20)
	assert_eq(gold.amount, 2_000 - 380 - 400 - 3 * 60 + 20)


func test_the_first_infirmary_done_is_the_one_injured_adventurers_use_on_either_floor() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_first_floor(gold)
	assert_true(hall.convert_room("upper_se", "infirmary", gold, 2_100))
	hall.checkpoint(2_160)
	# A second Infirmary, as a save from before rooms were unique can hold.
	hall.converted["back_left"] = {"type": "infirmary", "done_at": 2_220}
	hall.checkpoint(2_220)
	assert_eq(hall.first_room("infirmary"), "upper_se")
	assert_eq(hall.first_done_at("infirmary"), 2_160)
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
	assert_eq(gold.amount, 2_000 - 380 - 400)
	assert_eq(hall.seconds_left(2_100), 0)


func test_a_clock_set_back_neither_adds_time_to_the_extension_nor_undoes_it() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	hall.checkpoint(1_800)
	hall.checkpoint(900)
	assert_eq(hall.seconds_left(900), 300)
	assert_false(hall.has_first_floor(900))
	hall.checkpoint(2_100)
	hall.checkpoint(900)
	assert_true(hall.has_first_floor(900))
	assert_eq(hall.state("upper_nw", 900), Hall.State.RESTORED)
	assert_eq(hall.extend_refusal(gold, 900), "Already extended")
	assert_eq(gold.amount, 2_000 - 380 - 400)


func test_an_extension_under_way_and_a_built_first_floor_survive_save_and_load() -> void:
	var gold := Gold.new(2_000)
	var hall := _hall_with_restores(3, gold)
	assert_true(hall.extend(gold, 1_500))
	hall.checkpoint(1_700)
	var file := ConfigFile.new()
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_eq(loaded.seconds_left(1_700), 400)
	assert_false(loaded.has_first_floor(2_099))
	assert_eq(loaded.extend_refusal(gold, 1_700), "Already extended")
	assert_eq(loaded.next_restore(), {"gold": 300, "seconds": 600})
	assert_true(loaded.has_first_floor(2_100))

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


func test_an_old_save_loads_with_no_first_floor_and_can_extend() -> void:
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
	assert_true(hall.extend(gold, 2_000))
	assert_eq(gold.amount, 100)
	assert_true(hall.has_first_floor(2_600))


func test_a_restoration_keeps_the_length_it_started_with_when_the_rule_tables_read_differently_later() -> void:
	var gold := Gold.new(500)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	# Another room counted as restored would make today's table give the second room's 2 minutes.
	hall.restored.append("side_left")
	assert_eq(hall.job_seconds(), 30)
	assert_eq(hall.seconds_left(1_000), 30)
	assert_eq(hall.state("back_left", 1_030), Hall.State.RESTORED)


func test_a_job_under_way_loads_with_the_length_saved_when_it_started_and_one_saved_without_it_uses_todays_rule() -> void:
	var gold := Gold.new(1_000)
	var restoring := Hall.new(1_000)
	restoring.restore("back_left", gold, 1_000)
	var converting := _hall_with_empty_room("back_left", gold)
	converting.convert_room("back_left", "infirmary", gold, 1_200)
	var extending := _hall_with_empty_room("back_left", gold)
	for slot: String in ["side_left", "side_right"]:
		extending.restore(slot, gold, extending.checked_at)
		extending.checkpoint(extending.checked_at + 600)
	assert_true(extending.extend(Gold.new(400), extending.checked_at))
	var jobs: Array[Array] = [[restoring, 30], [converting, 60], [extending, 600]]
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
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_030)
	hall.restore("side_left", gold, 1_030)
	assert_eq(hall.seconds_left(1_030), 120)
	assert_eq(hall.state("side_left", 1_149), Hall.State.RESTORING)
	assert_eq(hall.state("side_left", 1_150), Hall.State.RESTORED)
