extends GutTest

const SAVE_PATH: String = "user://test_dispatch_save.cfg"
const PARTY: PackedStringArray = ["bram", "ilse", "tobin"]
const EVERYONE: Array[String] = ["bram", "ilse", "tobin", "maren"]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A seed with which `party` on `quest` succeeds, or fails when `success` is false.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var chance := Dispatch.new(0).success_chance(quest, party)
	for roll_seed: int in 10_000:
		if Outcome.roll(roll_seed, chance, Dispatch.QUESTS[quest]["difficulty"], party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


## Makes `adventurer`, out on a quest, have left with 1 health, so coming home leaves them under a
## quarter of their health, whatever the damage.
func _worn_out(dispatch: Dispatch, adventurer: String) -> void:
	for outing: Dictionary in dispatch.outings:
		if adventurer in outing["party"]:
			outing["health"][adventurer] = 1


## Sends PARTY on `quest` with a seed it succeeds with.
func _send_to_succeed(dispatch: Dispatch, quest: String, gold: Gold, now: int) -> bool:
	return dispatch.send(quest, PARTY, _seed(quest, PARTY, true), gold, now)


func _debriefed_quests(dispatch: Dispatch) -> Array[String]:
	var quests: Array[String] = []
	for debrief: Dictionary in dispatch.debriefs:
		quests.append(debrief["quest"])
	return quests


func _statuses(dispatch: Dispatch, now: int) -> Array[String]:
	var statuses: Array[String] = []
	for adventurer: String in EVERYONE:
		statuses.append(dispatch.status(adventurer, now))
	return statuses


func test_the_pool_has_six_quests_each_with_its_difficulty_paying_its_gold_after_its_duration() -> void:
	var expected := {
		"rats": ["Rats in the cellar", 60, 50, 3],
		"moonherbs": ["Gather moonherbs", 180, 150, 7],
		"goblins": ["Goblin camp", 600, 500, 12],
		"letters": ["Carry letters to the abbey", 120, 100, 5],
		"wolves": ["Wolves at the mill", 300, 250, 9],
		"crypt": ["Clear the old crypt", 480, 400, 11],
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
		assert_eq([info["name"], info["class"], info["rank"], Dispatch.new(1_000).adventurers.power(adventurer)], expected[adventurer])
	assert_eq(_statuses(Dispatch.new(1_000), 1_000), ["Resting", "Resting", "Resting", "Resting"])


func test_the_success_chance_is_from_the_picked_party_against_the_quest() -> void:
	# Power 7 against 7, less 15 for Attrition: Tobin covers Navigation.
	assert_eq(Dispatch.new(1_000).success_chance("moonherbs", ["bram", "tobin"]), 35)
	# Power 8 against 7, less 15 each for Navigation and Attrition.
	assert_eq(Dispatch.new(1_000).success_chance("moonherbs", ["bram", "ilse"]), 30)
	# Power 8 against 12 (Maren is a Healer), less 15 each for Traps and Navigation: down to 5.
	assert_eq(Dispatch.new(1_000).success_chance("goblins", ["bram", "ilse", "maren"]), 5)
	# Power 3 against 3, less 15 for Brute force.
	assert_eq(Dispatch.new(1_000).success_chance("rats", ["tobin"]), 35)


func test_four_one_person_parties_can_be_out() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("moonherbs", ["tobin"], 0, gold, 1_000))
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_030), 150)
	assert_eq(dispatch.party_refusal("rats", ["maren"], 1_030), "")
	assert_true(dispatch.send("rats", ["maren"], 0, gold, 1_030))
	assert_true(dispatch.send("goblins", ["bram"], 0, gold, 1_040))
	assert_true(dispatch.send("crypt", ["ilse"], 0, gold, 1_050))
	assert_eq(dispatch.outings.size(), 4)
	assert_eq(_statuses(dispatch, 1_050), ["On quest: Goblin camp", "On quest: Clear the old crypt", "On quest: Gather moonherbs", "On quest: Rats in the cellar"])
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_050), 130)
	# With everyone out, nobody is left to send.
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 1_050), "Tobin can't go")


func test_the_party_shows_as_on_its_quest_and_the_others_as_resting() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("goblins", ["ilse", "maren"], 7, gold, 1_000))
	assert_eq(_statuses(dispatch, 1_100), ["Resting", "On quest: Goblin camp", "Resting", "On quest: Goblin camp"])


func test_a_party_is_one_to_four_adventurers_who_are_home_and_well() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_eq(dispatch.party_refusal("rats", [], 1_000), "Pick at least one adventurer")
	assert_false(dispatch.send("rats", [], 1, gold, 1_000))
	assert_true(dispatch.outings.is_empty())
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 1_000), "")
	assert_eq(dispatch.party_refusal("rats", ["bram", "ilse", "tobin", "maren"], 1_000), "")
	assert_true(dispatch.send("rats", ["bram", "ilse", "tobin", "maren"], 1, gold, 1_000))
	assert_eq(_statuses(dispatch, 1_000), ["On quest: Rats in the cellar", "On quest: Rats in the cellar", "On quest: Rats in the cellar", "On quest: Rats in the cellar"])


func test_party_of_five_is_refused() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	var five: PackedStringArray = ["bram", "ilse", "tobin", "maren", "bram"]
	assert_eq(dispatch.party_refusal("rats", five, 1_000), "At most 4 in a party")
	assert_false(dispatch.send("rats", five, 1, gold, 1_000))
	assert_true(dispatch.outings.is_empty())


