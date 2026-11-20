extends GutTest

const SAVE_PATH: String = "user://test_gold_save.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_a_save_loads_into_a_fresh_state_with_the_same_gold() -> void:
	var file := ConfigFile.new()
	Gold.new(234).write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 234)


func test_with_no_save_a_new_game_starts_with_100_gold() -> void:
	assert_false(FileAccess.file_exists(SAVE_PATH))
	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 100)


func test_an_old_save_with_no_gold_keeps_its_none() -> void:
	var file := ConfigFile.new()
	Gold.new(0).write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 0)


func test_spending_takes_the_cost_from_the_gold_held() -> void:
	var gold := Gold.new(150)
	assert_true(gold.spend(100))
	assert_eq(gold.amount, 50)


func test_spending_more_than_is_held_is_refused_and_takes_nothing() -> void:
	var gold := Gold.new(50)
	assert_false(gold.spend(100))
	assert_eq(gold.amount, 50)
