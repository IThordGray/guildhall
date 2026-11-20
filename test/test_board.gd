extends GutTest

const SAVE_PATH: String = "user://test_board_save.cfg"
## Unix seconds a new board in these tests is first filled at, and the slots it fills with.
const START: int = 1_000_000
const START_SLOTS: Array[String] = ["letters", "goblins", "rats"]
const NO_HALLS: PackedInt64Array = []


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A board filled at START against `dispatch`, with `quest_halls` Quest halls finished by then.
func _board(dispatch: Dispatch, quest_halls: int) -> Board:
	var board := Board.new()
	board.refill(dispatch, START, _halls(quest_halls))
	return board


## The finish times of `count` Quest halls, all finished at START.
func _halls(count: int) -> PackedInt64Array:
	var done := PackedInt64Array()
	done.resize(count)
	done.fill(START)
	return done


## A seed with which `party` on `quest` succeeds, or fails when `success` is false.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var chance := Dispatch.new(0).success_chance(quest, party)
	for roll_seed: int in 10_000:
		if Outcome.roll(roll_seed, chance, Dispatch.QUESTS[quest]["difficulty"], party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


## Plays a game from START to `end`: each send in `sends`, as [unix seconds, slot, party], sends
## that slot's quest; Quest halls finish at `halls`. With `step` above 0 the board is refilled every
## `step` seconds as well, as while the app is open; with 0, only at the sends and at `end`, as
## when the player is away in between. The board at `end`.
func _play(sends: Array, halls: PackedInt64Array, end: int, step: int) -> Board:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := Board.new()
	board.refill(dispatch, START, _done_by(halls, START))
	var now := START
	for send: Array in sends + [[end, -1, []]]:
		while step > 0 and now + step < send[0]:
			now += step
			dispatch.checkpoint(now, gold)
			board.refill(dispatch, now, _done_by(halls, now))
		now = send[0]
		if send[1] >= 0:
			# The board the player picks from.
			dispatch.checkpoint(now, gold)
			board.refill(dispatch, now, _done_by(halls, now))
			var party: PackedStringArray = send[2]
			assert_true(board.send(dispatch, board.slots[send[1]], party, 1, gold, now, _done_by(halls, now)), str(send))
	dispatch.checkpoint(end, gold)
	board.refill(dispatch, end, _done_by(halls, end))
	return board


## The finish times in `halls` no later than `now`, as the hall knows them at `now`.
func _done_by(halls: PackedInt64Array, now: int) -> PackedInt64Array:
	var done := PackedInt64Array()
	for at: int in halls:
		if at <= now:
			done.append(at)
	return done


func test_a_new_board_fills_three_slots_plus_one_per_quest_hall_without_changing_the_others() -> void:
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	assert_eq(board.filled(), 3)
	board.refill(dispatch, START + 1_379, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	board.refill(dispatch, START + 1_380, PackedInt64Array([START + 1_380]))
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "rats", "crypt"]))
	assert_eq(board.filled(), 4)


func test_the_board_never_shows_a_quest_twice_and_leaves_a_slot_empty_when_none_is_free() -> void:
	var board := _board(Dispatch.new(START), 4)
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "rats", "moonherbs", "wolves", "crypt", ""]))
	assert_eq(board.filled(), 6)
	assert_eq(Dispatch.QUESTS.size(), 6)


func test_a_sent_quests_slot_refills_after_its_countdown_and_not_before() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["", "goblins", "rats"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 100), 3_600)
	dispatch.checkpoint(START + 3_699, gold)
	board.refill(dispatch, START + 3_699, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["", "goblins", "rats"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 3_699), 1)
	dispatch.checkpoint(START + 3_700, gold)
	board.refill(dispatch, START + 3_700, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["wolves", "goblins", "rats"]))


func test_each_slot_counts_down_on_its_own() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "goblins", ["ilse"], 1, gold, START + 1_000, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["", "", "rats"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 1_000), 2_700)
	assert_eq(board.seconds_to_refill(1, dispatch, START + 1_000), 3_600)
	board.refill(dispatch, START + 3_700, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["wolves", "", "rats"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 3_700), 900)
	board.refill(dispatch, START + 4_600, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["wolves", "letters", "rats"]))


func test_a_quest_out_is_not_offered_and_an_empty_slot_takes_it_once_its_party_is_back() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	# Seven slots, six quests: every quest on the board, the last slot empty.
	var board := _board(dispatch, 4)
	# Rats takes a minute: out from START + 100 to START + 160.
	assert_true(board.send(dispatch, "rats", ["bram"], _seed("rats", ["bram"], true), gold, START + 100, _halls(4)))
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", ""]))
	dispatch.checkpoint(START + 159, gold)
	board.refill(dispatch, START + 159, _halls(4))
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", ""]))
	assert_eq(board.seconds_to_refill(6, dispatch, START + 159), 0)
	dispatch.checkpoint(START + 160, gold)
	board.refill(dispatch, START + 160, _halls(4))
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", "rats"]))
	# Rats' own slot comes due with nothing free, so it stays empty.
	board.refill(dispatch, START + 3_700, _halls(4))
	assert_eq(board.slots, PackedStringArray(["letters", "goblins", "", "moonherbs", "wolves", "crypt", "rats"]))