func test_an_injured_adventurer_cannot_be_picked_until_recovered() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_600, gold)
	assert_false(dispatch.can_go("tobin", 1_600))
	assert_true(dispatch.can_go("bram", 1_600))
	assert_eq(dispatch.party_refusal("rats", ["bram", "tobin"], 1_600), "Tobin can't go")
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
	assert_eq(dispatch.debriefs, [{"quest": "rats", "returned_at": 1_060, "success": true, "party": PackedStringArray(["bram", "maren"]), "damage": {"bram": 0, "maren": 0}, "injured": {}, "gold": 50, "xp": 4, "revealed": PackedStringArray(), "loot": PackedStringArray(), "lost": PackedStringArray()}])
	assert_eq(_statuses(dispatch, 1_060), ["Resting", "Resting", "Resting", "Resting"])


func test_a_failure_pays_a_quarter_rounded_down_and_injures_a_worn_out_member_for_five_minutes_from_return() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	var injured := "tobin"
	dispatch.send("moonherbs", PARTY, _seed("moonherbs", PARTY, false), gold, 1_000)
	_worn_out(dispatch, injured)
	# Returns at 1_180; the checkpoint comes 100 s later, as on opening the app.
	dispatch.checkpoint(1_280, gold)
	assert_eq(gold.amount, 37)
	var hurt: Array[String] = []
	for adventurer: String in EVERYONE:
		if not dispatch.can_go(adventurer, 1_280):
			hurt.append(adventurer)
	assert_eq(hurt, [injured])
	assert_eq(dispatch.injury_left(injured, 1_280), 200)
	assert_eq(dispatch.injury_seconds(injured), 300)
	assert_eq(dispatch.status(injured, 1_280), "Injured · 3:20")
	assert_eq(dispatch.debriefs[0]["injured"], {injured: 300})
	assert_eq(dispatch.debriefs[0]["gold"], 37)
	assert_eq(dispatch.injury_left(injured, 1_479), 1)
	assert_eq(dispatch.status(injured, 1_480), "Resting")


func test_a_failed_goblin_camp_pays_125_and_names_the_injured() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_600, gold)
	assert_eq(gold.amount, 125)
	assert_eq(dispatch.debriefs[0]["injured"], {"tobin": 300})
	assert_eq(dispatch.debriefs[0]["gold"], 125)


func test_the_outcome_is_not_revealed_before_the_party_returns() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_599, gold)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.status("tobin", 1_599), "On quest: Goblin camp")
	dispatch.checkpoint(1_600, gold)
	assert_eq(dispatch.debriefs.size(), 1)


func test_the_reward_lands_exactly_when_the_quest_ends_and_not_a_second_before() -> void:
	var gold := Gold.new(10)
	var dispatch := Dispatch.new(1_000)
	_send_to_succeed(dispatch, "rats", gold, 1_000)
	dispatch.checkpoint(1_059, gold)
	assert_eq(gold.amount, 10)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_059), 1)
	assert_eq(dispatch.outings.size(), 1)
	dispatch.checkpoint(1_060, gold)
	assert_eq(gold.amount, 60)
	assert_true(dispatch.outings.is_empty())


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
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_010, gold)
	dispatch.checkpoint(1_000 + 600 + 299, gold)
	assert_eq(dispatch.status("tobin", 1_899), "Injured · 0:01")
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
	assert_true(dispatch.can_go("bram", 990))
	assert_false(dispatch.returned_since_checkpoint(990))
	dispatch.checkpoint(1_100, gold)
	dispatch.checkpoint(2_000, gold)
	assert_eq(gold.amount, 50)


func test_a_clock_set_back_after_a_failure_never_rerolls_repays_or_heals_early() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
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
	assert_eq(dispatch.debriefs.size(), 1)
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
	assert_eq(loaded.outings.size(), 1)
	loaded.checkpoint(1_179, loaded_gold)
	assert_eq(loaded_gold.amount, 30)
	loaded.checkpoint(1_180, loaded_gold)
	assert_eq(loaded_gold.amount, 180)


func test_a_party_out_and_an_injury_survive_save_and_load_with_the_same_outcome() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
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
	assert_eq(loaded.debriefs, [{"quest": "goblins", "returned_at": 1_600, "success": false, "party": PackedStringArray(["tobin"]), "damage": {"tobin": 11}, "injured": {"tobin": 300}, "gold": 125, "xp": 20, "revealed": PackedStringArray(["Navigation"]), "loot": PackedStringArray(), "lost": PackedStringArray()}])
	assert_eq(loaded.outings[0]["seed"], roll_seed)
	assert_eq(loaded.seconds_left(loaded.outings[0], 1_760), 170)
	loaded.checkpoint(1_930, loaded_gold)
	dispatch.checkpoint(1_930, gold)
	assert_eq(loaded_gold.amount, 125 + 37)
	assert_eq(loaded.debriefs, dispatch.debriefs)
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
	assert_true(dispatch.can_go("bram", 2_000))
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
	assert_eq(dispatch.outings.size(), 1)
	assert_eq(_statuses(dispatch, 1_100), ["Resting", "Resting", "Resting", "Resting"])
	dispatch.checkpoint(1_599, gold)
	assert_eq(gold.amount, 20)
	dispatch.checkpoint(1_600, gold)
	assert_eq(gold.amount, 520)
	assert_eq(dispatch.debriefs, [{"quest": "goblins", "returned_at": 1_600, "success": true, "party": PackedStringArray(), "damage": {}, "injured": {}, "gold": 500, "xp": 40, "revealed": PackedStringArray(["Navigation"]), "loot": PackedStringArray(), "lost": PackedStringArray()}])
	assert_eq(_statuses(dispatch, 1_600), ["Resting", "Resting", "Resting", "Resting"])
	assert_true(dispatch.outings.is_empty())


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
	assert_true(dispatch.can_go("bram", 2_000))
	dispatch.checkpoint(99_000, gold)
	assert_eq(gold.amount, 20)
	assert_true(dispatch.debriefs.is_empty())
	assert_true(_send_to_succeed(dispatch, "rats", gold, 99_000))


