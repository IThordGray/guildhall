extends GutTest

const SAVE_PATH: String = "user://test_gold_save.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_gold_rises_by_one_per_second() -> void:
	var gold := Gold.new(0, 1_000)
	assert_eq(gold.amount(1_000), 0)
	assert_eq(gold.amount(1_000 + 3_600), 3_600)


func test_away_gain_is_the_gold_earned_since_leaving_not_the_total() -> void:
	var gold := Gold.new(0, 1_000)
	gold.checkpoint(1_250)
	assert_eq(gold.gained_since_checkpoint(1_250), 0)
	assert_eq(gold.gained_since_checkpoint(1_250 + 600), 600)
	assert_eq(gold.amount(1_250 + 600), 850)


func test_a_checkpoint_keeps_the_total() -> void:
	var gold := Gold.new(40, 1_000)
	gold.checkpoint(1_100)
	assert_eq(gold.amount(1_100), 140)
	assert_eq(gold.amount(1_160), 200)


func test_a_clock_set_backwards_never_shows_less_than_the_save() -> void:
	var gold := Gold.new(500, 10_000)
	assert_eq(gold.amount(9_000), 500)
	gold.checkpoint(9_000)
	assert_eq(gold.amount(9_000), 500)
	assert_eq(gold.gained_since_checkpoint(9_000), 0)


func test_a_clock_set_back_then_forward_gives_no_free_gold() -> void:
	var gold := Gold.new(500, 10_000)
	gold.checkpoint(9_000)
	assert_eq(gold.amount(10_060), 560)


func test_a_save_loads_into_a_fresh_state_with_the_same_gold() -> void:
	var gold := Gold.new(0, 1_000)
	gold.checkpoint(1_234)
	assert_eq(gold.save(SAVE_PATH), OK)

	var loaded := Gold.load_or_start(SAVE_PATH, 99_999)
	assert_eq(loaded.amount(1_234), 234)
	assert_eq(loaded.gained_since_checkpoint(1_300), 66)


func test_with_no_save_a_new_game_starts_with_no_gold_now() -> void:
	assert_false(FileAccess.file_exists(SAVE_PATH))
	var gold := Gold.load_or_start(SAVE_PATH, 5_000)
	assert_eq(gold.amount(5_000), 0)
	assert_eq(gold.amount(5_010), 10)
