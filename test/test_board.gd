extends GutTest

const SAVE_PATH: String = "user://test_board_save.cfg"
## Unix seconds a new board in these tests is first filled at, and the slots it fills with: rank F,
## E and E quests.
const START: int = 1_000_000
const START_SLOTS: Array[String] = ["moonherbs", "wolves", "crypt"]
const NO_HALLS: PackedInt64Array = []
const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
## Every quest a guild whose best adventurer is rank F can take: ranks F and E.
const F_AND_E_QUESTS: Array[String] = [
	"cartographer", "crypt", "goblins", "letters", "lurker", "moonherbs", "mouth", "pilgrims", "rats",
	"sealed_door", "spiders", "well", "wolves",
]

## The ranks of the quests _play has sent, as keys.
var _sent_ranks: Dictionary = {}
## The quests whose challenges were known at the end of the last _play, sorted.
var _revealed: Array[String] = []


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _four(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


## An empty board with the three slots a guild saved before guild ranks has with no Quest hall.
func _old_board() -> Board:
	var board := Board.new()
	board.reception_slots = 3
	return board


## The board saved at SAVE_PATH, loaded for a guild saved before guild ranks.
func _load_old_board() -> Board:
	var board := Board.load_or_start(SAVE_PATH)
	board.reception_slots = 3
	return board


## A board filled at START against `dispatch` for a guild of `guild_rank`, with `quest_halls` Quest
## halls finished by then.
func _board(dispatch: Dispatch, quest_halls: int, guild_rank: String = "F") -> Board:
	var board := _old_board()
	board.refill(dispatch, START, _halls(quest_halls), -1, guild_rank)
	return board


## The finish times of `count` Quest halls, all finished at START.
func _halls(count: int) -> PackedInt64Array:
	var done := PackedInt64Array()
	done.resize(count)
	done.fill(START)
	return done


## A guild whose four starters are all of `rank`.
func _guild(rank: String) -> Dispatch:
	var dispatch := _four(START)
	for adventurer: String in dispatch.adventurers.roster:
		dispatch.adventurers.roster[adventurer]["rank"] = rank
	return dispatch


## A seed with which `party` on `quest` succeeds, or fails when `success` is false.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var chance := _four(0).success_chance(quest, party)
	for roll_seed: int in 10_000:
		if Outcome.roll(roll_seed, chance, 0, party, Adventurers.STARTERS).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


## Plays a game from START to `end` for a guild of `rank` whose starters are all of it: each send in
## `sends`, as [unix seconds, slot, party], sends that slot's quest; Quest halls finish at `halls`.
## With `step` above 0 the board is refilled every `step` seconds as well, as while the app is
## open; with 0, only at the sends and at `end`, as when the player is away in between. The first
## Map room finishes at `map_room`, -1 for none. The board at `end`.
func _play(sends: Array, halls: PackedInt64Array, end: int, step: int, rank: String = "F", map_room: int = -1) -> Board:
	var gold := Gold.new(0)
	var dispatch := _guild(rank)
	var board := _old_board()
	board.refill(dispatch, START, _done_by(halls, START), map_room, rank)
	var now := START
	for send: Array in sends + [[end, -1, []]]:
		while step > 0 and now + step < send[0]:
			now += step
			dispatch.checkpoint(now)
			board.refill(dispatch, now, _done_by(halls, now), map_room, rank)
		now = send[0]
		if send[1] >= 0:
			# The board the player picks from.
			dispatch.checkpoint(now)
			while not dispatch.debriefs.is_empty(): dispatch.read_debrief(0, gold)
			board.refill(dispatch, now, _done_by(halls, now), map_room, rank)
			var party: PackedStringArray = send[2]
			var quest := board.slots[send[1]]
			assert_true(board.send(dispatch, quest, party, 1, now, _done_by(halls, now), -1, map_room, rank), str(send))
			_sent_ranks[Dispatch.QUESTS[quest]["rank"]] = true
	dispatch.checkpoint(end)
	board.refill(dispatch, end, _done_by(halls, end), map_room, rank)
	_revealed.assign(dispatch.revealed)
	_revealed.sort()
	return board


## The finish times in `halls` no later than `now`, as the hall knows them at `now`.
func _done_by(halls: PackedInt64Array, now: int) -> PackedInt64Array:
	var done := PackedInt64Array()
	for at: int in halls:
		if at <= now:
			done.append(at)
	return done


func test_a_new_games_board_fills_two_slots_and_a_quest_hall_adds_a_third() -> void:
	var dispatch := Dispatch.new(START)
	var board := Board.new()
	board.refill(dispatch, START, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS.slice(0, 2)))
	board.refill(dispatch, START + 1_380, PackedInt64Array([START + 1_380]))
	assert_eq(board.slots.size(), 3)
	assert_eq(board.filled(), 3)
	assert_eq(board.slots.slice(0, 2), PackedStringArray(START_SLOTS.slice(0, 2)))


