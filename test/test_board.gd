extends GutTest

const SAVE_PATH: String = "user://test_board_save.cfg"
## A local day, in days since 1970-01-01, and the first three quests it and the next day offer.
const DAY: int = 20_001
const DAY_QUESTS: Array[String] = ["goblins", "moonherbs", "letters"]
const NEXT_DAY_QUESTS: Array[String] = ["moonherbs", "letters", "crypt"]
const PREVIOUS_DAY_QUESTS: Array[String] = ["crypt", "wolves", "letters"]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## Unix seconds `seconds` into local day `local_day`, at UTC.
func _at(local_day: int, seconds: int) -> int:
	return local_day * 86_400 + seconds


## A seed with which `party` on `quest` succeeds, or fails when `success` is false.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var chance := Dispatch.new(0).success_chance(quest, party)
	for roll_seed: int in 10_000:
		if Outcome.roll(roll_seed, chance, Dispatch.QUESTS[quest]["difficulty"], party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


func test_board_shows_three_quests_a_day_plus_one_per_quest_hall() -> void:
	var gold := Gold.new(1_000)
	var dispatch := Dispatch.new(_at(DAY, 0))
	var board := Board.new()
	var hall := Hall.new(_at(DAY, 0))
	assert_eq(board.quests(dispatch, _at(DAY, 600), 0, hall.rooms_done("quest_hall", _at(DAY, 600))), PackedStringArray(DAY_QUESTS))
	# A Quest hall restored and converted mid-day: finished at 43_380 s into the day.
	assert_true(hall.restore("back_left", gold, _at(DAY, 43_200)))
	assert_true(hall.convert_room("back_left", "quest_hall", gold, _at(DAY, 43_320)))
	assert_eq(board.quests(dispatch, _at(DAY, 43_379), 0, hall.rooms_done("quest_hall", _at(DAY, 43_379))), PackedStringArray(DAY_QUESTS))
	assert_eq(board.quests(dispatch, _at(DAY, 43_380), 0, hall.rooms_done("quest_hall", _at(DAY, 43_380))), PackedStringArray(["goblins", "moonherbs", "letters", "crypt"]))
	assert_eq(board.quests(dispatch, _at(DAY, 50_000), 0, 2), PackedStringArray(["goblins", "moonherbs", "letters", "crypt", "rats"]))
	# Never more than the six quests there are.
	for quest_halls: int in [3, 4]:
		assert_eq(board.quests(dispatch, _at(DAY, 50_000), 0, quest_halls), PackedStringArray(["goblins", "moonherbs", "letters", "crypt", "rats", "wolves"]))


func test_the_same_day_always_shows_the_same_quests_drawn_from_all_six() -> void:
	var board := Board.new()
	for seconds: int in [0, 1, 43_200, 86_399]:
		assert_eq(board.quests(Dispatch.new(_at(DAY, 0)), _at(DAY, seconds), 0, 0), PackedStringArray(DAY_QUESTS), str(seconds))
	assert_eq(board.quests(Dispatch.new(_at(DAY, 0)), _at(DAY + 1, 0), 0, 0), PackedStringArray(NEXT_DAY_QUESTS))
	assert_eq(board.quests(Dispatch.new(_at(DAY - 1, 0)), _at(DAY - 1, 0), 0, 0), PackedStringArray(PREVIOUS_DAY_QUESTS))
	var seen := {}
	for local_day: int in range(DAY, DAY + 30):
		for quest: String in board.quests(Dispatch.new(_at(local_day, 0)), _at(local_day, 0), 0, 0):
			seen[quest] = true
	assert_eq(seen.size(), 6)
	assert_eq(Dispatch.QUESTS.size(), 6)


func test_the_board_day_is_the_local_calendar_day() -> void:
	var board := Board.new()
	# 23:30 UTC is 00:30 the next day an hour east of UTC.
	var late := _at(DAY, 84_600)
	assert_eq(board.quests(Dispatch.new(late), late, 0, 0), PackedStringArray(DAY_QUESTS))
	assert_eq(board.quests(Dispatch.new(late), late, 60, 0), PackedStringArray(NEXT_DAY_QUESTS))
	# 00:30 UTC is still the day before an hour west of UTC.
	var early := _at(DAY + 1, 1_800)
	assert_eq(board.quests(Dispatch.new(early), early, 0, 0), PackedStringArray(NEXT_DAY_QUESTS))
	assert_eq(board.quests(Dispatch.new(early), early, -60, 0), PackedStringArray(DAY_QUESTS))


func test_used_quest_stays_off_until_next_day() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(_at(DAY, 0))
	var board := Board.new()
	assert_true(board.send(dispatch, "moonherbs", ["bram"], _seed("moonherbs", ["bram"], true), gold, _at(DAY, 100), 0, 0))
	assert_true(board.send(dispatch, "letters", ["ilse"], _seed("letters", ["ilse"], false), gold, _at(DAY, 100), 0, 0))
	assert_eq(board.quests(dispatch, _at(DAY, 100), 0, 0), PackedStringArray(["goblins"]))
	# Both back, one a success and one a failure: neither comes back to the board that day.
	dispatch.checkpoint(_at(DAY, 1_000), gold)
	assert_true(dispatch.outings.is_empty())
	assert_eq(gold.amount, 150 + 25)
	assert_eq(board.quests(dispatch, _at(DAY, 86_399), 0, 0), PackedStringArray(["goblins"]))
	assert_false(board.send(dispatch, "moonherbs", ["tobin"], 1, gold, _at(DAY, 86_399), 0, 0))
	assert_true(dispatch.outings.is_empty())
	# The next local day shows that day's quests, the two used yesterday among them.
	assert_eq(board.quests(dispatch, _at(DAY + 1, 0), 0, 0), PackedStringArray(NEXT_DAY_QUESTS))
	assert_true(board.send(dispatch, "moonherbs", ["tobin"], 1, gold, _at(DAY + 1, 10), 0, 0))
	assert_eq(board.quests(dispatch, _at(DAY + 1, 10), 0, 0), PackedStringArray(["letters", "crypt"]))


func test_clock_set_back_keeps_used_quests_used() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(_at(DAY, 0))
	var board := Board.new()
	assert_true(board.send(dispatch, "goblins", ["bram"], 1, gold, _at(DAY, 100), 0, 0))
	dispatch.checkpoint(_at(DAY, 3_600), gold)
	# Set back to the day before: still today's board, goblins still used.
	assert_eq(board.quests(dispatch, _at(DAY - 1, 50_000), 0, 0), PackedStringArray(["moonherbs", "letters"]))
	assert_false(board.send(dispatch, "goblins", ["ilse"], 1, gold, _at(DAY - 1, 50_000), 0, 0))
	assert_false(board.send(dispatch, "crypt", ["ilse"], 1, gold, _at(DAY - 1, 50_000), 0, 0))
	assert_true(dispatch.outings.is_empty())
	# Once the next day has been seen, setting the clock back never brings back the earlier board.
	dispatch.checkpoint(_at(DAY + 1, 10), gold)
	assert_eq(board.quests(dispatch, _at(DAY, 50_000), 0, 0), PackedStringArray(NEXT_DAY_QUESTS))


func test_a_quest_still_out_is_not_on_the_board_until_its_party_is_back() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(_at(DAY - 1, 0))
	var board := Board.new()
	# Letters takes two minutes: sent a minute before midnight, it is still out on the next day.
	assert_true(board.send(dispatch, "letters", ["bram"], _seed("letters", ["bram"], true), gold, _at(DAY - 1, 86_340), 0, 0))
	assert_eq(board.quests(dispatch, _at(DAY, 30), 0, 0), PackedStringArray(["goblins", "moonherbs"]))
	assert_false(board.send(dispatch, "letters", ["ilse"], 1, gold, _at(DAY, 30), 0, 0))
	assert_eq(dispatch.outings.size(), 1)
	# Back at 60 s into the day: used yesterday, so on today's board again.
	dispatch.checkpoint(_at(DAY, 60), gold)
	assert_eq(board.quests(dispatch, _at(DAY, 60), 0, 0), PackedStringArray(DAY_QUESTS))
	assert_true(board.send(dispatch, "letters", ["ilse"], 1, gold, _at(DAY, 60), 0, 0))


func test_a_quest_not_on_the_board_cannot_be_sent() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(_at(DAY, 0))
	var board := Board.new()
	assert_false(board.send(dispatch, "rats", ["bram"], 1, gold, _at(DAY, 100), 0, 0))
	assert_true(dispatch.outings.is_empty())
	assert_eq(board.quests(dispatch, _at(DAY, 100), 0, 0), PackedStringArray(DAY_QUESTS))
	# With a Quest hall, rats is not yet on the board, crypt is.
	assert_false(board.send(dispatch, "rats", ["bram"], 1, gold, _at(DAY, 100), 0, 1))
	assert_true(board.send(dispatch, "crypt", ["bram"], 1, gold, _at(DAY, 100), 0, 1))


func test_a_party_the_dispatch_refuses_leaves_the_quest_on_the_board() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(_at(DAY, 0))
	var board := Board.new()
	assert_false(board.send(dispatch, "goblins", [], 1, gold, _at(DAY, 100), 0, 0))
	assert_eq(board.quests(dispatch, _at(DAY, 100), 0, 0), PackedStringArray(DAY_QUESTS))


func test_the_board_and_its_used_quests_survive_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(_at(DAY, 0))
	var board := Board.new()
	assert_true(board.send(dispatch, "moonherbs", ["bram"], 1, gold, _at(DAY, 100), 0, 0))
	dispatch.checkpoint(_at(DAY, 1_000), gold)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Board.load_or_start(SAVE_PATH)
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, _at(DAY, 2_000))
	assert_eq(loaded.day, board.day)
	assert_eq(loaded.used, PackedStringArray(["moonherbs"]))
	assert_eq(loaded.quests(loaded_dispatch, _at(DAY, 2_000), 0, 0), PackedStringArray(["goblins", "letters"]))
	assert_eq(loaded.quests(loaded_dispatch, _at(DAY + 1, 0), 0, 0), PackedStringArray(NEXT_DAY_QUESTS))