func test_refills_draw_from_all_six_quests_and_never_repeat_one_on_the_board() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	var seen := {}
	var now := START
	for i: int in 30:
		now += Board.REFRESH_SECONDS
		assert_true(board.send(dispatch, board.slots[i % 3], ["bram"], 1, gold, now, NO_HALLS))
		now += Board.REFRESH_SECONDS
		dispatch.checkpoint(now, gold)
		board.refill(dispatch, now, NO_HALLS)
		assert_false(board.slots.has(""), str(i))
		for quest: String in board.slots:
			assert_eq(board.slots.count(quest), 1, str(i))
			seen[quest] = true
	assert_eq(seen.size(), 6)


func test_one_refill_after_an_absence_gives_the_board_refilling_every_second_gives() -> void:
	# Letters sent, then goblins: letters' slot comes due while goblins is still out.
	var sends: Array = [[START, 0, ["bram"]], [START + 3_500, 1, ["ilse"]]]
	assert_eq(_play(sends, NO_HALLS, START + 4_200, 0).slots, PackedStringArray(["letters", "", "rats"]))
	assert_eq(_play(sends, NO_HALLS, START + 4_200, 1).slots, PackedStringArray(["letters", "", "rats"]))
	# Overlapping outings, a Quest hall finished while away, and slots coming due while away.
	sends = [
		[START, 0, ["bram"]],
		[START + 3_500, 1, ["ilse"]],
		[START + 3_550, 2, ["tobin"]],
		[START + 3_700, 0, ["bram"]],
		[START + 7_400, 3, ["ilse"]],
	]
	var halls := PackedInt64Array([START + 5_000])
	var away := _play(sends, halls, START + 12_000, 0)
	assert_eq(away.slots, _play(sends, halls, START + 12_000, 1).slots)
	assert_eq(away.slots, _play(sends, halls, START + 12_000, 7).slots)
	assert_eq(away.filled(), 4)
	# Seven slots: a slot with nothing free takes rats when its party is back, while away.
	sends = [[START + 100, 2, ["bram"]], [START + 110, 0, ["ilse"]]]
	away = _play(sends, _halls(4), START + 5_000, 0)
	assert_eq(away.slots, PackedStringArray(["", "goblins", "letters", "moonherbs", "wolves", "crypt", "rats"]))
	assert_eq(_play(sends, _halls(4), START + 5_000, 1).slots, away.slots)


func test_a_quest_not_on_the_board_cannot_be_sent() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	for quest: String in ["crypt", ""]:
		assert_false(board.send(dispatch, quest, ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_true(dispatch.outings.is_empty())
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_a_party_the_dispatch_refuses_leaves_the_quest_on_the_board() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_false(board.send(dispatch, "goblins", [], 1, gold, START + 100, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_clock_set_back_neither_undoes_a_refill_nor_restarts_a_countdown() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, NO_HALLS))
	dispatch.checkpoint(START + 3_700, gold)
	board.refill(dispatch, START + 3_700, NO_HALLS)
	assert_true(board.send(dispatch, "goblins", ["ilse"], 1, gold, START + 3_800, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["wolves", "", "rats"]))
	# Set back to before the first refill: it stays, and the second countdown runs on from where it was.
	dispatch.checkpoint(START + 200, gold)
	board.refill(dispatch, START + 200, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["wolves", "", "rats"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 200), 3_600)
	# Its time seen once, a clock set back again doesn't hold the refill off.
	dispatch.checkpoint(START + 7_400, gold)
	board.refill(dispatch, START + 300, NO_HALLS)
	assert_ne(board.slots[1], "")


func test_the_same_save_always_refills_the_same_way() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "letters", ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "goblins", ["ilse"], 1, gold, START + 3_500, NO_HALLS))
	dispatch.checkpoint(START + 3_550, gold)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Board.load_or_start(SAVE_PATH)
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, START + 3_550)
	assert_eq(loaded.slots, PackedStringArray(["", "", "rats"]))
	assert_eq(loaded.seconds_to_refill(0, loaded_dispatch, START + 3_550), 150)
	# Away until goblins is back: the save alone says goblins was out when slot 0 came due.
	loaded_dispatch.checkpoint(START + 4_200, gold)
	for refilled: Board in [loaded, Board.load_or_start(SAVE_PATH)]:
		refilled.refill(loaded_dispatch, START + 4_200, NO_HALLS)
		assert_eq(refilled.slots, PackedStringArray(["wolves", "", "rats"]))
	# The slot and its refill time pick the quest: refilled at other times, the slot draws others.
	var drawn := {}
	for seconds: int in 10:
		var later := Board.load_or_start(SAVE_PATH)
		later.refill_at[0] += seconds
		later.refill(loaded_dispatch, START + 4_200, NO_HALLS)
		drawn[later.slots[0]] = true
	assert_gt(drawn.size(), 1)


func test_a_save_from_before_slots_starts_with_every_slot_filled() -> void:
	var file := ConfigFile.new()
	file.set_value("board", "day", 11)
	file.set_value("board", "used", PackedStringArray(["letters", "goblins"]))
	assert_eq(file.save(SAVE_PATH), OK)
	var board := Board.load_or_start(SAVE_PATH)
	board.refill(Dispatch.new(START), START, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