## A hall at 1_000 converting `back_left` into `type`: restored at 1_120, converted at 1_180.
func _hall_converting(type: String, gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_true(hall.convert_room("back_left", type, gold, 1_120))
	return hall


func test_save_from_previous_build_loads() -> void:
	var start := 20_001 * 86_400
	var gold := Gold.new(1_000)
	var hall := Hall.new(start)
	assert_true(hall.restore("back_left", gold, start))
	assert_true(hall.convert_room("back_left", "quest_hall", gold, start + 120))
	hall.checkpoint(start + 180)
	var dispatch := Dispatch.new(start)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), gold, start + 200)
	_worn_out(dispatch, "tobin")
	dispatch.send("goblins", ["bram", "ilse"], 1, gold, start + 300)
	dispatch.checkpoint(start + 400, gold)
	# The previous build wrote these three sections, and no board.
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	var loaded_hall := Hall.load_or_start(SAVE_PATH, start + 500)
	var loaded := Dispatch.load_or_start(SAVE_PATH, start + 500)
	var board := Board.load_or_start(SAVE_PATH)
	assert_eq(loaded_gold.amount, 1_000 - 120 - 60 + 12)
	assert_eq(loaded_hall.room_type("back_left"), "quest_hall")
	assert_eq(loaded_hall.rooms_done("quest_hall", start + 500), 1)
	assert_eq(_statuses(loaded, start + 500), ["On quest: Goblin camp", "On quest: Goblin camp", "Injured · 1:00", "Resting"])
	assert_eq(loaded.seconds_left(loaded.outings[0], start + 500), 400)
	# Four slots with the Quest hall, filled with any quest but goblins, still out.
	board.refill(loaded, start + 500, PackedInt64Array([start + 180]))
	assert_eq(board.slots, PackedStringArray(["wolves", "letters", "crypt", "rats"]))


func test_an_injury_lasts_150_seconds_with_an_infirmary_finished_before_the_return() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	var dispatch := Dispatch.new(1_000)
	# Returns at 1_600; the Infirmary finished at 1_180, while the app was away.
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_700, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_700), 50)
	assert_eq(dispatch.injury_seconds("tobin"), 150)
	assert_eq(dispatch.status("tobin", 1_700), "Injured · 0:50")
	assert_true(dispatch.can_go("tobin", 1_750))


func test_an_injury_lasts_300_seconds_when_the_infirmary_finishes_after_the_return() -> void:
	var gold := Gold.new(1_000)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
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
	assert_eq(dispatch.injury_seconds("tobin"), 300)
	assert_eq(dispatch.injury_left("tobin", 1_899), 1)
	assert_true(dispatch.can_go("tobin", 1_900))


func test_an_injury_keeps_its_length_through_save_and_load() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.send("rats", ["bram"], _seed("rats", ["bram"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
	_worn_out(dispatch, "bram")
	# Bram returned at 1_060, before the Infirmary; Tobin at 1_600, after it.
	dispatch.checkpoint(1_100, gold, hall.first_done_at("infirmary"))
	dispatch.checkpoint(1_700, gold, hall.first_done_at("infirmary"))
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_700)
	assert_eq(loaded.injury_seconds("tobin"), 150)
	assert_eq(loaded.injury_seconds("bram"), 300)
	assert_eq(loaded.injury_left("tobin", 1_700), 50)


func test_an_injury_saved_before_lengths_were_kept_loads_as_the_long_injury() -> void:
	var file := ConfigFile.new()
	file.set_value("dispatch", "outings", [])
	file.set_value("dispatch", "injured_until", {"tobin": 1_750})
	file.set_value("dispatch", "checked_at", 1_700)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_700)
	assert_eq(loaded.injury_left("tobin", 1_700), 50)
	assert_eq(loaded.injury_seconds("tobin"), 300)


func test_two_infirmaries_still_heal_in_150_seconds() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	hall.restore("back_right", gold, 1_180)
	hall.convert_room("back_right", "infirmary", gold, 1_300)
	hall.checkpoint(1_360)
	assert_eq(hall.rooms_done("infirmary", 1_360), 2)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_400)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(2_000, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 2_000), 150)


func test_two_parties_back_in_the_same_checkpoint_come_home_in_the_order_they_returned() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["bram", "ilse"], _seed("goblins", ["bram", "ilse"], true), gold, 1_000)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), gold, 1_100)
	# Rats came back at 1_160, the goblin camp at 1_600, though the goblin camp left first.
	dispatch.checkpoint(2_000, gold)
	assert_true(dispatch.outings.is_empty())
	assert_eq(gold.amount, 500 + 12)
	assert_eq(_debriefed_quests(dispatch), ["rats", "goblins"])


func test_a_clock_set_back_never_changes_an_injury_already_decided() -> void:
	var gold := Gold.new(1_000)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
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