func test_a_board_saved_before_guild_ranks_fills_three_slots_plus_one_per_quest_hall_without_changing_the_others() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	assert_eq(board.filled(), 3)
	board.refill(dispatch, START + 1_379, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	board.refill(dispatch, START + 1_380, PackedInt64Array([START + 1_380]))
	assert_eq(board.slots, PackedStringArray(["moonherbs", "wolves", "crypt", "rats"]))
	assert_eq(board.filled(), 4)


func test_the_board_never_shows_a_quest_twice_and_leaves_a_slot_empty_when_none_is_free() -> void:
	# Fourteen slots, thirteen quests a new guild can take.
	var board := _board(_four(START), 11)
	assert_eq(board.slots.size(), 14)
	assert_eq(board.filled(), 13)
	assert_eq(board.slots[13], "")
	var shown: Array[String] = []
	shown.assign(board.slots.slice(0, 13))
	shown.sort()
	assert_eq(shown, F_AND_E_QUESTS)


func test_a_sent_quests_slot_refills_after_a_countdown_set_by_its_rank_f_20_seconds_e_60_and_d_120() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "moonherbs", ["bram"], 1, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "wolves", ["ilse"], 1, START + 100, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 100), 20)
	assert_eq(board.seconds_to_refill(1, dispatch, START + 100), 60)
	dispatch.checkpoint(START + 119)
	board.refill(dispatch, START + 119, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 119), 1)
	dispatch.checkpoint(START + 120)
	board.refill(dispatch, START + 120, NO_HALLS)
	assert_ne(board.slots[0], "")
	assert_eq(board.slots[1], "")
	dispatch.checkpoint(START + 159)
	board.refill(dispatch, START + 159, NO_HALLS)
	assert_eq(board.slots[1], "")
	dispatch.checkpoint(START + 160)
	board.refill(dispatch, START + 160, NO_HALLS)
	assert_ne(board.slots[1], "")
	# A rank D quest, for a rank-E guild with someone rank E.
	var ranked := _guild("E")
	var ranked_board := _board(ranked, 0, "E")
	assert_eq(Dispatch.QUESTS[ranked_board.slots[1]]["rank"], "D")
	assert_true(ranked_board.send(ranked, ranked_board.slots[1], ["bram"], 1, START + 100, NO_HALLS, -1, -1, "E"))
	assert_eq(ranked_board.seconds_to_refill(1, ranked, START + 100), 120)


func test_each_slot_counts_down_on_its_own() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "moonherbs", ["bram"], 1, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "wolves", ["ilse"], 1, START + 105, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 105), 15)
	assert_eq(board.seconds_to_refill(1, dispatch, START + 105), 60)
	board.refill(dispatch, START + 120, NO_HALLS)
	assert_ne(board.slots[0], "")
	assert_eq(board.slots[1], "")
	assert_eq(board.seconds_to_refill(1, dispatch, START + 120), 45)
	board.refill(dispatch, START + 165, NO_HALLS)
	assert_ne(board.slots[1], "")
	assert_ne(board.slots[1], board.slots[0])


func test_the_next_refill_is_the_soonest_empty_slots_countdown_and_none_while_no_slot_is_empty() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_eq(board.seconds_to_next_refill(dispatch, START), -1)
	# Slot 1 empties first but counts down longer: rank E, 60 seconds, against slot 0's rank F, 20.
	assert_true(board.send(dispatch, "wolves", ["ilse"], 1, START + 100, NO_HALLS))
	assert_eq(board.seconds_to_next_refill(dispatch, START + 100), 60)
	assert_true(board.send(dispatch, "moonherbs", ["bram"], 1, START + 110, NO_HALLS))
	assert_eq(board.seconds_to_next_refill(dispatch, START + 110), 20)
	board.refill(dispatch, START + 130, NO_HALLS)
	assert_ne(board.slots[0], "")
	assert_eq(board.seconds_to_next_refill(dispatch, START + 130), 30)
	board.refill(dispatch, START + 160, NO_HALLS)
	assert_eq(board.filled(), 3)
	assert_eq(board.seconds_to_next_refill(dispatch, START + 160), -1)


