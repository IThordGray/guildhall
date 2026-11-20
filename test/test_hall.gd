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


func test_the_convert_choices_are_a_quest_hall_an_infirmary_and_a_bunk_room_each_60_gold_and_a_minute() -> void:
	assert_eq(Hall.ROOM_TYPES.keys(), ["quest_hall", "infirmary", "bunk_room"])
	assert_eq(Hall.ROOM_TYPES["quest_hall"]["name"], "Quest hall")
	assert_eq(Hall.ROOM_TYPES["quest_hall"]["blurb"], "adds a slot to the quest board")
	assert_eq(Hall.ROOM_TYPES["infirmary"]["name"], "Infirmary")
	assert_eq(Hall.ROOM_TYPES["infirmary"]["blurb"], "injuries heal twice as fast")
	assert_eq(Hall.ROOM_TYPES["bunk_room"]["name"], "Bunk room")
	assert_eq(Hall.ROOM_TYPES["bunk_room"]["blurb"], "2 more beds")
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
	hall.convert_room("back_right", "infirmary", gold, 1_520)
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