var rats_debrief: Dictionary = {"quest": "rats", "returned_at": 1_160, "success": false, "party": PackedStringArray(["tobin"]), "damage": {"tobin": 1}, "injured": {}, "gold": 12, "xp": 2, "revealed": PackedStringArray(), "loot": PackedStringArray(), "lost": PackedStringArray()}
var goblins_debrief: Dictionary = {"quest": "goblins", "returned_at": 1_600, "success": true, "party": PackedStringArray(["bram", "ilse"]), "damage": {"bram": 6, "ilse": 6}, "injured": {}, "gold": 500, "xp": 40, "revealed": PackedStringArray(["Navigation"]), "loot": PackedStringArray(), "lost": PackedStringArray()}


## Goblin camp succeeds for Bram and Ilse, sent at 1_000 (back at 1_600); Rats in the cellar
## fails for Tobin, sent at 1_100 (back at 1_160). Brought home at 1_200 and 2_000.
func _two_returns(gold: Gold) -> Dispatch:
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["bram", "ilse"], _seed("goblins", ["bram", "ilse"], true), gold, 1_000)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), gold, 1_100)
	dispatch.checkpoint(1_200, gold)
	dispatch.checkpoint(2_000, gold)
	return dispatch


func test_a_returned_party_adds_a_debrief_with_its_quest_result_party_injured_member_and_gold() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("moonherbs", PARTY, _seed("moonherbs", PARTY, false), gold, 1_100)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_279, gold, hall.first_done_at("infirmary"))
	assert_true(dispatch.debriefs.is_empty())
	dispatch.checkpoint(1_400, gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.debriefs, [{"quest": "moonherbs", "returned_at": 1_280, "success": false, "party": PARTY, "damage": {"bram": 6, "ilse": 6, "tobin": 6}, "injured": {"tobin": 150}, "gold": 37, "xp": 6, "revealed": PackedStringArray(["Attrition"]), "loot": PackedStringArray(), "lost": PackedStringArray()}])


func test_two_returns_give_two_debriefs_in_the_order_they_came_back() -> void:
	var gold := Gold.new(0)
	var dispatch := _two_returns(gold)
	assert_eq(dispatch.debriefs, [rats_debrief, goblins_debrief])


func test_reading_a_debrief_files_only_that_one_and_changes_nothing_else() -> void:
	var gold := Gold.new(0)
	var dispatch := _two_returns(gold)
	assert_eq(gold.amount, 512)
	assert_eq(dispatch.injury_left("tobin", 2_000), 0)
	dispatch.read_debrief(0)
	assert_eq(dispatch.debriefs, [goblins_debrief])
	assert_eq(gold.amount, 512)
	assert_eq(_statuses(dispatch, 2_000), ["Resting", "Resting", "Resting", "Resting"])
	dispatch.checkpoint(2_100, gold)
	assert_eq(gold.amount, 512)
	dispatch.read_debrief(0)
	assert_true(dispatch.debriefs.is_empty())


func test_reading_a_debrief_leaves_an_injury_running() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), gold, 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_100, gold)
	assert_eq(gold.amount, 12)
	dispatch.read_debrief(0)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 12)
	assert_eq(dispatch.status("tobin", 1_100), "Injured · 4:20")


func test_debriefs_survive_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := _two_returns(gold)
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_eq(loaded.debriefs, [rats_debrief, goblins_debrief])
	loaded.read_debrief(1)
	loaded.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	assert_eq(Dispatch.load_or_start(SAVE_PATH, 2_000).debriefs, [rats_debrief])


func test_a_debrief_says_how_many_whole_minutes_ago_the_party_came_back() -> void:
	var gold := Gold.new(0)
	var dispatch := _two_returns(gold)
	assert_eq(dispatch.back_label(goblins_debrief, 2_000), "Back 6 min ago")
	assert_eq(dispatch.back_label(rats_debrief, 2_000), "Back 14 min ago")
	assert_eq(dispatch.back_label(goblins_debrief, 2_259), "Back 10 min ago")
	assert_eq(dispatch.back_label(goblins_debrief, 2_260), "Back 11 min ago")
	# A clock set back never makes a return more recent.
	assert_eq(dispatch.back_label(goblins_debrief, 1_000), "Back 6 min ago")
	var fresh := Dispatch.new(1_000)
	_send_to_succeed(fresh, "rats", gold, 1_000)
	fresh.checkpoint(1_060, gold)
	assert_eq(fresh.back_label(fresh.debriefs[0], 1_119), "Back just now")
	assert_eq(fresh.back_label(fresh.debriefs[0], 1_120), "Back 1 min ago")


func test_a_save_from_before_debriefs_loads_with_none_and_nothing_lost() -> void:
	# What the build before debriefs wrote: the latest return in words, and no debriefs.
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 640)
	file.set_value("dispatch", "outings", [{"quest": "rats", "since": 1_000, "party": PackedStringArray(["bram"]), "seed": _seed("rats", ["bram"], true)}])
	file.set_value("dispatch", "injured_until", {"tobin": 1_200})
	file.set_value("dispatch", "injury_lengths", {"tobin": 150})
	file.set_value("dispatch", "last_return", "Goblin camp: failed · +125 gold · Tobin injured")
	file.set_value("dispatch", "checked_at", 1_050)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_050)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 640)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_050), 10)
	assert_eq(dispatch.injury_left("tobin", 1_050), 150)
	assert_eq(dispatch.injury_seconds("tobin"), 150)
	dispatch.checkpoint(1_060, gold)
	assert_eq(gold.amount, 690)
	assert_eq(dispatch.debriefs, [{"quest": "rats", "returned_at": 1_060, "success": true, "party": PackedStringArray(["bram"]), "damage": {"bram": 1}, "injured": {}, "gold": 50, "xp": 4, "revealed": PackedStringArray(), "loot": PackedStringArray(), "lost": PackedStringArray()}])