func test_an_empty_slot_waiting_for_a_free_quest_gives_way_to_a_slot_counting_down_else_the_next_refill_is_0() -> void:
	var dispatch := _four(START)
	# Fourteen slots, thirteen quests: the last slot is due and waits for a quest to be free.
	var board := _board(dispatch, 11)
	assert_eq(board.slots[13], "")
	assert_eq(board.seconds_to_next_refill(dispatch, START), 0)
	assert_true(board.send(dispatch, "rats", ["bram"], 1, START + 100, _halls(11)))
	assert_eq(board.seconds_to_next_refill(dispatch, START + 100), 20)


func test_a_quest_out_is_not_offered_and_an_empty_slot_takes_it_once_its_party_is_back() -> void:
	var dispatch := _four(START)
	# Fourteen slots, thirteen quests: every quest on the board, the last slot empty.
	var board := _board(dispatch, 11)
	var shown := board.slots.duplicate()
	var rats := shown.find("rats")
	assert_ne(rats, -1)
	assert_eq(shown[13], "")
	# Rats takes two seconds: out from START + 100 to START + 102.
	assert_true(board.send(dispatch, "rats", ["bram"], _seed("rats", ["bram"], true), START + 100, _halls(11)))
	shown[rats] = ""
	assert_eq(board.slots, shown)
	dispatch.checkpoint(START + 101)
	board.refill(dispatch, START + 101, _halls(11))
	assert_eq(board.slots, shown)
	assert_eq(board.seconds_to_refill(13, dispatch, START + 101), 0)
	dispatch.checkpoint(START + 102)
	board.refill(dispatch, START + 102, _halls(11))
	shown[13] = "rats"
	assert_eq(board.slots, shown)
	# Rats' own slot comes due with nothing free, so it stays empty.
	board.refill(dispatch, START + 3_700, _halls(11))
	assert_eq(board.slots, shown)


func test_a_rank_f_guild_is_offered_every_rank_f_and_e_quest_in_turn_never_one_twice_and_never_rank_d() -> void:
	var gold := Gold.new(0)
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	var seen := {}
	var now := START
	for i: int in 100:
		now += 3_600
		assert_true(board.send(dispatch, board.slots[i % 3], ["bram"], 1, now, NO_HALLS))
		now += 3_600
		dispatch.checkpoint(now)
		while not dispatch.debriefs.is_empty(): dispatch.read_debrief(0, gold)
		board.refill(dispatch, now, NO_HALLS)
		assert_false(board.slots.has(""), str(i))
		for quest: String in board.slots:
			assert_eq(board.slots.count(quest), 1, str(i))
			seen[quest] = true
	var offered: Array[String] = []
	offered.assign(seen.keys())
	offered.sort()
	assert_eq(offered, F_AND_E_QUESTS)


func test_with_one_rank_e_adventurer_rank_d_quests_reach_a_rank_e_guilds_board() -> void:
	var gold := Gold.new(0)
	var dispatch := _four(START)
	dispatch.adventurers.roster["maren"]["rank"] = "E"
	var board := _board(dispatch, 0, "E")
	var seen_ranks := {}
	var now := START
	for i: int in 30:
		for quest: String in board.slots:
			seen_ranks[Dispatch.QUESTS[quest]["rank"]] = true
		now += 3_600
		assert_true(board.send(dispatch, board.slots[i % 3], ["maren"], 1, now, NO_HALLS, -1, -1, "E"), str(i))
		now += 3_600
		dispatch.checkpoint(now)
		while not dispatch.debriefs.is_empty(): dispatch.read_debrief(0, gold)
		board.refill(dispatch, now, NO_HALLS, -1, "E")
	assert_eq(seen_ranks, {"F": true, "E": true, "D": true})


## How many of 1_000 fills draw each rank for a guild of `guild_rank` whose starters are all of
## `adventurer_rank`: each fill a one-slot board filled at its own second.
func _ranks_drawn(guild_rank: String, adventurer_rank: String) -> Dictionary:
	var drawn := {"F": 0, "E": 0, "D": 0}
	var dispatch := _guild(adventurer_rank)
	for i: int in 1_000:
		var board := Board.new()
		board.reception_slots = 1
		board.refill(dispatch, START + i, NO_HALLS, -1, guild_rank)
		drawn[Dispatch.QUESTS[board.slots[0]]["rank"]] += 1
	return drawn


