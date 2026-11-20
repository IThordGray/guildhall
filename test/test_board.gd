extends GutTest

const SAVE_PATH: String = "user://test_board_save.cfg"
## Unix seconds a new board in these tests is first filled at, and the slots it fills with: rank E,
## F and E quests.
const START: int = 1_000_000
const START_SLOTS: Array[String] = ["sealed_door", "cartographer", "crypt"]
const NO_HALLS: PackedInt64Array = []
## Every quest a guild whose best adventurer is rank F can take: ranks F and E.
const F_AND_E_QUESTS: Array[String] = [
	"cartographer", "crypt", "goblins", "letters", "lurker", "moonherbs", "mouth", "pilgrims", "rats",
	"sealed_door", "spiders", "well", "wolves",
]

## The ranks of the quests _play has sent, as keys.
var _sent_ranks: Dictionary = {}


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


## A new guild whose four starters are all of `rank`.
func _guild(rank: String) -> Dispatch:
	var dispatch := Dispatch.new(START)
	for adventurer: String in dispatch.adventurers.roster:
		dispatch.adventurers.roster[adventurer]["rank"] = rank
	return dispatch


## A seed with which `party` on `quest` succeeds, or fails when `success` is false.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var chance := Dispatch.new(0).success_chance(quest, party)
	for roll_seed: int in 10_000:
		if Outcome.roll(roll_seed, chance, 0, party, Adventurers.STARTERS).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


## Plays a game from START to `end` for a guild whose starters are all of `rank`: each send in
## `sends`, as [unix seconds, slot, party], sends that slot's quest; Quest halls finish at `halls`.
## With `step` above 0 the board is refilled every `step` seconds as well, as while the app is
## open; with 0, only at the sends and at `end`, as when the player is away in between. The board
## at `end`.
func _play(sends: Array, halls: PackedInt64Array, end: int, step: int, rank: String = "F") -> Board:
	var gold := Gold.new(0)
	var dispatch := _guild(rank)
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
			var quest := board.slots[send[1]]
			assert_true(board.send(dispatch, quest, party, 1, gold, now, _done_by(halls, now)), str(send))
			_sent_ranks[Dispatch.QUESTS[quest]["rank"]] = true
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
	assert_eq(board.slots, PackedStringArray(["sealed_door", "cartographer", "crypt", "moonherbs"]))
	assert_eq(board.filled(), 4)


func test_the_board_never_shows_a_quest_twice_and_leaves_a_slot_empty_when_none_is_free() -> void:
	# Fourteen slots, thirteen quests a new guild can take.
	var board := _board(Dispatch.new(START), 11)
	assert_eq(board.slots.size(), 14)
	assert_eq(board.filled(), 13)
	assert_eq(board.slots[13], "")
	var shown: Array[String] = []
	shown.assign(board.slots.slice(0, 13))
	shown.sort()
	assert_eq(shown, F_AND_E_QUESTS)


func test_a_sent_quests_slot_refills_after_a_countdown_set_by_its_rank_f_10_minutes_e_30_and_d_60() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "cartographer", ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "sealed_door", ["ilse"], 1, gold, START + 100, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 100), 600)
	assert_eq(board.seconds_to_refill(0, dispatch, START + 100), 1_800)
	dispatch.checkpoint(START + 699, gold)
	board.refill(dispatch, START + 699, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 699), 1)
	dispatch.checkpoint(START + 700, gold)
	board.refill(dispatch, START + 700, NO_HALLS)
	assert_ne(board.slots[1], "")
	assert_eq(board.slots[0], "")
	dispatch.checkpoint(START + 1_899, gold)
	board.refill(dispatch, START + 1_899, NO_HALLS)
	assert_eq(board.slots[0], "")
	dispatch.checkpoint(START + 1_900, gold)
	board.refill(dispatch, START + 1_900, NO_HALLS)
	assert_ne(board.slots[0], "")
	# A rank D quest, for a guild with someone rank E.
	var ranked := _guild("E")
	var ranked_board := _board(ranked, 0)
	assert_eq(Dispatch.QUESTS[ranked_board.slots[1]]["rank"], "D")
	assert_true(ranked_board.send(ranked, ranked_board.slots[1], ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_eq(ranked_board.seconds_to_refill(1, ranked, START + 100), 3_600)


func test_each_slot_counts_down_on_its_own() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "cartographer", ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "sealed_door", ["ilse"], 1, gold, START + 200, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 200), 500)
	assert_eq(board.seconds_to_refill(0, dispatch, START + 200), 1_800)
	board.refill(dispatch, START + 700, NO_HALLS)
	assert_ne(board.slots[1], "")
	assert_eq(board.slots[0], "")
	assert_eq(board.seconds_to_refill(0, dispatch, START + 700), 1_300)
	board.refill(dispatch, START + 2_000, NO_HALLS)
	assert_ne(board.slots[0], "")
	assert_ne(board.slots[0], board.slots[1])