func _xp(dispatch: Dispatch) -> Array[int]:
	var xp: Array[int] = []
	for adventurer: String in EVERYONE:
		xp.append(dispatch.adventurers.xp[adventurer])
	return xp


func test_every_member_of_a_returning_party_gains_xp_and_half_as_much_on_a_failure() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("moonherbs", ["bram", "maren"], _seed("moonherbs", ["bram", "maren"], true), gold, 1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), gold, 1_000)
	dispatch.checkpoint(1_179, gold)
	assert_eq(_xp(dispatch), [0, 0, 0, 0])
	# 180 s of moonherbs gives 12 XP; 600 s of goblin camp 40, halved for failing.
	dispatch.checkpoint(1_180, gold)
	assert_eq(_xp(dispatch), [12, 0, 0, 12])
	assert_eq(dispatch.debriefs[0]["xp"], 12)
	dispatch.checkpoint(1_600, gold)
	assert_eq(_xp(dispatch), [12, 0, 20, 12])
	assert_eq(dispatch.debriefs[1]["xp"], 20)
	dispatch.checkpoint(5_000, gold)
	assert_eq(_xp(dispatch), [12, 0, 20, 12])


func test_xp_banks_past_several_level_ups_and_an_adventurer_with_one_waiting_can_still_be_sent() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	var party: PackedStringArray = ["bram", "ilse"]
	var now := 1_000
	for quest: int in 3:
		assert_true(dispatch.send("goblins", party, _seed("goblins", party, true), gold, now))
		now += 600
		dispatch.checkpoint(now, gold)
	# 40 XP a goblin camp: enough for level 2 (40) and level 3 (80).
	assert_eq(dispatch.adventurers.xp["bram"], 120)
	assert_true(dispatch.adventurers.level_up_ready("bram"))
	assert_true(dispatch.can_go("bram", now))
	assert_eq(dispatch.adventurers.level_up("bram").size(), 4)
	assert_eq(dispatch.adventurers.xp["bram"], 80)
	assert_true(dispatch.adventurers.level_up_ready("bram"))
	dispatch.adventurers.level_up("bram")
	assert_eq(dispatch.adventurers.levels["bram"], 3)
	assert_eq(dispatch.adventurers.xp["bram"], 0)
	assert_false(dispatch.adventurers.level_up_ready("bram"))
	assert_eq(dispatch.adventurers.levels["ilse"], 1)


func test_a_level_up_while_out_never_changes_how_the_quest_ends() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	var grown := Dispatch.new(1_000)
	for each: Dispatch in [dispatch, grown]:
		each.adventurers.gain_xp("tobin", 1_000_000)
	for level: int in 10:
		grown.adventurers.level_up("tobin")
	var chance := dispatch.success_chance("goblins", ["tobin"])
	var grown_chance := grown.success_chance("goblins", ["tobin"])
	assert_gt(grown_chance, chance)
	var roll_seed := -1
	for candidate: int in 10_000:
		if not Outcome.roll(candidate, chance, 12, ["tobin"]).success and Outcome.roll(candidate, grown_chance, 12, ["tobin"]).success:
			roll_seed = candidate
			break
	assert_true(dispatch.send("goblins", ["tobin"], roll_seed, gold, 1_000))
	for level: int in 10:
		dispatch.adventurers.level_up("tobin")
	assert_eq(dispatch.success_chance("goblins", ["tobin"]), grown_chance)
	dispatch.checkpoint(1_600, gold)
	assert_false(dispatch.debriefs[0]["success"])


func _grow_grit(dispatch: Dispatch, adventurer: String) -> void:
	dispatch.adventurers.gain_xp(adventurer, 1_000_000)
	var grit_gain := 0
	while grit_gain == 0:
		grit_gain = dispatch.adventurers.level_up(adventurer)["grit"]


func test_a_level_up_while_out_never_changes_the_health_a_member_comes_back_with_or_their_injury() -> void:
	for grow: bool in [false, true]:
		var gold := Gold.new(0)
		var dispatch := _tobin_hurt(gold)
		# Rats in the cellar succeeds with seed 7 and deals Tobin 1: back with 4 of the 16 he left
		# with, exactly a quarter.
		assert_true(dispatch.send("rats", ["tobin"], 7, gold, 1_600))
		assert_true(dispatch.send("rats", ["maren"], 7, gold, 1_600))
		if grow:
			_grow_grit(dispatch, "tobin")
			_grow_grit(dispatch, "maren")
			assert_gt(dispatch.adventurers.max_health("tobin"), 16)
			assert_gt(dispatch.adventurers.max_health("maren"), 20)
		assert_eq(dispatch.health("tobin", 1_630), 5, "grown %s" % grow)
		assert_eq(dispatch.health("maren", 1_630), 20, "grown %s" % grow)
		dispatch.checkpoint(1_660, gold)
		assert_eq(dispatch.health("tobin", 1_660), 4, "grown %s" % grow)
		for debrief: Dictionary in dispatch.debriefs:
			assert_true(debrief["injured"].is_empty(), "grown %s" % grow)
		assert_true(dispatch.can_go("tobin", 1_660))