func test_a_rank_f_guilds_board_is_about_four_in_five_rank_f_the_rest_rank_e_and_never_rank_d_even_with_rank_e_adventurers() -> void:
	# Rank-E adventurers could take rank D quests, so only the guild's rank keeps them off.
	var drawn := _ranks_drawn("F", "E")
	assert_between(drawn["F"], 700, 850)
	assert_eq(drawn["E"], 1_000 - drawn["F"])
	assert_gt(drawn["E"], 0)
	assert_eq(drawn["D"], 0)


func test_a_rank_e_guild_draws_rank_d_only_once_an_adventurer_is_rank_e_sharing_the_rest_by_weight() -> void:
	var capped := _ranks_drawn("E", "F")
	assert_eq(capped["D"], 0)
	# Rank F's 10 of the 80 left: about one in eight.
	assert_between(capped["F"], 80, 170)
	assert_eq(capped["E"], 1_000 - capped["F"])
	var uncapped := _ranks_drawn("E", "E")
	# Rank D's 20 of 100.
	assert_between(uncapped["D"], 150, 250)
	assert_between(uncapped["F"], 60, 140)


func test_one_refill_after_an_absence_gives_the_board_refilling_every_second_gives_whatever_the_ranks_sent() -> void:
	_sent_ranks.clear()
	# Moonherbs (F) sent, then wolves (E): moonherbs' slot comes due at START + 20 while the wolves
	# are still out.
	var sends: Array = [[START, 0, ["bram"]], [START + 15, 1, ["ilse"]]]
	var away := _play(sends, NO_HALLS, START + 22, 0)
	assert_eq(away.slots[1], "")
	assert_ne(away.slots[0], "")
	assert_ne(away.slots[0], "wolves")
	assert_eq(_play(sends, NO_HALLS, START + 22, 1).slots, away.slots)
	# Overlapping outings, a Quest hall finished while away, and slots of each rank coming due while
	# away.
	sends = [
		[START, 0, ["bram"]],
		[START + 3, 1, ["ilse"]],
		[START + 5, 2, ["tobin"]],
		[START + 27, 0, ["maren"]],
		[START + 70, 1, ["bram"]],
		[START + 75, 3, ["ilse"]],
	]
	var halls := PackedInt64Array([START + 33])
	away = _play(sends, halls, START + 200, 0)
	assert_eq(away.slots, _play(sends, halls, START + 200, 1).slots)
	assert_eq(away.slots, _play(sends, halls, START + 200, 7).slots)
	assert_eq(away.filled(), 4)
	# A guild of rank E, sending rank D and F quests too.
	sends = [[START, 1, ["bram"]], [START + 18, 0, ["ilse"]], [START + 25, 2, ["tobin"]], [START + 80, 0, ["maren"]]]
	away = _play(sends, NO_HALLS, START + 300, 0, "E")
	assert_eq(away.slots, _play(sends, NO_HALLS, START + 300, 1, "E").slots)
	assert_eq(away.filled(), 3)
	assert_eq(_sent_ranks, {"F": true, "E": true, "D": true})
	# Fourteen slots: a slot with nothing free takes rats when its party is back, while away.
	var rats := _board(_four(START), 11).slots.find("rats")
	sends = [[START + 100, rats, ["bram"]], [START + 110, 0, ["ilse"]]]
	away = _play(sends, _halls(11), START + 5_000, 0)
	assert_eq(away.slots[13], "rats")
	assert_eq(away.slots[0], "")
	assert_eq(_play(sends, _halls(11), START + 5_000, 1).slots, away.slots)