func test_a_quest_out_is_not_offered_and_an_empty_slot_takes_it_once_its_party_is_back() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	# Fourteen slots, thirteen quests: every quest on the board, the last slot empty.
	var board := _board(dispatch, 11)
	var shown := board.slots.duplicate()
	var rats := shown.find("rats")
	assert_ne(rats, -1)
	assert_eq(shown[13], "")
	# Rats takes a minute: out from START + 100 to START + 160.
	assert_true(board.send(dispatch, "rats", ["bram"], _seed("rats", ["bram"], true), gold, START + 100, _halls(11)))
	shown[rats] = ""
	assert_eq(board.slots, shown)
	dispatch.checkpoint(START + 159, gold)
	board.refill(dispatch, START + 159, _halls(11))
	assert_eq(board.slots, shown)
	assert_eq(board.seconds_to_refill(13, dispatch, START + 159), 0)
	dispatch.checkpoint(START + 160, gold)
	board.refill(dispatch, START + 160, _halls(11))
	shown[13] = "rats"
	assert_eq(board.slots, shown)
	# Rats' own slot comes due with nothing free, so it stays empty.
	board.refill(dispatch, START + 3_700, _halls(11))
	assert_eq(board.slots, shown)


func test_a_new_guild_is_offered_every_rank_f_and_e_quest_in_turn_never_one_twice_and_never_rank_d() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	var seen := {}
	var now := START
	for i: int in 100:
		now += 3_600
		assert_true(board.send(dispatch, board.slots[i % 3], ["bram"], 1, gold, now, NO_HALLS))
		now += 3_600
		dispatch.checkpoint(now, gold)
		board.refill(dispatch, now, NO_HALLS)
		assert_false(board.slots.has(""), str(i))
		for quest: String in board.slots:
			assert_eq(board.slots.count(quest), 1, str(i))
			seen[quest] = true
	var offered: Array[String] = []
	offered.assign(seen.keys())
	offered.sort()
	assert_eq(offered, F_AND_E_QUESTS)


func test_with_one_rank_e_adventurer_rank_d_quests_reach_the_board() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	dispatch.adventurers.roster["maren"]["rank"] = "E"
	var board := _board(dispatch, 0)
	var seen_ranks := {}
	var now := START
	for i: int in 30:
		for quest: String in board.slots:
			seen_ranks[Dispatch.QUESTS[quest]["rank"]] = true
		now += 3_600
		assert_true(board.send(dispatch, board.slots[i % 3], ["maren"], 1, gold, now, NO_HALLS), str(i))
		now += 3_600
		dispatch.checkpoint(now, gold)
		board.refill(dispatch, now, NO_HALLS)
	assert_eq(seen_ranks, {"F": true, "E": true, "D": true})


func test_one_refill_after_an_absence_gives_the_board_refilling_every_second_gives_whatever_the_ranks_sent() -> void:
	_sent_ranks.clear()
	# Cartographer (F) sent, then the sealed door (E): cartographer's slot comes due at START + 600
	# while the sealed door is still out.
	var sends: Array = [[START, 1, ["bram"]], [START + 500, 0, ["ilse"]]]
	var away := _play(sends, NO_HALLS, START + 1_000, 0)
	assert_eq(away.slots[0], "")
	assert_ne(away.slots[1], "")
	assert_ne(away.slots[1], "sealed_door")
	assert_eq(_play(sends, NO_HALLS, START + 1_000, 1).slots, away.slots)
	# Overlapping outings, a Quest hall finished while away, and slots of each rank coming due while
	# away.
	sends = [
		[START, 0, ["bram"]],
		[START + 100, 1, ["ilse"]],
		[START + 150, 2, ["tobin"]],
		[START + 800, 1, ["maren"]],
		[START + 2_000, 0, ["bram"]],
		[START + 2_100, 3, ["ilse"]],
	]
	var halls := PackedInt64Array([START + 1_000])
	away = _play(sends, halls, START + 6_000, 0)
	assert_eq(away.slots, _play(sends, halls, START + 6_000, 1).slots)
	assert_eq(away.slots, _play(sends, halls, START + 6_000, 7).slots)
	assert_eq(away.filled(), 4)
	# A guild of rank E, sending rank D quests too.
	sends = [[START, 1, ["bram"]], [START + 100, 0, ["ilse"]], [START + 200, 2, ["tobin"]], [START + 2_000, 0, ["maren"]]]
	away = _play(sends, NO_HALLS, START + 8_000, 0, "E")
	assert_eq(away.slots, _play(sends, NO_HALLS, START + 8_000, 1, "E").slots)
	assert_eq(away.filled(), 3)
	assert_eq(_sent_ranks, {"F": true, "E": true, "D": true})
	# Fourteen slots: a slot with nothing free takes rats when its party is back, while away.
	var rats := _board(Dispatch.new(START), 11).slots.find("rats")
	sends = [[START + 100, rats, ["bram"]], [START + 110, 0, ["ilse"]]]
	away = _play(sends, _halls(11), START + 5_000, 0)
	assert_eq(away.slots[13], "rats")
	assert_eq(away.slots[0], "")
	assert_eq(_play(sends, _halls(11), START + 5_000, 1).slots, away.slots)


