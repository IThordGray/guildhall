extends GutTest

const SAVE_PATH: String = "user://test_dispatch_save.cfg"
const PARTY: PackedStringArray = ["bram", "ilse", "tobin"]
const EVERYONE: Array[String] = ["bram", "ilse", "tobin", "maren"]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A seed with which `party` on `quest` succeeds, or fails when `success` is false.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var chance := Dispatch.success_chance(quest, party)
	for roll_seed: int in 10_000:
		if Outcome.roll(roll_seed, chance, party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


## Sends PARTY on `quest` with a seed it succeeds with.
func _send_to_succeed(dispatch: Dispatch, quest: String, gold: Gold, now: int) -> bool:
	return dispatch.send(quest, PARTY, _seed(quest, PARTY, true), gold, now)


func _statuses(dispatch: Dispatch, now: int) -> Array[String]:
	var statuses: Array[String] = []
	for adventurer: String in EVERYONE:
		statuses.append(dispatch.status(adventurer, now))
	return statuses


func test_the_board_has_three_quests_each_with_its_difficulty_paying_its_gold_after_its_duration() -> void:
	var expected := {
		"rats": ["Rats in the cellar", 60, 50, 3],
		"moonherbs": ["Gather moonherbs", 180, 150, 7],
		"goblins": ["Goblin camp", 600, 500, 12],
	}
	assert_eq(Dispatch.QUESTS.keys(), expected.keys())
	for quest: String in expected:
		var gold := Gold.new(0)
		var dispatch := Dispatch.new(1_000)
		assert_eq(Dispatch.QUESTS[quest]["name"], expected[quest][0])
		assert_eq(Dispatch.QUESTS[quest]["difficulty"], expected[quest][3])
		assert_true(_send_to_succeed(dispatch, quest, gold, 1_000))
		assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_000), expected[quest][1], quest)
		dispatch.checkpoint(1_000 + expected[quest][1], gold)
		assert_eq(gold.amount, expected[quest][2], quest)


func test_the_roster_has_four_rank_f_adventurers_all_resting_in_a_new_game() -> void:
	var expected := {
		"bram": ["Bram", "Swordsman", "F", 4],
		"ilse": ["Ilse", "Mage", "F", 4],
		"tobin": ["Tobin", "Scout", "F", 3],
		"maren": ["Maren", "Healer", "F", 3],
	}
	assert_eq(Dispatch.ADVENTURERS.keys(), expected.keys())
	for adventurer: String in expected:
		var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
		assert_eq([info["name"], info["class"], info["rank"], info["power"]], expected[adventurer])
	assert_eq(_statuses(Dispatch.new(1_000), 1_000), ["Resting", "Resting", "Resting", "Resting"])


func test_the_success_chance_is_from_the_picked_party_against_the_quest() -> void:
	assert_eq(Dispatch.success_chance("moonherbs", ["bram", "tobin"]), 50)
	assert_eq(Dispatch.success_chance("moonherbs", ["bram", "ilse"]), 60)
	assert_eq(Dispatch.success_chance("goblins", ["bram", "ilse", "maren"]), 40)
	assert_eq(Dispatch.success_chance("rats", ["tobin"]), 50)


func test_sending_the_party_starts_its_timer_and_refuses_another_send_while_out() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_eq(dispatch.refusal(), "")
	assert_true(_send_to_succeed(dispatch, "moonherbs", gold, 1_000))
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_030), 150)
	assert_eq(dispatch.refusal(), "Party is out")
	assert_eq(dispatch.party_refusal(["maren"], 1_030), "Party is out")
	assert_false(dispatch.send("rats", ["maren"], 0, gold, 1_030))
	assert_eq(dispatch.outings.size(), 1)
	assert_eq(dispatch.outings[0]["quest"], "moonherbs")
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_030), 150)
	assert_eq(dispatch.status("maren", 1_030), "Resting")


func test_the_party_shows_as_on_its_quest_and_the_others_as_resting() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("goblins", ["ilse", "maren"], 7, gold, 1_000))
	assert_eq(_statuses(dispatch, 1_100), ["Resting", "On quest: Goblin camp", "Resting", "On quest: Goblin camp"])