func test_a_quest_not_on_the_board_cannot_be_sent() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	for quest: String in ["rats", ""]:
		assert_false(board.send(dispatch, quest, ["bram"], 1, START + 100, NO_HALLS))
	assert_true(dispatch.outings.is_empty())
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_a_party_the_dispatch_refuses_leaves_the_quest_on_the_board() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_false(board.send(dispatch, "wolves", [], 1, START + 100, NO_HALLS))
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_clock_set_back_neither_undoes_a_refill_nor_restarts_a_countdown() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "moonherbs", ["bram"], 1, START + 100, NO_HALLS))
	dispatch.checkpoint(START + 120)
	board.refill(dispatch, START + 120, NO_HALLS)
	var refilled := board.slots[0]
	assert_ne(refilled, "")
	assert_true(board.send(dispatch, "wolves", ["ilse"], 1, START + 125, NO_HALLS))
	assert_eq(board.slots, PackedStringArray([refilled, "", "crypt"]))
	# Set back to before the first refill: it stays, and the second countdown runs on from where it was.
	dispatch.checkpoint(START + 105)
	board.refill(dispatch, START + 105, NO_HALLS)
	assert_eq(board.slots, PackedStringArray([refilled, "", "crypt"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 105), 60)
	# Its time seen once, a clock set back again doesn't hold the refill off.
	dispatch.checkpoint(START + 200)
	board.refill(dispatch, START + 110, NO_HALLS)
	assert_ne(board.slots[1], "")


func test_the_same_save_always_refills_the_same_way() -> void:
	var gold := Gold.new(0)
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "moonherbs", ["bram"], 1, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "wolves", ["ilse"], 1, START + 115, NO_HALLS))
	dispatch.checkpoint(START + 117)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := _load_old_board()
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, START + 117)
	assert_eq(loaded.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(loaded.seconds_to_refill(0, loaded_dispatch, START + 117), 3)
	# Away until the wolves are back: the save alone says they were out when slot 0 came due.
	loaded_dispatch.checkpoint(START + 130)
	for refilled: Board in [loaded, _load_old_board()]:
		refilled.refill(loaded_dispatch, START + 130, NO_HALLS)
		assert_eq(refilled.slots, PackedStringArray(["moonherbs", "", "crypt"]))
	# The slot and its refill time pick the quest: refilled at other times, the slot draws others.
	var drawn := {}
	for seconds: int in 10:
		var later := _load_old_board()
		later.refill_at[0] += seconds
		later.refill(loaded_dispatch, START + 130, NO_HALLS)
		drawn[later.slots[0]] = true
	assert_gt(drawn.size(), 1)


func test_a_save_from_before_slots_starts_with_every_slot_filled() -> void:
	var file := ConfigFile.new()
	file.set_value("board", "day", 11)
	file.set_value("board", "used", PackedStringArray(["letters", "goblins"]))
	assert_eq(file.save(SAVE_PATH), OK)
	var board := _load_old_board()
	board.refill(_four(START), START, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))


func test_a_save_from_before_ranked_countdowns_with_old_quests_on_the_board_and_out_loads_and_plays_on() -> void:
	# The previous build: six quests, one countdown of an hour, goblins out with Bram and Ilse.
	var gold := Gold.new(40)
	var dispatch := _four(START)
	assert_true(dispatch.send("goblins", ["bram", "ilse"], 1, START))
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
	var board := _load_old_board()
	loaded.checkpoint(START + 3_599)
	board.refill(loaded, START + 3_599, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["letters", "", "rats"]))
	assert_eq(loaded.debriefs.size(), 1)
	var reward: int = loaded.debriefs[0]["gold"]
	loaded.read_debrief(0, loaded_gold)
	assert_eq(loaded_gold.amount, 40 + reward)
	# The saved countdown runs out when it said; an old quest sends, and its slot counts down by rank.
	loaded.checkpoint(START + 3_600)
	board.refill(loaded, START + 3_600, NO_HALLS)
	assert_ne(board.slots[1], "")
	assert_true(board.send(loaded, "letters", ["tobin"], 1, START + 3_600, NO_HALLS))
	assert_eq(board.seconds_to_refill(0, loaded, START + 3_600), 20)


## When the first Map room finished in most tests below: before the board was first filled.
const MAP_ROOM_EARLY: int = START - 1_000


func test_without_a_finished_map_room_no_challenge_is_revealed_however_long_a_quest_waits() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	board.refill(dispatch, START + 100_000, NO_HALLS)
	# A Map room under way, finishing at START + 150_000.
	board.refill(dispatch, START + 149_999, NO_HALLS, START + 150_000)
	for quest: String in START_SLOTS:
		assert_eq(dispatch.unknown_challenges(quest).size(), 1, quest)
		assert_eq(board.seconds_to_reveal(quest, dispatch, START + 149_999), -1, quest)
	# Once it is finished, they are revealed in time.
	board.refill(dispatch, START + 150_010, NO_HALLS, START + 150_000)
	for quest: String in START_SLOTS:
		assert_true(dispatch.unknown_challenges(quest).is_empty(), quest)