func test_a_quest_not_on_the_board_cannot_be_sent() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	for quest: String in ["rats", ""]:
		assert_false(board.send(dispatch, quest, ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_true(dispatch.outings.is_empty())
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_a_party_the_dispatch_refuses_leaves_the_quest_on_the_board() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_false(board.send(dispatch, "sealed_door", [], 1, gold, START + 100, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_clock_set_back_neither_undoes_a_refill_nor_restarts_a_countdown() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "cartographer", ["bram"], 1, gold, START + 100, NO_HALLS))
	dispatch.checkpoint(START + 700, gold)
	board.refill(dispatch, START + 700, NO_HALLS)
	var refilled := board.slots[1]
	assert_ne(refilled, "")
	assert_true(board.send(dispatch, "sealed_door", ["ilse"], 1, gold, START + 800, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["", refilled, "crypt"]))
	# Set back to before the first refill: it stays, and the second countdown runs on from where it was.
	dispatch.checkpoint(START + 200, gold)
	board.refill(dispatch, START + 200, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["", refilled, "crypt"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 200), 1_800)
	# Its time seen once, a clock set back again doesn't hold the refill off.
	dispatch.checkpoint(START + 2_600, gold)
	board.refill(dispatch, START + 300, NO_HALLS)
	assert_ne(board.slots[0], "")


func test_the_same_save_always_refills_the_same_way() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "cartographer", ["bram"], 1, gold, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "sealed_door", ["ilse"], 1, gold, START + 500, NO_HALLS))
	dispatch.checkpoint(START + 550, gold)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Board.load_or_start(SAVE_PATH)
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, START + 550)
	assert_eq(loaded.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(loaded.seconds_to_refill(1, loaded_dispatch, START + 550), 150)
	# Away until the sealed door is back: the save alone says it was out when slot 1 came due.
	loaded_dispatch.checkpoint(START + 1_000, gold)
	for refilled: Board in [loaded, Board.load_or_start(SAVE_PATH)]:
		refilled.refill(loaded_dispatch, START + 1_000, NO_HALLS)
		assert_eq(refilled.slots, PackedStringArray(["", "lurker", "crypt"]))
	# The slot and its refill time pick the quest: refilled at other times, the slot draws others.
	var drawn := {}
	for seconds: int in 10:
		var later := Board.load_or_start(SAVE_PATH)
		later.refill_at[1] += seconds
		later.refill(loaded_dispatch, START + 1_000, NO_HALLS)
		drawn[later.slots[1]] = true
	assert_gt(drawn.size(), 1)


func test_a_save_from_before_slots_starts_with_every_slot_filled() -> void:
	var file := ConfigFile.new()
	file.set_value("board", "day", 11)
	file.set_value("board", "used", PackedStringArray(["letters", "goblins"]))
	assert_eq(file.save(SAVE_PATH), OK)
	var board := Board.load_or_start(SAVE_PATH)
	board.refill(Dispatch.new(START), START, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_a_save_from_before_ranked_countdowns_with_old_quests_on_the_board_and_out_loads_and_plays_on() -> void:
	# The previous build: six quests, one countdown of an hour, goblins out with Bram and Ilse.
	var gold := Gold.new(40)
	var dispatch := Dispatch.new(START)
	assert_true(dispatch.send("goblins", ["bram", "ilse"], 1, gold, START))
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	file.set_value("board", "slots", PackedStringArray(["letters", "", "rats"]))
	file.set_value("board", "refill_at", PackedInt64Array([START, START + 3_600, START]))
	var back_at: Dictionary[String, int] = {"goblins": START + 600}
	file.set_value("board", "back_at", back_at)
	file.set_value("board", "checked_at", START)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	var loaded := Dispatch.load_or_start(SAVE_PATH, START + 3_599)
	var board := Board.load_or_start(SAVE_PATH)
	loaded.checkpoint(START + 3_599, loaded_gold)
	board.refill(loaded, START + 3_599, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["letters", "", "rats"]))
	assert_eq(loaded.debriefs.size(), 1)
	assert_eq(loaded_gold.amount, 40 + int(loaded.debriefs[0]["gold"]))
	# The saved countdown runs out when it said; an old quest sends, and its slot counts down by rank.
	loaded.checkpoint(START + 3_600, loaded_gold)
	board.refill(loaded, START + 3_600, NO_HALLS)
	assert_ne(board.slots[1], "")
	assert_true(board.send(loaded, "letters", ["tobin"], 1, loaded_gold, START + 3_600, NO_HALLS))
	assert_eq(board.seconds_to_refill(0, loaded, START + 3_600), 600)