func test_a_party_is_one_to_three_adventurers_who_are_home_and_well() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_eq(dispatch.party_refusal([], 1_000), "Pick at least one adventurer")
	assert_false(dispatch.send("rats", [], 1, gold, 1_000))
	assert_eq(dispatch.party_refusal(["bram", "ilse", "tobin", "maren"], 1_000), "At most 3 in a party")
	assert_false(dispatch.send("rats", ["bram", "ilse", "tobin", "maren"], 1, gold, 1_000))
	assert_true(dispatch.outings.is_empty())
	assert_eq(dispatch.party_refusal(["tobin"], 1_000), "")
	assert_eq(dispatch.party_refusal(["bram", "ilse", "tobin"], 1_000), "")
	assert_true(dispatch.send("rats", ["bram", "ilse", "tobin"], 1, gold, 1_000))


func test_an_injured_adventurer_cannot_be_picked_until_recovered() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_600, gold)
	assert_false(dispatch.can_go("tobin", 1_600))
	assert_true(dispatch.can_go("bram", 1_600))
	assert_eq(dispatch.party_refusal(["bram", "tobin"], 1_600), "Tobin can't go")
	assert_false(dispatch.send("rats", ["bram", "tobin"], 1, gold, 1_600))
	assert_true(dispatch.outings.is_empty())
	assert_true(dispatch.can_go("tobin", 1_900))
	assert_true(dispatch.send("rats", ["bram", "tobin"], 1, gold, 1_900))


func test_an_adventurer_out_on_a_quest_cannot_be_picked_and_is_free_once_home() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("rats", ["bram"], _seed("rats", ["bram"], true), gold, 1_000)
	assert_false(dispatch.can_go("bram", 1_030))
	assert_true(dispatch.can_go("ilse", 1_030))
	dispatch.checkpoint(1_060, gold)
	assert_true(dispatch.can_go("bram", 1_060))


func test_a_success_pays_the_full_reward_and_injures_nobody() -> void:
	var gold := Gold.new(5)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("rats", ["bram", "maren"], _seed("rats", ["bram", "maren"], true), gold, 1_000)
	dispatch.checkpoint(1_060, gold)
	assert_eq(gold.amount, 55)
	assert_eq(dispatch.last_return, "Rats in the cellar: success · +50 gold")
	assert_eq(_statuses(dispatch, 1_060), ["Resting", "Resting", "Resting", "Resting"])


func test_a_failure_pays_a_quarter_rounded_down_and_injures_one_member_for_five_minutes_from_return() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	var roll_seed := _seed("moonherbs", PARTY, false)
	var injured := Outcome.roll(roll_seed, Dispatch.success_chance("moonherbs", PARTY), PARTY).injured
	dispatch.send("moonherbs", PARTY, roll_seed, gold, 1_000)
	# Returns at 1_180; the checkpoint comes 100 s later, as on opening the app.
	dispatch.checkpoint(1_280, gold)
	assert_eq(gold.amount, 37)
	var hurt: Array[String] = []
	for adventurer: String in EVERYONE:
		if not dispatch.can_go(adventurer, 1_280):
			hurt.append(adventurer)
	assert_eq(hurt, [injured])
	assert_eq(dispatch.injury_left(injured, 1_280), 200)
	assert_eq(dispatch.status(injured, 1_280), "Injured · 3:20")
	var injured_name: String = Dispatch.ADVENTURERS[injured]["name"]
	assert_eq(dispatch.last_return, "Gather moonherbs: failed · +37 gold · %s injured" % injured_name)
	assert_eq(dispatch.injury_left(injured, 1_479), 1)
	assert_eq(dispatch.status(injured, 1_480), "Resting")


func test_a_failed_goblin_camp_pays_125_and_names_the_injured() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_600, gold)
	assert_eq(gold.amount, 125)
	assert_eq(dispatch.last_return, "Goblin camp: failed · +125 gold · Tobin injured")


func test_the_outcome_is_not_revealed_before_the_party_returns() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_599, gold)
	assert_eq(dispatch.last_return, "")
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.status("tobin", 1_599), "On quest: Goblin camp")
	dispatch.checkpoint(1_600, gold)
	assert_ne(dispatch.last_return, "")


func test_the_reward_lands_exactly_when_the_quest_ends_and_not_a_second_before() -> void:
	var gold := Gold.new(10)
	var dispatch := Dispatch.new(1_000)
	_send_to_succeed(dispatch, "rats", gold, 1_000)
	dispatch.checkpoint(1_059, gold)
	assert_eq(gold.amount, 10)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_059), 1)
	assert_eq(dispatch.refusal(), "Party is out")
	dispatch.checkpoint(1_060, gold)
	assert_eq(gold.amount, 60)
	assert_eq(dispatch.refusal(), "")