func test_with_a_map_room_finished_a_quest_is_revealed_exactly_10_seconds_after_it_was_put_on_the_board() -> void:
	var dispatch := _four(START)
	var board := _old_board()
	board.refill(dispatch, START, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.seconds_to_reveal("crypt", dispatch, START), 10)
	board.refill(dispatch, START + 9, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.seconds_to_reveal("crypt", dispatch, START + 9), 1)
	for quest: String in START_SLOTS:
		assert_eq(dispatch.unknown_challenges(quest).size(), 1, quest)
	board.refill(dispatch, START + 10, NO_HALLS, MAP_ROOM_EARLY)
	for quest: String in START_SLOTS:
		assert_true(dispatch.unknown_challenges(quest).is_empty(), quest)
		assert_eq(board.seconds_to_reveal(quest, dispatch, START + 10), -1, quest)
	# A quest put on the board later counts from when it was put there: crypt's slot refills at
	# START + 80.
	assert_true(board.send(dispatch, "crypt", ["bram"], 1, START + 20, NO_HALLS, -1, MAP_ROOM_EARLY))
	dispatch.checkpoint(START + 89)
	board.refill(dispatch, START + 89, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.slots[2], "pilgrims")
	assert_eq(dispatch.unknown_challenges("pilgrims"), PackedStringArray(["Attrition"]))
	assert_eq(board.seconds_to_reveal("pilgrims", dispatch, START + 89), 1)
	board.refill(dispatch, START + 90, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("pilgrims").is_empty())


func test_a_quest_on_the_board_before_the_map_room_finished_is_revealed_10_seconds_after_the_room_finishes() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	var map_room := START + 1_000
	board.refill(dispatch, START + 1_009, NO_HALLS, map_room)
	assert_eq(board.seconds_to_reveal("wolves", dispatch, START + 1_009), 1)
	assert_eq(dispatch.unknown_challenges("wolves"), PackedStringArray(["Attrition"]))
	board.refill(dispatch, START + 1_010, NO_HALLS, map_room)
	assert_true(dispatch.unknown_challenges("wolves").is_empty())


func test_a_quest_the_map_room_revealed_stays_revealed_while_out_and_back_on_the_board() -> void:
	var dispatch := _four(START)
	# Fourteen slots, thirteen quests: every quest on the board, the last slot empty.
	var board := _old_board()
	board.refill(dispatch, START, _halls(11), MAP_ROOM_EARLY)
	assert_eq(board.slots[13], "")
	board.refill(dispatch, START + 10, _halls(11), MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("sealed_door").is_empty())
	# The sealed door takes twelve seconds: out from START + 400 to START + 412.
	assert_true(board.send(dispatch, "sealed_door", ["bram"], 1, START + 400, _halls(11), -1, MAP_ROOM_EARLY))
	dispatch.checkpoint(START + 411)
	board.refill(dispatch, START + 411, _halls(11), MAP_ROOM_EARLY)
	assert_false(board.slots.has("sealed_door"))
	assert_true(dispatch.unknown_challenges("sealed_door").is_empty())
	# Back, it takes the empty slot, its challenges known from the moment it is put there.
	dispatch.checkpoint(START + 412)
	board.refill(dispatch, START + 412, _halls(11), MAP_ROOM_EARLY)
	assert_eq(board.slots[13], "sealed_door")
	assert_true(dispatch.unknown_challenges("sealed_door").is_empty())
	assert_eq(board.seconds_to_reveal("sealed_door", dispatch, START + 412), -1)
	# Its return had nothing left to reveal.
	assert_eq(dispatch.debriefs.size(), 1)
	assert_eq(dispatch.debriefs[0]["revealed"], PackedStringArray())


func test_a_quest_sent_before_its_reveal_is_not_revealed_by_the_map_room_but_by_its_return() -> void:
	var dispatch := _four(START)
	var board := _old_board()
	board.refill(dispatch, START, NO_HALLS, MAP_ROOM_EARLY)
	# Moonherbs takes six seconds: out from START + 9 to START + 15.
	assert_true(board.send(dispatch, "moonherbs", ["bram"], 1, START + 9, NO_HALLS, -1, MAP_ROOM_EARLY))
	dispatch.checkpoint(START + 14)
	board.refill(dispatch, START + 14, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("wolves").is_empty())
	assert_eq(dispatch.unknown_challenges("moonherbs"), PackedStringArray(["Attrition"]))
	assert_eq(board.seconds_to_reveal("moonherbs", dispatch, START + 14), -1)
	dispatch.checkpoint(START + 15)
	assert_eq(dispatch.debriefs[0]["revealed"], PackedStringArray(["Attrition"]))
	assert_true(dispatch.unknown_challenges("moonherbs").is_empty())