func _healths(dispatch: Dispatch, now: int) -> Array[int]:
	var healths: Array[int] = []
	for adventurer: String in EVERYONE:
		healths.append(dispatch.health(adventurer, now))
	return healths


## Tobin, at 16 health, fails a goblin camp sent at 1_000 that deals him 11: back at 1_600 with 5.
func _tobin_hurt(gold: Gold, infirmary_from: int = -1) -> Dispatch:
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("goblins", ["tobin"], 0, gold, 1_000))
	dispatch.checkpoint(1_600, gold, infirmary_from)
	assert_eq(dispatch.debriefs[0]["damage"], {"tobin": 11})
	return dispatch


func test_a_new_guild_is_at_full_health_from_grit() -> void:
	var dispatch := Dispatch.new(1_000)
	assert_eq(_healths(dispatch, 1_000), [24, 20, 16, 20])
	for adventurer: String in EVERYONE:
		assert_eq(dispatch.seconds_to_full(adventurer, 1_000), 0)


func test_damage_heals_a_point_every_20_seconds_up_to_the_maximum() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	assert_eq(dispatch.health("tobin", 1_600), 5)
	assert_eq(dispatch.health("tobin", 1_619), 5)
	assert_eq(dispatch.health("tobin", 1_620), 6)
	assert_eq(dispatch.health("tobin", 1_800), 15)
	assert_eq(dispatch.seconds_to_full("tobin", 1_600), 220)
	assert_eq(dispatch.seconds_to_full("tobin", 1_700), 120)
	assert_eq(dispatch.health("tobin", 1_820), 16)
	assert_eq(dispatch.seconds_to_full("tobin", 1_820), 0)
	assert_eq(dispatch.health("tobin", 9_000), 16)
	assert_eq(dispatch.health("bram", 1_600), 24)


func test_an_infirmary_doubles_healing_from_the_moment_it_is_finished_not_before() -> void:
	var gold := Gold.new(1_000)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_200)
	hall.convert_room("back_left", "infirmary", gold, 1_550)
	assert_eq(hall.first_done_at("infirmary"), 1_610)
	var dispatch := _tobin_hurt(gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.seconds_to_full("tobin", 1_600), 115)
	assert_eq(dispatch.health("tobin", 1_610), 5)
	# 10 s slow, then 90 s at double speed: 190 s worth, where all-slow gives 10 and all-fast 15.
	assert_eq(dispatch.health("tobin", 1_700), 14)
	assert_eq(dispatch.health("tobin", 1_714), 15)
	assert_eq(dispatch.health("tobin", 1_715), 16)


func test_a_clock_set_back_never_lowers_health_or_undoes_healing() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	dispatch.checkpoint(1_700, gold)
	assert_eq(dispatch.health("tobin", 1_700), 10)
	dispatch.checkpoint(1_500, gold)
	assert_eq(dispatch.health("tobin", 1_500), 10)
	assert_eq(dispatch.seconds_to_full("tobin", 1_500), 120)
	dispatch.checkpoint(1_650, gold)
	assert_eq(dispatch.health("tobin", 1_650), 10)
	assert_eq(dispatch.health("tobin", 1_720), 11)


func test_a_hurt_adventurer_can_be_sent_heals_nothing_while_out_and_takes_damage_on_top() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	assert_true(dispatch.can_go("tobin", 1_600))
	assert_eq(dispatch.status("tobin", 1_600), "Resting")
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 1_600), "")
	# Rats in the cellar succeeds with seed 7 and deals him 1.
	assert_true(dispatch.send("rats", ["tobin"], 7, gold, 1_600))
	assert_eq(dispatch.health("tobin", 1_659), 5)
	# No countdown to full while out: nobody heals there.
	assert_eq(dispatch.seconds_to_full("tobin", 1_630), 0)
	dispatch.checkpoint(1_660, gold)
	assert_eq(dispatch.debriefs[1]["damage"], {"tobin": 1})
	assert_eq(dispatch.health("tobin", 1_660), 4)
	assert_eq(dispatch.health("tobin", 1_680), 5)
	# Exactly a quarter is not under it.
	assert_true(dispatch.debriefs[1]["injured"].is_empty())
	assert_true(dispatch.can_go("tobin", 1_660))


func test_damage_never_takes_health_below_1_and_under_a_quarter_injures_until_the_timer_ends() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	# 11 more damage from a second failed goblin camp, with 5 health left.
	assert_true(dispatch.send("goblins", ["tobin"], 0, gold, 1_600))
	dispatch.checkpoint(2_200, gold)
	assert_eq(dispatch.debriefs[1]["damage"], {"tobin": 11})
	assert_eq(dispatch.health("tobin", 2_200), 1)
	assert_eq(dispatch.debriefs[1]["injured"], {"tobin": 300})
	assert_eq(dispatch.status("tobin", 2_200), "Injured · 5:00")
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 2_499), "Tobin can't go")
	assert_false(dispatch.send("rats", ["tobin"], 7, gold, 2_499))
	assert_true(dispatch.can_go("tobin", 2_500))
	assert_eq(dispatch.health("tobin", 2_500), 16)


func test_a_success_can_still_leave_a_worn_out_member_injured_while_the_others_are_not() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("rats", ["tobin", "bram"], _seed("rats", ["tobin", "bram"], true), gold, 1_000))
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_060, gold)
	assert_eq(gold.amount, 50)
	assert_eq(dispatch.debriefs[0]["injured"], {"tobin": 300})
	assert_false(dispatch.can_go("tobin", 1_060))
	assert_true(dispatch.can_go("bram", 1_060))


