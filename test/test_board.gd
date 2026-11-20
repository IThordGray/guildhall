extends GutTest

const SAVE_PATH: String = "user://test_board_save.cfg"
## Unix seconds a new board in these tests is first filled at, and the slots it fills with.
const START: int = 1_000_000
const START_SLOTS: Array[String] = ["letters", "goblins", "rats"]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A board and the dispatch it was filled against, filled at START with `quest_halls` Quest halls.
func _board(dispatch: Dispatch, quest_halls: int) -> Board:
	var board := Board.new()
	board.refill(dispatch, START, quest_halls)
	return board


## A seed with which `party` on `quest` succeeds, or fails when `success` is false.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var chance := Dispatch.new(0).success_chance(quest, party)
	for roll_seed: int in 10_000:
		if Outcome.roll(roll_seed, chance, Dispatch.QUESTS[quest]["difficulty"], party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


func test_a_new_board_fills_three_slots_plus_one_per_quest_hall_without_changing_the_others() -> void:
	var gold := Gold.new(1_000)
	var dispatch := Dispatch.new(START)
	var hall := Hall.new(START)
	var board := _board(dispatch, hall.rooms_done("quest_hall", START))
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	# A Quest hall restored and converted: finished at START + 1_380.
	assert_true(hall.restore("back_left", gold, START + 1_200))
	assert_true(hall.convert_room("back_left", "quest_hall", gold, START + 1_320))
	board.refill(dispatch, START + 1_379, hall.rooms_done("quest_hall", START + 1_379))
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	board.refill(dispatch, START + 1_380, hall.rooms_done("quest_hall", START + 1_380))
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "rats", "crypt"]))


func test_the_board_never_shows_a_quest_twice_and_leaves_a_slot_empty_when_none_is_free() -> void:
	var board := _board(Dispatch.new(START), 4)
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "rats", "moonherbs", "wolves", "crypt", ""]))
	assert_eq(Dispatch.QUESTS.size(), 6)


func test_a_sent_quests_slot_refills_after_its_countdown_and_not_before() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, 0))
	assert_eq(board.slots, PackedStringArray(["", "goblins", "rats"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 100), 3_600)
	dispatch.checkpoint(START + 3_699, gold)
	board.refill(dispatch, START + 3_699, 0)
	assert_eq(board.slots, PackedStringArray(["", "goblins", "rats"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 3_699), 1)
	dispatch.checkpoint(START + 3_700, gold)
	board.refill(dispatch, START + 3_700, 0)
	assert_eq(board.slots, PackedStringArray(["wolves", "goblins", "rats"]))


func test_each_slot_counts_down_on_its_own() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, 0))
	assert_true(board.send(dispatch, "goblins", ["ilse"], 1, gold, START + 1_000, 0))
	assert_eq(board.slots, PackedStringArray(["", "", "rats"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 1_000), 2_700)
	assert_eq(board.seconds_to_refill(1, dispatch, START + 1_000), 3_600)
	board.refill(dispatch, START + 3_700, 0)
	assert_eq(board.slots, PackedStringArray(["wolves", "", "rats"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 3_700), 900)
	board.refill(dispatch, START + 4_600, 0)
	assert_eq(board.slots, PackedStringArray(["wolves", "moonherbs", "rats"]))


func test_a_quest_out_is_not_offered_and_an_empty_slot_takes_it_once_its_party_is_back() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	# Seven slots, six quests: every quest on the board, the last slot empty.
	var board := _board(dispatch, 4)
	# Rats takes a minute: out from START + 100 to START + 160.
	assert_true(board.send(dispatch, "rats", ["bram"], _seed("rats", ["bram"], true), gold, START + 100, 4))
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", ""]))
	dispatch.checkpoint(START + 159, gold)
	board.refill(dispatch, START + 159, 4)
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", ""]))
	assert_eq(board.seconds_to_refill(6, dispatch, START + 159), 0)
	dispatch.checkpoint(START + 160, gold)
	board.refill(dispatch, START + 160, 4)
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", "rats"]))
	# Rats' own slot comes due with nothing free, so it stays empty.
	board.refill(dispatch, START + 3_700, 4)
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", "rats"]))


func test_refills_draw_from_all_six_quests_and_never_repeat_one_on_the_board() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	var seen := {}
	var now := START
	for i: int in 30:
		now += Board.REFRESH_SECONDS
		assert_true(board.send(dispatch, board.slots[i % 3], ["bram"], 1, gold, now, 0))
		now += Board.REFRESH_SECONDS
		dispatch.checkpoint(now, gold)
		board.refill(dispatch, now, 0)
		assert_false(board.slots.has(""), str(i))
		for quest: String in board.slots:
			assert_eq(board.slots.count(quest), 1, str(i))
			seen[quest] = true
	assert_eq(seen.size(), 6)


func test_a_quest_not_on_the_board_cannot_be_sent() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	for quest: String in ["crypt", ""]:
		assert_false(board.send(dispatch, quest, ["bram"], 1, gold, START + 100, 0))
	assert_true(dispatch.outings.is_empty())
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_a_party_the_dispatch_refuses_leaves_the_quest_on_the_board() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_false(board.send(dispatch, "goblins", [], 1, gold, START + 100, 0))
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_clock_set_back_neither_undoes_a_refill_nor_restarts_a_countdown() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, 0))
	dispatch.checkpoint(START + 3_700, gold)
	board.refill(dispatch, START + 3_700, 0)
	assert_true(board.send(dispatch, "goblins", ["ilse"], 1, gold, START + 3_800, 0))
	assert_eq(board.slots, PackedStringArray(["wolves", "", "rats"]))
	# Set back to before the first refill: it stays, and the second countdown runs on from where it was.
	dispatch.checkpoint(START + 200, gold)
	board.refill(dispatch, START + 200, 0)
	assert_eq(board.slots, PackedStringArray(["wolves", "", "rats"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 200), 3_600)
	# Its time seen once, a clock set back again doesn't hold the refill off.
	dispatch.checkpoint(START + 7_400, gold)
	board.refill(dispatch, START + 300, 0)
	assert_ne(board.slots[1], "")


func test_the_same_save_always_refills_the_same_way() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, 0))
	dispatch.checkpoint(START + 1_000, gold)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Board.load_or_start(SAVE_PATH)
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, START + 2_000)
	assert_eq(loaded.slots, PackedStringArray(["", "goblins", "rats"]))
	assert_eq(loaded.seconds_to_refill(0, loaded_dispatch, START + 2_000), 1_700)
	for refilled: Board in [board, loaded, Board.load_or_start(SAVE_PATH)]:
		refilled.refill(loaded_dispatch, START + 3_700, 0)
		assert_eq(refilled.slots, PackedStringArray(["wolves", "goblins", "rats"]))
	# The slot and its refill time pick the quest: refilled at other times, the slot draws others.
	var drawn := {}
	for seconds: int in 10:
		var later := Board.load_or_start(SAVE_PATH)
		later.refill_at[0] += seconds
		later.refill(loaded_dispatch, START + 3_700 + seconds, 0)
		drawn[later.slots[0]] = true
	assert_gt(drawn.size(), 1)


func test_a_save_from_before_slots_starts_with_every_slot_filled() -> void:
	var file := ConfigFile.new()
	file.set_value("board", "day", 11)
	file.set_value("board", "used", PackedStringArray(["letters", "goblins"]))
	assert_eq(file.save(SAVE_PATH), OK)
	var board := Board.load_or_start(SAVE_PATH)
	board.refill(Dispatch.new(START), START, 0)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
