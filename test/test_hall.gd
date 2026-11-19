extends GutTest

const SAVE_PATH: String = "user://test_hall_save.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_a_new_hall_has_the_entrance_and_reception_usable_and_other_rooms_damaged() -> void:
	var hall := Hall.new(1_000)
	assert_eq(hall.state("entrance", 1_000), Hall.State.USABLE)
	assert_eq(hall.state("reception", 1_000), Hall.State.USABLE)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)


func test_restoring_a_damaged_room_takes_120_gold_at_once() -> void:
	var gold := Gold.new(150, 1_000)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_eq(gold.amount(1_000), 30)
	assert_eq(hall.state("back_left", 1_000), Hall.State.RESTORING)


func test_restoring_is_refused_with_the_shortfall_when_gold_is_short() -> void:
	var gold := Gold.new(100, 1_000)
	var hall := Hall.new(1_000)
	assert_eq(hall.refusal("back_left", gold, 1_000), "Need 20 more gold")
	assert_false(hall.restore("back_left", gold, 1_000))
	assert_eq(gold.amount(1_000), 100)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)
	assert_eq(hall.refusal("back_left", gold, 1_020), "")


func test_restoring_is_refused_while_the_builder_is_busy_and_allowed_once_free() -> void:
	var gold := Gold.new(1_000, 1_000)
	var hall := Hall.new(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_eq(hall.refusal("back_right", gold, 1_010), "Builder busy")
	assert_false(hall.restore("back_right", gold, 1_010))
	assert_eq(gold.amount(1_010), 890)
	assert_eq(hall.state("back_right", 1_010), Hall.State.DAMAGED)
	assert_true(hall.restore("back_right", gold, 1_120))
	assert_eq(hall.state("back_left", 1_120), Hall.State.RESTORED)


func test_restoring_is_refused_for_a_room_that_is_not_damaged() -> void:
	var gold := Gold.new(1_000, 1_000)
	var hall := Hall.new(1_000)
	assert_false(hall.restore("entrance", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_false(hall.restore("back_left", gold, 1_200))
	assert_eq(gold.amount(1_200), 1_080)


func test_a_room_is_restored_exactly_120_seconds_after_starting() -> void:
	var gold := Gold.new(120, 1_000)
	var hall := Hall.new(1_000)
	hall.restore("side_left", gold, 1_000)
	assert_eq(hall.state("side_left", 1_119), Hall.State.RESTORING)
	assert_eq(hall.seconds_left(1_119), 1)
	assert_eq(hall.state("side_left", 1_120), Hall.State.RESTORED)
	assert_eq(hall.seconds_left(1_120), 0)


func test_a_clock_set_back_after_completion_keeps_the_room_restored_and_charges_nothing() -> void:
	var gold := Gold.new(200, 1_000)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	gold.checkpoint(1_200)
	hall.checkpoint(1_200)
	assert_eq(gold.amount(1_200), 280)

	gold.checkpoint(900)
	hall.checkpoint(900)
	assert_eq(hall.state("back_left", 900), Hall.State.RESTORED)
	assert_eq(hall.seconds_left(900), 0)
	assert_false(hall.finished_since_checkpoint(900))
	assert_eq(gold.amount(900), 280)
	assert_eq(hall.refusal("back_right", gold, 900), "")


func test_a_clock_set_back_mid_restoration_adds_no_time_to_the_countdown() -> void:
	var gold := Gold.new(120, 1_000)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_060)
	assert_eq(hall.seconds_left(500), 60)
	hall.checkpoint(500)
	assert_eq(hall.seconds_left(500), 60)
	assert_eq(hall.seconds_left(1_090), 30)


func test_a_restoration_in_progress_survives_save_and_load() -> void:
	var gold := Gold.new(500, 1_000)
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
	assert_eq(Gold.load_or_start(SAVE_PATH, 99_999).amount(1_150), 410)


func test_a_save_with_gold_only_loads_with_the_gold_kept_and_a_fresh_hall() -> void:
	var gold := Gold.new(0, 1_000)
	gold.checkpoint(1_234)
	assert_eq(gold.save(SAVE_PATH), OK)

	var hall := Hall.load_or_start(SAVE_PATH, 2_000)
	assert_eq(hall.state("entrance", 2_000), Hall.State.USABLE)
	assert_eq(hall.state("back_left", 2_000), Hall.State.DAMAGED)
	assert_eq(hall.seconds_left(2_000), 0)
	assert_eq(Gold.load_or_start(SAVE_PATH, 2_000).amount(1_234), 234)


func test_a_restoration_that_finished_while_away_is_reported_on_return_once() -> void:
	var gold := Gold.new(120, 1_000)
	var hall := Hall.new(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_010)
	assert_false(hall.finished_since_checkpoint(1_100))
	assert_true(hall.finished_since_checkpoint(1_300))
	hall.checkpoint(1_300)
	assert_false(hall.finished_since_checkpoint(1_400))
	assert_eq(hall.state("back_left", 1_400), Hall.State.RESTORED)