func test_health_survives_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	dispatch.send("rats", ["tobin"], 7, gold, 1_610)
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_620)
	loaded.checkpoint(1_620, gold)
	assert_eq(loaded.health("tobin", 1_620), 5)
	loaded.checkpoint(1_670, gold)
	assert_eq(loaded.health("tobin", 1_670), 4)
	assert_eq(loaded.seconds_to_full("tobin", 1_670), 240)
	for now: int in [1_670, 1_700, 1_900]:
		loaded.checkpoint(now, gold)
		dispatch.checkpoint(now, gold)
		assert_eq(_healths(loaded, now), _healths(dispatch, now))
	assert_eq(loaded.health("tobin", 1_900), 15)


func test_a_save_from_before_health_loads_everyone_at_full_health_with_a_running_injury_kept() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", ["tobin"], 0, gold, 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_700, gold)
	assert_eq(dispatch.health("tobin", 1_700), 6)
	# The previous build wrote no health.
	var file := ConfigFile.new()
	dispatch.write(file)
	file.erase_section_key("dispatch", "wounds")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_700)
	assert_eq(_healths(loaded, 1_700), [24, 20, 16, 20])
	assert_eq(loaded.injury_left("tobin", 1_700), 200)
	assert_eq(loaded.status("tobin", 1_700), "Injured · 3:20")


## What a new guild doesn't know about each quest.
const STARTING_UNKNOWN: Dictionary = {
	"rats": [],
	"moonherbs": ["Attrition"],
	"goblins": ["Navigation"],
	"letters": ["Protect"],
	"wolves": ["Attrition"],
	"crypt": ["Attrition"],
}


func _unknown(dispatch: Dispatch) -> Dictionary:
	var unknown := {}
	for quest: String in Dispatch.QUESTS:
		unknown[quest] = Array(dispatch.unknown_challenges(quest))
	return unknown


func test_a_new_guild_knows_every_challenge_but_each_quests_last_and_all_of_rats() -> void:
	assert_eq(_unknown(Dispatch.new(1_000)), STARTING_UNKNOWN)


func test_a_healers_own_power_does_not_count_toward_the_party_but_their_cover_does() -> void:
	var dispatch := Dispatch.new(1_000)
	assert_eq(dispatch.party_power(["bram", "tobin"]), 7)
	assert_eq(dispatch.party_power(["bram", "maren"]), 4)
	assert_eq(dispatch.party_power(["maren"]), 0)
	# Rats has nothing for Maren to cover, so she adds nothing to Bram's 60.
	assert_eq(dispatch.success_chance("rats", ["bram"]), 60)
	assert_eq(dispatch.success_chance("rats", ["bram", "maren"]), 60)
	# On moonherbs she covers Attrition: 35 without her, 50 with.
	assert_eq(dispatch.success_chance("moonherbs", ["bram", "tobin"]), 35)
	assert_eq(dispatch.success_chance("moonherbs", ["bram", "tobin", "maren"]), 50)


func test_the_range_shown_holds_the_true_chance_and_the_true_chance_is_what_a_party_leaves_with() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	# Rats has nothing unknown: Bram's 60, widened by 10 either way.
	assert_eq(dispatch.chance_range("rats", ["bram"]), Vector2i(50, 70))
	# Moonherbs' Attrition is unknown: 50 by power, Navigation covered by Tobin.
	assert_eq(dispatch.chance_range("moonherbs", ["bram", "tobin"]), Vector2i(25, 60))
	# Whether Maren covers the unknown challenge changes the true chance, not the range.
	assert_eq(dispatch.chance_range("moonherbs", ["bram", "tobin", "maren"]), Vector2i(25, 60))
	assert_true(dispatch.send("moonherbs", ["bram", "tobin"], 1, gold, 1_000))
	assert_eq(dispatch.outings[0]["chance"], 35)


func test_a_party_back_from_a_quest_reveals_its_unknown_challenges_for_good() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("moonherbs", ["bram", "tobin"], 1, gold, 1_000))
	dispatch.checkpoint(1_179, gold)
	assert_eq(_unknown(dispatch), STARTING_UNKNOWN, "still out, nothing revealed")
	dispatch.checkpoint(1_180, gold)
	var known := STARTING_UNKNOWN.duplicate()
	known["moonherbs"] = []
	assert_eq(_unknown(dispatch), known)
	assert_eq(dispatch.debriefs[0]["revealed"], PackedStringArray(["Attrition"]))
	# Known to be uncovered, the range narrows to the true 35, widened by 10.
	assert_eq(dispatch.chance_range("moonherbs", ["bram", "tobin"]), Vector2i(25, 45))
	# A second trip has nothing left to reveal.
	assert_true(dispatch.send("moonherbs", ["bram", "tobin"], 1, gold, 1_200))
	dispatch.checkpoint(1_380, gold)
	assert_eq(dispatch.debriefs[1]["revealed"], PackedStringArray())
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_400)
	assert_eq(_unknown(loaded), known)
	assert_eq(loaded.debriefs, dispatch.debriefs)