func test_the_reward_is_paid_once_however_many_checkpoints_follow() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	_send_to_succeed(dispatch, "rats", gold, 1_000)
	for now: int in [1_060, 1_061, 1_200, 5_000, 5_000]:
		dispatch.checkpoint(now, gold)
	assert_eq(gold.amount, 50)


func test_a_quest_that_ended_while_the_app_was_closed_pays_on_the_first_checkpoint_after() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	_send_to_succeed(dispatch, "goblins", gold, 1_000)
	dispatch.checkpoint(1_010, gold)
	assert_false(dispatch.returned_since_checkpoint(1_500))
	assert_true(dispatch.returned_since_checkpoint(9_000))
	dispatch.checkpoint(9_000, gold)
	assert_eq(gold.amount, 500)
	assert_false(dispatch.returned_since_checkpoint(9_000))


func test_an_injury_runs_out_while_the_app_is_closed() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_010, gold)
	dispatch.checkpoint(1_000 + 600 + 300, gold)
	assert_eq(gold.amount, 125)
	assert_eq(dispatch.status("tobin", 1_900), "Resting")


func test_a_clock_set_back_after_the_return_pays_nothing_extra_and_does_not_rerun_the_quest() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	_send_to_succeed(dispatch, "rats", gold, 1_000)
	dispatch.checkpoint(1_100, gold)
	assert_eq(gold.amount, 50)

	dispatch.checkpoint(990, gold)
	assert_eq(gold.amount, 50)
	assert_true(dispatch.outings.is_empty())
	assert_eq(dispatch.refusal(), "")
	assert_false(dispatch.returned_since_checkpoint(990))
	dispatch.checkpoint(1_100, gold)
	dispatch.checkpoint(2_000, gold)
	assert_eq(gold.amount, 50)


func test_a_clock_set_back_after_a_failure_never_rerolls_repays_or_heals_early() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_700, gold)
	assert_eq(gold.amount, 125)
	assert_eq(dispatch.injury_left("tobin", 1_700), 200)

	dispatch.checkpoint(500, gold)
	assert_eq(dispatch.injury_left("tobin", 500), 200)
	assert_eq(dispatch.status("tobin", 500), "Injured · 3:20")
	assert_false(dispatch.can_go("tobin", 500))
	dispatch.checkpoint(1_000, gold)
	dispatch.checkpoint(1_600, gold)
	assert_eq(gold.amount, 125)
	assert_eq(dispatch.last_return, "Goblin camp: failed · +125 gold · Tobin injured")
	assert_eq(dispatch.injury_left("tobin", 1_899), 1)
	assert_true(dispatch.can_go("tobin", 1_900))


func test_a_clock_set_back_mid_quest_adds_no_time_to_the_countdown() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	_send_to_succeed(dispatch, "moonherbs", gold, 1_000)
	dispatch.checkpoint(1_100, gold)
	dispatch.checkpoint(500, gold)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 500), 80)
	dispatch.checkpoint(1_180, gold)
	assert_eq(gold.amount, 150)


func test_with_the_party_home_time_passing_adds_no_gold() -> void:
	var gold := Gold.new(70)
	var dispatch := Dispatch.new(1_000)
	dispatch.checkpoint(1_000 + 3_600, gold)
	assert_eq(gold.amount, 70)
	assert_true(_send_to_succeed(dispatch, "rats", gold, 4_600))
	dispatch.checkpoint(4_660 + 3_600, gold)
	assert_eq(gold.amount, 120)


func test_a_quest_in_progress_survives_save_and_load() -> void:
	var gold := Gold.new(30)
	var dispatch := Dispatch.new(1_000)
	_send_to_succeed(dispatch, "moonherbs", gold, 1_000)
	dispatch.checkpoint(1_050, gold)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded.outings[0]["quest"], "moonherbs")
	assert_eq(loaded.seconds_left(loaded.outings[0], 1_050), 130)
	assert_eq(loaded.refusal(), "Party is out")
	loaded.checkpoint(1_179, loaded_gold)
	assert_eq(loaded_gold.amount, 30)
	loaded.checkpoint(1_180, loaded_gold)
	assert_eq(loaded_gold.amount, 180)