func test_one_refill_after_an_absence_reveals_what_refilling_every_second_reveals() -> void:
	# The Map room finishes at START + 15, revealing the first slots at START + 25. Moonherbs is
	# sent before then, and its return reveals it; the wolves are sent after. Their slots refill at
	# START + 24 with spiders, revealed at START + 34, and at START + 90 with letters, revealed at
	# START + 100.
	var map_room := START + 15
	var sends: Array = [[START + 4, 0, ["bram"]], [START + 30, 1, ["ilse"]]]
	var expected := {
		START + 99: ["crypt", "moonherbs", "spiders", "wolves"],
		START + 100: ["crypt", "letters", "moonherbs", "spiders", "wolves"],
	}
	for end: int in expected:
		var away := _play(sends, NO_HALLS, end, 0, "F", map_room)
		assert_eq(away.slots, PackedStringArray(["spiders", "letters", "crypt"]), str(end))
		assert_eq(_revealed, expected[end], str(end))
		var watched := _play(sends, NO_HALLS, end, 1, "F", map_room)
		assert_eq(watched.slots, away.slots, str(end))
		assert_eq(_revealed, expected[end], str(end))


func test_a_clock_set_back_neither_restarts_a_reveal_countdown_nor_undoes_a_reveal() -> void:
	var dispatch := _four(START)
	var board := _old_board()
	board.refill(dispatch, START, NO_HALLS, MAP_ROOM_EARLY)
	board.refill(dispatch, START + 6, NO_HALLS, MAP_ROOM_EARLY)
	# Set back to START + 2: the countdown runs on from the time already seen.
	board.refill(dispatch, START + 2, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.seconds_to_reveal("crypt", dispatch, START + 2), 4)
	assert_eq(dispatch.unknown_challenges("crypt").size(), 1)
	board.refill(dispatch, START + 10, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("crypt").is_empty())
	board.refill(dispatch, START + 1, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("crypt").is_empty())


func test_fill_times_and_reveals_survive_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := _four(START)
	var board := _old_board()
	board.refill(dispatch, START, NO_HALLS, MAP_ROOM_EARLY)
	# The wolves are revealed at START + 10; crypt's slot takes pilgrims at START + 80, to be revealed
	# at START + 90.
	assert_true(board.send(dispatch, "crypt", ["bram"], 1, START + 20, NO_HALLS, -1, MAP_ROOM_EARLY))
	dispatch.checkpoint(START + 85)
	board.refill(dispatch, START + 85, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.slots[2], "pilgrims")
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := _load_old_board()
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, START + 85)
	assert_true(loaded_dispatch.unknown_challenges("wolves").is_empty())
	loaded.refill(loaded_dispatch, START + 89, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(loaded.seconds_to_reveal("pilgrims", loaded_dispatch, START + 89), 1)
	assert_eq(loaded_dispatch.unknown_challenges("pilgrims"), PackedStringArray(["Attrition"]))
	loaded.refill(loaded_dispatch, START + 90, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(loaded_dispatch.unknown_challenges("pilgrims").is_empty())


func test_a_save_from_before_fill_times_reveals_its_board_counting_from_when_it_was_last_refilled() -> void:
	var file := ConfigFile.new()
	file.set_value("board", "slots", PackedStringArray(["letters", "", "rats"]))
	file.set_value("board", "refill_at", PackedInt64Array([START, START + 3_600, START]))
	var back_at: Dictionary[String, int] = {}
	file.set_value("board", "back_at", back_at)
	file.set_value("board", "checked_at", START + 100)
	assert_eq(file.save(SAVE_PATH), OK)
	var dispatch := _four(START + 100)
	var board := _load_old_board()
	board.refill(dispatch, START + 109, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.seconds_to_reveal("letters", dispatch, START + 109), 1)
	assert_eq(dispatch.unknown_challenges("letters"), PackedStringArray(["Protect"]))
	board.refill(dispatch, START + 110, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("letters").is_empty())