func test_a_save_from_before_challenges_loads_with_the_starting_knowledge_and_nothing_else_lost() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("moonherbs", ["bram"], 1, gold, 1_000))
	dispatch.checkpoint(1_180, gold)
	assert_true(dispatch.send("goblins", ["tobin"], 1, gold, 1_200))
	# The previous build wrote nothing revealed, and debriefs without it.
	var file := ConfigFile.new()
	dispatch.write(file)
	var debriefs: Array = file.get_value("dispatch", "debriefs")
	debriefs[0].erase("revealed")
	file.set_value("dispatch", "debriefs", debriefs)
	file.erase_section_key("dispatch", "revealed")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_200)
	assert_eq(_unknown(loaded), STARTING_UNKNOWN)
	assert_eq(loaded.debriefs.size(), 1)
	assert_eq(loaded.debriefs[0]["gold"], dispatch.debriefs[0]["gold"])
	assert_eq(loaded.outings, dispatch.outings)
	assert_eq(loaded.adventurers.xp, dispatch.adventurers.xp)


func test_the_same_seed_sends_the_same_party_to_the_same_end() -> void:
	var party: PackedStringArray = ["bram", "tobin", "maren"]
	var successes := 0
	for roll_seed: int in 40:
		var ends: Array[Dictionary] = []
		for run: int in 2:
			var dispatch := Dispatch.new(1_000)
			assert_true(dispatch.send("moonherbs", party, roll_seed, Gold.new(0), 1_000))
			dispatch.checkpoint(1_180, Gold.new(0))
			ends.append(dispatch.debriefs[0])
		assert_eq(ends[1], ends[0])
		if ends[0]["success"]:
			successes += 1
	assert_between(successes, 1, 39, "both outcomes occur, so the seed decides")


## The first seed that brings back loot from a rank `rank` quest.
func _loot_seed(rank: String) -> int:
	for roll_seed: int in 1_000:
		if not Gear.loot(roll_seed, rank).is_empty():
			return roll_seed
	fail_test("no seed found")
	return -1


func test_a_returning_party_puts_its_loot_in_the_stash_and_its_debrief_lists_it() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	var roll_seed := _loot_seed("E")
	var item := Gear.loot(roll_seed, "E")
	assert_true(dispatch.send("goblins", ["bram", "ilse"], roll_seed, gold, 1_000))
	dispatch.checkpoint(1_599, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray())
	dispatch.checkpoint(1_600, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray([item]))
	assert_eq(dispatch.debriefs[0]["loot"], PackedStringArray([item]))
	assert_eq(dispatch.debriefs[0]["lost"], PackedStringArray())
	# A return whose seed brings nothing adds nothing.
	assert_true(dispatch.send("goblins", ["bram"], 0, gold, 1_600))
	assert_eq(Gear.loot(0, "E"), "")
	dispatch.checkpoint(2_200, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray([item]))
	assert_eq(dispatch.debriefs[1]["loot"], PackedStringArray())


func test_loot_brought_to_a_full_stash_is_lost_and_the_debrief_says_so() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	for i: int in Gear.STASH_CAP:
		assert_true(dispatch.adventurers.gear.stow("belt"))
	var roll_seed := _loot_seed("F")
	var item := Gear.loot(roll_seed, "F")
	assert_true(dispatch.send("rats", ["bram"], roll_seed, gold, 1_000))
	dispatch.checkpoint(1_060, gold)
	assert_eq(dispatch.adventurers.gear.stash.size(), 20)
	assert_eq(dispatch.debriefs[0]["loot"], PackedStringArray())
	assert_eq(dispatch.debriefs[0]["lost"], PackedStringArray([item]))
	assert_does_not_have(dispatch.adventurers.gear.stash, item if item != "belt" else "never")


func test_gear_cannot_be_changed_while_out_and_can_once_home() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.adventurers.gear.stow("chapel_plate")
	var chance := dispatch.success_chance("rats", ["bram"])
	assert_true(dispatch.send("rats", ["bram"], 1, gold, 1_000))
	assert_false(dispatch.can_change_gear("bram"))
	assert_false(dispatch.wear("bram", 0))
	assert_eq(dispatch.adventurers.gear.worn["bram"]["armour"], "leather_vest")
	assert_eq(dispatch.adventurers.gear.stash[0], "chapel_plate")
	assert_eq(dispatch.outings[0]["chance"], chance)
	# Someone home may change theirs meanwhile.
	assert_true(dispatch.can_change_gear("ilse"))
	dispatch.checkpoint(1_060, gold)
	assert_true(dispatch.can_change_gear("bram"))
	assert_true(dispatch.wear("bram", 0))
	assert_eq(dispatch.adventurers.gear.worn["bram"]["armour"], "chapel_plate")
	assert_eq(dispatch.adventurers.gear.stash[0], "leather_vest")


func test_gear_the_stash_and_loot_in_debriefs_survive_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	var roll_seed := _loot_seed("E")
	assert_true(dispatch.send("goblins", ["tobin"], roll_seed, gold, 1_000))
	dispatch.checkpoint(1_600, gold)
	dispatch.adventurers.gear.stow("night_cloak")
	assert_true(dispatch.wear("ilse", dispatch.adventurers.gear.stash.size() - 1))
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_600)
	assert_eq(loaded.adventurers.gear.worn, dispatch.adventurers.gear.worn)
	assert_eq(loaded.adventurers.gear.worn["ilse"]["back"], "night_cloak")
	assert_eq(loaded.adventurers.gear.stash, PackedStringArray([Gear.loot(roll_seed, "E")]))
	assert_eq(loaded.debriefs, dispatch.debriefs)
	assert_eq(loaded.adventurers.stat_total("ilse", "agility"), 5)