func test_a_party_out_and_an_injury_survive_save_and_load_with_the_same_outcome() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_700, gold)
	var party: PackedStringArray = ["bram", "maren"]
	var roll_seed := _seed("moonherbs", party, false)
	dispatch.send("moonherbs", party, roll_seed, gold, 1_750)
	dispatch.checkpoint(1_760, gold)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(_statuses(loaded, 1_760), ["On quest: Gather moonherbs", "Resting", "Injured · 2:20", "On quest: Gather moonherbs"])
	assert_eq(loaded.last_return, "Goblin camp: failed · +125 gold · Tobin injured")
	assert_eq(loaded.outings[0]["seed"], roll_seed)
	assert_eq(loaded.seconds_left(loaded.outings[0], 1_760), 170)
	loaded.checkpoint(1_930, loaded_gold)
	dispatch.checkpoint(1_930, gold)
	assert_eq(loaded_gold.amount, 125 + 37)
	assert_eq(loaded.last_return, dispatch.last_return)
	assert_eq(_statuses(loaded, 1_930), _statuses(dispatch, 1_930))


func test_an_m2_save_loads_with_its_gold_kept_and_the_party_home() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 300)
	file.set_value("gold", "saved_at", 1_000)
	Hall.new(1_000).write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_true(dispatch.outings.is_empty())
	assert_eq(dispatch.refusal(), "")
	dispatch.checkpoint(2_000, gold)
	assert_eq(gold.amount, 300)
	assert_true(_send_to_succeed(dispatch, "rats", gold, 2_000))


func _m3_save(quest: String) -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 20)
	file.set_value("dispatch", "quest", quest)
	file.set_value("dispatch", "quest_since", 1_000)
	file.set_value("dispatch", "checked_at", 1_010)
	assert_eq(file.save(SAVE_PATH), OK)


func test_an_m3_save_with_the_party_out_pays_that_quest_in_full_on_return_with_no_injuries() -> void:
	_m3_save("goblins")
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_eq(dispatch.refusal(), "Party is out")
	assert_eq(_statuses(dispatch, 1_100), ["Resting", "Resting", "Resting", "Resting"])
	dispatch.checkpoint(1_599, gold)
	assert_eq(gold.amount, 20)
	dispatch.checkpoint(1_600, gold)
	assert_eq(gold.amount, 520)
	assert_eq(dispatch.last_return, "Goblin camp: success · +500 gold")
	assert_eq(_statuses(dispatch, 1_600), ["Resting", "Resting", "Resting", "Resting"])
	assert_eq(dispatch.refusal(), "")


func test_an_m3_save_with_the_party_home_loads_with_all_four_resting() -> void:
	_m3_save("")
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_true(dispatch.outings.is_empty())
	assert_eq(_statuses(dispatch, 2_000), ["Resting", "Resting", "Resting", "Resting"])
	assert_eq(gold.amount, 20)
	assert_true(_send_to_succeed(dispatch, "rats", gold, 2_000))


func test_a_save_naming_an_unknown_quest_loads_with_nobody_out() -> void:
	_m3_save("dragons")
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_true(dispatch.outings.is_empty())
	assert_eq(dispatch.refusal(), "")
	dispatch.checkpoint(99_000, gold)
	assert_eq(gold.amount, 20)
	assert_eq(dispatch.last_return, "")
	assert_true(_send_to_succeed(dispatch, "rats", gold, 99_000))


## A hall at 1_000 converting `back_left` into `type`: restored at 1_120, converted at 1_180.
func _hall_converting(type: String, gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_true(hall.convert_room("back_left", type, gold, 1_120))
	return hall


func test_a_finished_quest_hall_lets_a_second_quest_go_out_and_a_third_is_refused() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("quest_hall", gold)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("goblins", ["tobin"], 1, gold, 1_150, hall.rooms_done("quest_hall", 1_150)))
	# Until the Quest hall is finished it does nothing.
	assert_eq(dispatch.refusal("rats", hall.rooms_done("quest_hall", 1_179)), "Party is out")
	assert_false(dispatch.send("rats", ["bram"], 1, gold, 1_179, hall.rooms_done("quest_hall", 1_179)))

	var quest_halls := hall.rooms_done("quest_hall", 1_180)
	assert_eq(quest_halls, 1)
	assert_eq(dispatch.refusal("rats", quest_halls), "")
	assert_true(dispatch.send("rats", ["bram"], 1, gold, 1_180, quest_halls))
	assert_eq(dispatch.refusal("moonherbs", quest_halls), "2 parties out")
	assert_eq(dispatch.party_refusal(["ilse"], 1_180, "moonherbs", quest_halls), "2 parties out")
	assert_false(dispatch.send("moonherbs", ["ilse"], 1, gold, 1_180, quest_halls))
	assert_eq(dispatch.outings.size(), 2)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_200), 550)
	assert_eq(dispatch.seconds_left(dispatch.outings[1], 1_200), 40)
	dispatch.checkpoint(1_240, gold)
	assert_eq(dispatch.refusal("moonherbs", quest_halls), "")


