extends GutTest

const SAVE_PATH: String = "user://test_dispatch_save.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_the_board_has_three_quests_each_paying_its_gold_after_its_duration() -> void:
	var expected := {
		"rats": ["Rats in the cellar", 60, 50],
		"moonherbs": ["Gather moonherbs", 180, 150],
		"goblins": ["Goblin camp", 600, 500],
	}
	assert_eq(Dispatch.QUESTS.keys(), expected.keys())
	for quest: String in expected:
		var gold := Gold.new(0)
		var dispatch := Dispatch.new(1_000)
		assert_eq(Dispatch.QUESTS[quest]["name"], expected[quest][0])
		assert_true(dispatch.send(quest, gold, 1_000))
		assert_eq(dispatch.seconds_left(1_000), expected[quest][1], quest)
		dispatch.checkpoint(1_000 + expected[quest][1], gold)
		assert_eq(gold.amount, expected[quest][2], quest)


func test_sending_the_party_starts_its_timer_and_refuses_another_send_while_out() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_eq(dispatch.refusal(1_000), "")
	assert_true(dispatch.send("moonherbs", gold, 1_000))
	assert_eq(dispatch.seconds_left(1_030), 150)
	assert_eq(dispatch.refusal(1_030), "Party is out")
	assert_false(dispatch.send("rats", gold, 1_030))
	assert_eq(dispatch.quest, "moonherbs")
	assert_eq(dispatch.seconds_left(1_030), 150)


func test_the_reward_lands_exactly_when_the_quest_ends_and_not_a_second_before() -> void:
	var gold := Gold.new(10)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("rats", gold, 1_000)
	dispatch.checkpoint(1_059, gold)
	assert_eq(gold.amount, 10)
	assert_eq(dispatch.seconds_left(1_059), 1)
	assert_eq(dispatch.refusal(1_059), "Party is out")
	dispatch.checkpoint(1_060, gold)
	assert_eq(gold.amount, 60)
	assert_eq(dispatch.refusal(1_060), "")


func test_the_reward_is_paid_once_however_many_checkpoints_follow() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("rats", gold, 1_000)
	for now: int in [1_060, 1_061, 1_200, 5_000, 5_000]:
		dispatch.checkpoint(now, gold)
	assert_eq(gold.amount, 50)


func test_a_quest_that_ended_while_the_app_was_closed_pays_on_the_first_checkpoint_after() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("goblins", gold, 1_000)
	dispatch.checkpoint(1_010, gold)
	assert_false(dispatch.returned_since_checkpoint(1_500))
	assert_true(dispatch.returned_since_checkpoint(9_000))
	dispatch.checkpoint(9_000, gold)
	assert_eq(gold.amount, 500)
	assert_false(dispatch.returned_since_checkpoint(9_000))


func test_a_clock_set_back_after_the_return_pays_nothing_extra_and_does_not_rerun_the_quest() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("rats", gold, 1_000)
	dispatch.checkpoint(1_100, gold)
	assert_eq(gold.amount, 50)

	dispatch.checkpoint(990, gold)
	assert_eq(gold.amount, 50)
	assert_eq(dispatch.seconds_left(990), 0)
	assert_eq(dispatch.refusal(990), "")
	assert_false(dispatch.returned_since_checkpoint(990))
	dispatch.checkpoint(1_100, gold)
	dispatch.checkpoint(2_000, gold)
	assert_eq(gold.amount, 50)


func test_a_clock_set_back_mid_quest_adds_no_time_to_the_countdown() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("moonherbs", gold, 1_000)
	dispatch.checkpoint(1_100, gold)
	dispatch.checkpoint(500, gold)
	assert_eq(dispatch.seconds_left(500), 80)
	dispatch.checkpoint(1_180, gold)
	assert_eq(gold.amount, 150)


func test_with_the_party_home_time_passing_adds_no_gold() -> void:
	var gold := Gold.new(70)
	var dispatch := Dispatch.new(1_000)
	dispatch.checkpoint(1_000 + 3_600, gold)
	assert_eq(gold.amount, 70)
	assert_true(dispatch.send("rats", gold, 4_600))
	dispatch.checkpoint(4_660 + 3_600, gold)
	assert_eq(gold.amount, 120)


func test_a_quest_in_progress_survives_save_and_load() -> void:
	var gold := Gold.new(30)
	var dispatch := Dispatch.new(1_000)
	dispatch.send("moonherbs", gold, 1_000)
	dispatch.checkpoint(1_050, gold)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded.quest, "moonherbs")
	assert_eq(loaded.seconds_left(1_050), 130)
	assert_eq(loaded.refusal(1_050), "Party is out")
	loaded.checkpoint(1_179, loaded_gold)
	assert_eq(loaded_gold.amount, 30)
	loaded.checkpoint(1_180, loaded_gold)
	assert_eq(loaded_gold.amount, 180)


func test_an_m2_save_loads_with_its_gold_kept_and_the_party_home() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 300)
	file.set_value("gold", "saved_at", 1_000)
	Hall.new(1_000).write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_eq(dispatch.quest, "")
	assert_eq(dispatch.refusal(2_000), "")
	dispatch.checkpoint(2_000, gold)
	assert_eq(gold.amount, 300)
	assert_true(dispatch.send("rats", gold, 2_000))
