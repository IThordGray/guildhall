extends GutTest

const SAVE_PATH: String = "user://test_game_clock_save.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


# An open clock starting at real time 1000 and running `speed` times as fast from there.
func _open_clock(speed: int) -> GameClock:
	var clock := GameClock.new(0.0)
	clock.arrive(1000.0)
	clock.set_speed(speed, 1000.0)
	return clock


func test_a_new_game_runs_on_real_time() -> void:
	assert_false(FileAccess.file_exists(SAVE_PATH))
	var clock := GameClock.load_or_start(SAVE_PATH)
	assert_eq(clock.now(5000.0), 5000)
	assert_eq(clock.speed, 1)


func test_at_x1_game_time_keeps_pace_with_real_time() -> void:
	var clock := _open_clock(1)
	assert_eq(clock.now(1000.0), 1000)
	assert_eq(clock.now(4600.0), 4600)


func test_at_x10_a_real_minute_is_ten_game_minutes() -> void:
	var clock := _open_clock(10)
	assert_eq(clock.now(1060.0), 1600)


func test_at_x60_a_real_minute_is_a_game_hour() -> void:
	var clock := _open_clock(60)
	assert_eq(clock.now(1060.0), 4600)


func test_switching_speed_neither_jumps_back_nor_forward() -> void:
	var clock := _open_clock(60)
	assert_eq(clock.now(1010.0), 1600)
	clock.set_speed(10, 1010.0)
	assert_eq(clock.now(1010.0), 1600)
	assert_eq(clock.now(1020.0), 1700)
	clock.set_speed(1, 1020.0)
	assert_eq(clock.now(1020.0), 1700)
	assert_eq(clock.now(1030.0), 1710)


func test_a_real_clock_set_back_never_turns_game_time_back() -> void:
	var clock := _open_clock(60)
	assert_eq(clock.now(1010.0), 1600)
	assert_eq(clock.now(900.0), 1600)
	assert_eq(clock.now(1020.0), 2200)


func test_a_real_clock_set_back_never_shrinks_the_time_saved() -> void:
	var clock := _open_clock(60)
	clock.set_speed(1, 900.0)
	var file := ConfigFile.new()
	clock.write(file, 900.0)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := GameClock.load_or_start(SAVE_PATH)
	loaded.arrive(2000.0)
	assert_eq(loaded.now(2000.0), 2000)


func test_time_while_the_app_is_left_counts_at_x1_and_the_speed_resumes_on_return() -> void:
	var clock := _open_clock(60)
	assert_eq(clock.now(1010.0), 1600)
	clock.leave(1010.0)
	assert_eq(clock.now(2010.0), 2600)
	clock.arrive(4610.0)
	assert_eq(clock.now(4610.0), 5200)
	assert_eq(clock.now(4620.0), 5800)


func test_time_gained_survives_a_reload_which_starts_at_x1() -> void:
	var clock := _open_clock(60)
	assert_eq(clock.now(1010.0), 1600)
	var file := ConfigFile.new()
	clock.write(file, 1010.0)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := GameClock.load_or_start(SAVE_PATH)
	loaded.arrive(2000.0)
	assert_eq(loaded.speed, 1)
	assert_eq(loaded.now(2000.0), 2590)
	assert_eq(loaded.now(2010.0), 2600)