func test_a_quest_already_out_cannot_be_sent_again_even_with_room_for_another() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("moonherbs", ["bram"], 1, gold, 1_000, 1))
	assert_eq(dispatch.refusal("moonherbs", 1), "Already out")
	assert_eq(dispatch.party_refusal(["ilse"], 1_010, "moonherbs", 1), "Already out")
	assert_false(dispatch.send("moonherbs", ["ilse"], 1, gold, 1_010, 1))
	assert_eq(dispatch.refusal("rats", 1), "")
	assert_eq(dispatch.outings.size(), 1)
	dispatch.checkpoint(1_180, gold)
	assert_eq(dispatch.refusal("moonherbs", 1), "")


func test_an_injury_lasts_150_seconds_with_an_infirmary_finished_before_the_return() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	var dispatch := Dispatch.new(1_000)
	# Returns at 1_600; the Infirmary finished at 1_180, while the app was away.
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_700, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_700), 50)
	assert_eq(dispatch.status("tobin", 1_700), "Injured · 0:50")
	assert_true(dispatch.can_go("tobin", 1_750))


func test_an_injury_lasts_300_seconds_when_the_infirmary_finishes_after_the_return() -> void:
	var gold := Gold.new(1_000)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_200)
	hall.convert_room("back_left", "infirmary", gold, 1_550)
	# Away until 1_700: the party returned at 1_600, the Infirmary finished at 1_610, and the hall
	# took its checkpoint first.
	hall.checkpoint(1_700)
	dispatch.checkpoint(1_700, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_700), 200)
	dispatch.checkpoint(1_800, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_899), 1)
	assert_true(dispatch.can_go("tobin", 1_900))


func test_two_infirmaries_still_heal_in_150_seconds() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	hall.restore("back_right", gold, 1_180)
	hall.convert_room("back_right", "infirmary", gold, 1_300)
	hall.checkpoint(1_360)
	assert_eq(hall.rooms_done("infirmary", 1_360), 2)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_400)
	dispatch.checkpoint(2_000, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 2_000), 150)


func test_two_parties_back_in_the_same_checkpoint_come_home_in_the_order_they_returned() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["bram", "ilse"], _seed("goblins", ["bram", "ilse"], true), gold, 1_000, 1)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), gold, 1_100, 1)
	# Rats came back at 1_160, the goblin camp at 1_600, though the goblin camp left first.
	dispatch.checkpoint(2_000, gold)
	assert_true(dispatch.outings.is_empty())
	assert_eq(gold.amount, 500 + 12)
	assert_eq(dispatch.last_return, "Goblin camp: success · +500 gold")


func test_a_clock_set_back_never_changes_an_injury_already_decided() -> void:
	var gold := Gold.new(1_000)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_200)
	hall.convert_room("back_left", "infirmary", gold, 1_550)
	hall.checkpoint(1_650)
	dispatch.checkpoint(1_650, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_650), 250)
	assert_eq(gold.amount, 1_000 - 120 - 60 + 125)

	# Set back to before the return and the Infirmary: nothing is re-decided, repaid or re-charged.
	hall.checkpoint(1_500)
	dispatch.checkpoint(1_500, gold, hall.first_done_at("infirmary"))
	assert_eq(hall.state("back_left", 1_500), Hall.State.CONVERTED)
	assert_eq(dispatch.injury_left("tobin", 1_500), 250)
	assert_true(dispatch.outings.is_empty())
	dispatch.checkpoint(1_700, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_899), 1)
	assert_eq(gold.amount, 1_000 - 120 - 60 + 125)
