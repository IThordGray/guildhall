extends GutTest

const Fixtures := preload("res://test/fixtures.gd")

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
	board.refill(dispatch, START, _halls(quest_halls), PackedInt64Array(), PackedInt64Array(), guild_rank)
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
		if Outcome.roll(roll_seed, chance, 0, party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


## Plays a game from START to `end` for a guild of `rank` whose starters are all of it: each send in
## `sends`, as [unix seconds, slot, party], sends that slot's quest; Quest halls finish at `halls`.
## With `step` above 0 the board is refilled every `step` seconds as well, as while the app is
## open; with 0, only at the sends and at `end`, as when the player is away in between. The first
## Map room finishes at `map_room`, -1 for none. The board at `end`.
func _play(sends: Array, halls: PackedInt64Array, end: int, step: int, rank: String = "F", map_room: int = -1) -> Board:
	var map_tiers := PackedInt64Array() if map_room < 0 else PackedInt64Array([map_room])
	var dispatch := _guild(rank)
	var board := _old_board()
	board.refill(dispatch, START, _done_by(halls, START), map_tiers, PackedInt64Array(), rank)
	var now := START
	for send: Array in sends + [[end, -1, []]]:
		while step > 0 and now + step < send[0]:
			now += step
			dispatch.checkpoint(now)
			board.refill(dispatch, now, _done_by(halls, now), map_tiers, PackedInt64Array(), rank)
		now = send[0]
		if send[1] >= 0:
			# The board the player picks from.
			dispatch.checkpoint(now)
			while not dispatch.waiting_loot.is_empty(): dispatch.let_loot_go(0)
			board.refill(dispatch, now, _done_by(halls, now), map_tiers, PackedInt64Array(), rank)
			var party: PackedStringArray = send[2]
			var quest := board.slots[send[1]]
			assert_true(board.send(dispatch, quest, Fixtures.party(dispatch, party), 1, now, _done_by(halls, now), PackedInt64Array(), map_tiers, PackedInt64Array(), rank), str(send))
			_sent_ranks[Dispatch.QUESTS[quest]["rank"]] = true
	dispatch.checkpoint(end)
	board.refill(dispatch, end, _done_by(halls, end), map_tiers, PackedInt64Array(), rank)
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
	board.refill(dispatch, START + 30, PackedInt64Array([START + 30]))
	assert_eq(board.slots.size(), 3)
	assert_eq(board.filled(), 3)
	assert_eq(board.slots.slice(0, 2), PackedStringArray(START_SLOTS.slice(0, 2)))


func test_a_board_saved_before_guild_ranks_fills_three_slots_plus_one_per_quest_hall_without_changing_the_others() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	assert_eq(board.filled(), 3)
	board.refill(dispatch, START + 29, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	board.refill(dispatch, START + 30, PackedInt64Array([START + 30]))
	assert_eq(board.slots, PackedStringArray(["moonherbs", "wolves", "crypt", "lurker"]))
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
	assert_true(board.send(dispatch, "moonherbs", Fixtures.party(dispatch, ["bram"]), 1, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "wolves", Fixtures.party(dispatch, ["ilse"]), 1, START + 100, NO_HALLS))
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
	assert_true(ranked_board.send(ranked, ranked_board.slots[1], Fixtures.party(ranked, ["bram"]), 1, START + 100, NO_HALLS, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "E"))
	assert_eq(ranked_board.seconds_to_refill(1, ranked, START + 100), 120)


func test_each_slot_counts_down_on_its_own() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "moonherbs", Fixtures.party(dispatch, ["bram"]), 1, START + 100, NO_HALLS))
	assert_true(board.send(dispatch, "wolves", Fixtures.party(dispatch, ["ilse"]), 1, START + 105, NO_HALLS))
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
	assert_true(board.send(dispatch, "wolves", Fixtures.party(dispatch, ["ilse"]), 1, START + 10, NO_HALLS))
	assert_eq(board.seconds_to_next_refill(dispatch, START + 10), 60)
	assert_true(board.send(dispatch, "moonherbs", Fixtures.party(dispatch, ["bram"]), 1, START + 20, NO_HALLS))
	assert_eq(board.seconds_to_next_refill(dispatch, START + 20), 20)
	board.refill(dispatch, START + 40, NO_HALLS)
	assert_ne(board.slots[0], "")
	assert_eq(board.seconds_to_next_refill(dispatch, START + 40), 30)
	board.refill(dispatch, START + 70, NO_HALLS)
	assert_eq(board.filled(), 3)
	assert_eq(board.seconds_to_next_refill(dispatch, START + 70), -1)


func test_an_empty_slot_waiting_for_a_free_quest_gives_way_to_a_slot_counting_down_else_the_next_refill_is_0() -> void:
	var dispatch := _four(START)
	# Fourteen slots, thirteen quests: the last slot is due and waits for a quest to be free.
	var board := _board(dispatch, 11)
	assert_eq(board.slots[13], "")
	assert_eq(board.seconds_to_next_refill(dispatch, START), 0)
	assert_true(board.send(dispatch, "rats", Fixtures.party(dispatch, ["bram"]), 1, START + 100, _halls(11)))
	assert_eq(board.seconds_to_next_refill(dispatch, START + 100), 20)


func test_a_quest_out_is_not_offered_and_an_empty_slot_takes_it_once_its_party_is_back() -> void:
	var dispatch := _four(START)
	# Fourteen slots, thirteen quests: every quest on the board, the last slot empty.
	var board := _board(dispatch, 11)
	var shown := board.slots.duplicate()
	var rats := shown.find("rats")
	assert_ne(rats, -1)
	assert_eq(shown[13], "")
	# Rats takes two seconds: out from START + 10 to START + 12.
	assert_true(board.send(dispatch, "rats", Fixtures.party(dispatch, ["bram"]), _seed("rats", ["bram"], true), START + 10, _halls(11)))
	shown[rats] = ""
	assert_eq(board.slots, shown)
	dispatch.checkpoint(START + 11)
	board.refill(dispatch, START + 11, _halls(11))
	assert_eq(board.slots, shown)
	assert_eq(board.seconds_to_refill(13, dispatch, START + 11), 0)
	dispatch.checkpoint(START + 12)
	board.refill(dispatch, START + 12, _halls(11))
	shown[13] = "rats"
	assert_eq(board.slots, shown)
	# Rats' own slot comes due at START + 30 with nothing free, so it stays empty until the first
	# quests leave the board, at START + 60.
	board.refill(dispatch, START + 59, _halls(11))
	assert_eq(board.slots, shown)


## The first second from `now` on at which `board`, refilled to it for a guild of `rank`, shows a
## quest: every slot can be between its quest leaving and its refill at once.
func _until_a_quest(board: Board, dispatch: Dispatch, now: int, rank: String = "F") -> int:
	var at := now
	board.refill(dispatch, at, NO_HALLS, PackedInt64Array(), PackedInt64Array(), rank)
	while board.filled() == 0:
		at += 1
		board.refill(dispatch, at, NO_HALLS, PackedInt64Array(), PackedInt64Array(), rank)
	return at


## The quest in `board`'s first filled slot from `slot` on, going round.
func _quest_from(board: Board, slot: int) -> String:
	for i: int in board.slots.size():
		var quest := board.slots[(slot + i) % board.slots.size()]
		if quest != "":
			return quest
	return ""


func test_a_rank_f_guild_is_offered_every_rank_f_and_e_quest_in_turn_never_one_twice_and_never_rank_d() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	var seen := {}
	var now := START
	for i: int in 100:
		now = _until_a_quest(board, dispatch, now + 3_600)
		assert_true(board.send(dispatch, _quest_from(board, i % 3), Fixtures.party(dispatch, ["bram"]), 1, now, NO_HALLS))
		now += 3_600
		dispatch.checkpoint(now)
		while not dispatch.waiting_loot.is_empty(): dispatch.let_loot_go(0)
		board.refill(dispatch, now, NO_HALLS)
		for quest: String in board.slots:
			if quest != "":
				assert_eq(board.slots.count(quest), 1, str(i))
				seen[quest] = true
	var offered: Array[String] = []
	offered.assign(seen.keys())
	offered.sort()
	assert_eq(offered, F_AND_E_QUESTS)


func test_with_one_rank_e_party_rank_d_quests_reach_a_rank_e_guilds_board() -> void:
	var dispatch := _four(START)
	dispatch.adventurers.roster["maren"]["rank"] = "E"
	Fixtures.party(dispatch, ["maren"])
	var board := _board(dispatch, 0, "E")
	var seen_ranks := {}
	var now := START
	for i: int in 30:
		for quest: String in board.slots:
			if quest != "":
				seen_ranks[Dispatch.QUESTS[quest]["rank"]] = true
		now = _until_a_quest(board, dispatch, now + 3_600, "E")
		assert_true(board.send(dispatch, _quest_from(board, i % 3), ["maren"], 1, now, NO_HALLS, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "E"), str(i))
		now += 3_600
		dispatch.checkpoint(now)
		while not dispatch.waiting_loot.is_empty(): dispatch.let_loot_go(0)
		board.refill(dispatch, now, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "E")
	assert_eq(seen_ranks, {"F": true, "E": true, "D": true})


# How many of 200 one-slot boards, each filled at its own second against `dispatch` for a rank-E
# guild, draw a rank D quest.
func _rank_d_drawn(dispatch: Dispatch) -> int:
	var drawn := 0
	for i: int in 200:
		var board := Board.new()
		board.reception_slots = 1
		board.refill(dispatch, START + i, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "E")
		if Dispatch.QUESTS[board.slots[0]]["rank"] == "D":
			drawn += 1
	return drawn


func test_the_board_reaches_one_rank_above_the_highest_ranked_party_reserves_not_counted_and_no_party_counts_as_f() -> void:
	var dispatch := _four(START)
	dispatch.adventurers.roster["maren"]["rank"] = "E"
	# With three rank-F members, Maren's party is rank F: no rank D quest.
	assert_eq(_rank_d_drawn(dispatch), 0)
	# In reserve, her rank E counts for nothing.
	assert_true(dispatch.adventurers.parties.move("maren", Parties.RESERVES, dispatch))
	assert_eq(_rank_d_drawn(dispatch), 0)
	# A party of her own is rank E.
	assert_true(dispatch.adventurers.parties.move("maren", Parties.NEW_PARTY, dispatch))
	assert_gt(_rank_d_drawn(dispatch), 0)
	# With nobody in a party, the board is a rank-F party's, whatever the reserves' ranks.
	for adventurer: String in dispatch.adventurers.roster:
		dispatch.adventurers.roster[adventurer]["rank"] = "E"
		assert_true(dispatch.adventurers.parties.move(adventurer, Parties.RESERVES, dispatch))
	assert_true(dispatch.adventurers.parties.parties.is_empty())
	assert_eq(_rank_d_drawn(dispatch), 0)
	assert_true(dispatch.adventurers.parties.move("bram", Parties.NEW_PARTY, dispatch))
	assert_gt(_rank_d_drawn(dispatch), 0)


## How many of 1_000 fills draw each rank for a guild of `guild_rank` whose starters are all of
## `adventurer_rank`: each fill a one-slot board filled at its own second.
func _ranks_drawn(guild_rank: String, adventurer_rank: String) -> Dictionary:
	var drawn := {"F": 0, "E": 0, "D": 0}
	var dispatch := _guild(adventurer_rank)
	for i: int in 1_000:
		var board := Board.new()
		board.reception_slots = 1
		board.refill(dispatch, START + i, NO_HALLS, PackedInt64Array(), PackedInt64Array(), guild_rank)
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
	# The Quest hall's slot added, and one slot between its quest leaving and its refill.
	assert_eq(away.slots.size(), 4)
	assert_eq(away.filled(), 3)
	# A guild of rank E, sending rank D and F quests too.
	sends = [[START, 1, ["bram"]], [START + 18, 0, ["ilse"]], [START + 25, 2, ["tobin"]], [START + 80, 0, ["maren"]]]
	away = _play(sends, NO_HALLS, START + 300, 0, "E")
	assert_eq(away.slots, _play(sends, NO_HALLS, START + 300, 1, "E").slots)
	assert_eq(away.filled(), 3)
	assert_eq(_sent_ranks, {"F": true, "E": true, "D": true})
	# Fourteen slots: a slot with nothing free takes rats when its party is back, while away.
	var rats := _board(_four(START), 11).slots.find("rats")
	# Rats is back at START + 12 and moonherbs at START + 17; rats' slot then takes moonherbs at
	# START + 30, and moonherbs' slot finds nothing free at START + 31 until the first quests leave
	# the board, at START + 60.
	sends = [[START + 10, rats, ["bram"]], [START + 11, 0, ["ilse"]]]
	away = _play(sends, _halls(11), START + 59, 0)
	assert_eq(away.slots[13], "rats")
	assert_eq(away.slots[0], "")
	assert_eq(_play(sends, _halls(11), START + 59, 1).slots, away.slots)


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
	assert_true(board.send(dispatch, "moonherbs", Fixtures.party(dispatch, ["bram"]), 1, START + 10, NO_HALLS))
	dispatch.checkpoint(START + 30)
	board.refill(dispatch, START + 30, NO_HALLS)
	var refilled := board.slots[0]
	assert_ne(refilled, "")
	assert_true(board.send(dispatch, "wolves", Fixtures.party(dispatch, ["ilse"]), 1, START + 35, NO_HALLS))
	assert_eq(board.slots, PackedStringArray([refilled, "", "crypt"]))
	# Set back to before the first refill: it stays, and the second countdown runs on from where it was.
	dispatch.checkpoint(START + 15)
	board.refill(dispatch, START + 15, NO_HALLS)
	assert_eq(board.slots, PackedStringArray([refilled, "", "crypt"]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 15), 60)
	# Its time seen once, a clock set back again doesn't hold the refill off.
	dispatch.checkpoint(START + 110)
	board.refill(dispatch, START + 20, NO_HALLS)
	assert_ne(board.slots[1], "")


func test_the_same_save_always_refills_the_same_way() -> void:
	var gold := Gold.new(0)
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_true(board.send(dispatch, "moonherbs", Fixtures.party(dispatch, ["bram"]), 1, START + 10, NO_HALLS))
	assert_true(board.send(dispatch, "wolves", Fixtures.party(dispatch, ["ilse"]), 1, START + 25, NO_HALLS))
	dispatch.checkpoint(START + 27)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	board.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := _load_old_board()
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, START + 27)
	assert_eq(loaded.slots, PackedStringArray(["", "", "crypt"]))
	assert_eq(loaded.seconds_to_refill(0, loaded_dispatch, START + 27), 3)
	# Away until the wolves are back: the save alone says they were out when slot 0 came due.
	loaded_dispatch.checkpoint(START + 40)
	for refilled: Board in [loaded, _load_old_board()]:
		refilled.refill(loaded_dispatch, START + 40, NO_HALLS)
		assert_eq(refilled.slots, PackedStringArray(["sealed_door", "", "crypt"]))
	# The slot and its refill time pick the quest: refilled at other times, the slot draws others.
	var drawn := {}
	for seconds: int in 10:
		var later := _load_old_board()
		later.refill_at[0] += seconds
		later.refill(loaded_dispatch, START + 40, NO_HALLS)
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
	assert_true(dispatch.send("goblins", Fixtures.party(dispatch, ["bram", "ilse"]), 1, START))
	var success := Outcome.roll(1, dispatch.outings[0]["chance"], 0, PackedStringArray(["bram", "ilse"])).success
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
	# Loaded before the old quests leave the board, a minute after the save.
	var loaded := Dispatch.load_or_start(SAVE_PATH, START + 59)
	loaded.gold = loaded_gold
	var board := _load_old_board()
	loaded.checkpoint(START + 59)
	board.refill(loaded, START + 59, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["letters", "", "rats"]))
	assert_true(loaded.outings.is_empty())
	assert_eq(loaded_gold.amount, 82 if success else 40)
	# An old quest sends, and its slot counts down by rank; the saved countdown runs out when it said.
	assert_true(board.send(loaded, "letters", Fixtures.party(loaded, ["tobin"]), 1, START + 59, NO_HALLS))
	assert_eq(board.seconds_to_refill(0, loaded, START + 59), 20)
	loaded.checkpoint(START + 3_599)
	board.refill(loaded, START + 3_599, NO_HALLS)
	assert_eq(board.slots[1], "")
	loaded.checkpoint(START + 3_600)
	board.refill(loaded, START + 3_600, NO_HALLS)
	assert_ne(board.slots[1], "")


## When the first Map room finished in most tests below: before the board was first filled.
const MAP_ROOM_EARLY: PackedInt64Array = [START - 1_000]


func test_without_a_finished_map_room_no_challenge_is_revealed_however_long_a_quest_waits() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	# As long as the quests stay on the board: the first leaves at START + 60.
	board.refill(dispatch, START + 39, NO_HALLS)
	# A Map room under way, finishing at START + 40.
	board.refill(dispatch, START + 39, NO_HALLS, PackedInt64Array([START + 40]))
	for quest: String in START_SLOTS:
		assert_eq(dispatch.unknown_challenges(quest).size(), 1, quest)
		assert_eq(board.seconds_to_reveal(quest, dispatch, START + 39), -1, quest)
	# Once it is finished, they are revealed in time.
	board.refill(dispatch, START + 50, NO_HALLS, PackedInt64Array([START + 40]))
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
	assert_true(board.send(dispatch, "crypt", Fixtures.party(dispatch, ["bram"]), 1, START + 20, NO_HALLS, PackedInt64Array(), MAP_ROOM_EARLY))
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
	var map_room := PackedInt64Array([START + 1_000])
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
	# The sealed door takes twelve seconds: out from START + 20 to START + 32.
	assert_true(board.send(dispatch, "sealed_door", Fixtures.party(dispatch, ["bram"]), 1, START + 20, _halls(11), PackedInt64Array(), MAP_ROOM_EARLY))
	dispatch.checkpoint(START + 31)
	board.refill(dispatch, START + 31, _halls(11), MAP_ROOM_EARLY)
	assert_false(board.slots.has("sealed_door"))
	assert_true(dispatch.unknown_challenges("sealed_door").is_empty())
	# Back, it takes the empty slot, its challenges known from the moment it is put there.
	dispatch.checkpoint(START + 32)
	board.refill(dispatch, START + 32, _halls(11), MAP_ROOM_EARLY)
	assert_eq(board.slots[13], "sealed_door")
	assert_true(dispatch.unknown_challenges("sealed_door").is_empty())
	assert_eq(board.seconds_to_reveal("sealed_door", dispatch, START + 32), -1)
	# Its return had nothing left to reveal.
	assert_true(dispatch.outings.is_empty())
	assert_eq(dispatch.revealed.count("sealed_door"), 1)


func test_a_quest_sent_before_its_reveal_is_not_revealed_by_the_map_room_but_by_its_return() -> void:
	var dispatch := _four(START)
	var board := _old_board()
	board.refill(dispatch, START, NO_HALLS, MAP_ROOM_EARLY)
	# Moonherbs takes six seconds: out from START + 9 to START + 15.
	assert_true(board.send(dispatch, "moonherbs", Fixtures.party(dispatch, ["bram"]), 1, START + 9, NO_HALLS, PackedInt64Array(), MAP_ROOM_EARLY))
	dispatch.checkpoint(START + 14)
	board.refill(dispatch, START + 14, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("wolves").is_empty())
	assert_eq(dispatch.unknown_challenges("moonherbs"), PackedStringArray(["Attrition"]))
	assert_eq(board.seconds_to_reveal("moonherbs", dispatch, START + 14), -1)
	dispatch.checkpoint(START + 15)
	assert_true(dispatch.unknown_challenges("moonherbs").is_empty())


func test_one_refill_after_an_absence_reveals_what_refilling_every_second_reveals() -> void:
	# The Map room finishes at START + 15, revealing the first slots at START + 25. Moonherbs is
	# sent before then, and its return reveals it; the wolves are sent after. Their slots refill at
	# START + 24 with spiders, revealed at START + 34 and leaving the board at START + 84, and at
	# START + 90 with letters, revealed at START + 100.
	var map_room := START + 15
	var sends: Array = [[START + 4, 0, ["bram"]], [START + 30, 1, ["ilse"]]]
	var expected := {
		START + 99: ["crypt", "moonherbs", "spiders", "wolves"],
		START + 100: ["crypt", "letters", "moonherbs", "spiders", "wolves"],
	}
	for end: int in expected:
		var away := _play(sends, NO_HALLS, end, 0, "F", map_room)
		assert_eq(away.slots, PackedStringArray(["", "letters", "crypt"]), str(end))
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
	assert_true(board.send(dispatch, "crypt", Fixtures.party(dispatch, ["bram"]), 1, START + 20, NO_HALLS, PackedInt64Array(), MAP_ROOM_EARLY))
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
	assert_eq(dispatch.unknown_challenges("letters"), PackedStringArray(["Negotiation"]))
	board.refill(dispatch, START + 110, NO_HALLS, MAP_ROOM_EARLY)
	assert_true(dispatch.unknown_challenges("letters").is_empty())


func test_a_quest_left_on_the_board_leaves_after_its_ranks_time_f_60_e_120_and_d_240_and_its_slot_refills_as_after_a_send() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	# Moonherbs is rank F, the wolves and the crypt rank E.
	assert_eq(board.seconds_to_leave("moonherbs", dispatch, START + 18), 42)
	assert_eq(board.seconds_to_leave("wolves", dispatch, START + 18), 102)
	assert_eq(board.seconds_to_leave("rats", dispatch, START + 18), -1)
	board.refill(dispatch, START + 59, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(START_SLOTS))
	board.refill(dispatch, START + 60, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["", "wolves", "crypt"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 60), 20)
	board.refill(dispatch, START + 79, NO_HALLS)
	assert_eq(board.slots[0], "")
	board.refill(dispatch, START + 80, NO_HALLS)
	assert_ne(board.slots[0], "")
	board.refill(dispatch, START + 119, NO_HALLS)
	assert_eq(board.slots.slice(1), PackedStringArray(["wolves", "crypt"]))
	board.refill(dispatch, START + 120, NO_HALLS)
	assert_eq(board.slots.slice(1), PackedStringArray(["", ""]))
	assert_eq(board.seconds_to_refill(1, dispatch, START + 120), 60)
	# A rank D quest, for a rank-E guild with someone rank E.
	var ranked := _guild("E")
	var ranked_board := _board(ranked, 0, "E")
	var rank_d := ranked_board.slots[1]
	assert_eq(Dispatch.QUESTS[rank_d]["rank"], "D")
	ranked_board.refill(ranked, START + 239, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "E")
	assert_eq(ranked_board.slots[1], rank_d)
	ranked_board.refill(ranked, START + 240, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "E")
	assert_eq(ranked_board.slots[1], "")
	assert_eq(ranked_board.seconds_to_refill(1, ranked, START + 240), 120)


func test_a_quest_that_left_the_board_is_free_to_be_drawn_again() -> void:
	var dispatch := _four(START)
	# Fourteen slots, thirteen quests: every quest on the board, the last slot waiting for one.
	var board := _board(dispatch, 11)
	var rank_f: Array[String] = []
	for quest: String in board.slots:
		if quest != "" and Dispatch.QUESTS[quest]["rank"] == "F":
			rank_f.append(quest)
	assert_eq(rank_f.size(), 7)
	board.refill(dispatch, START + 59, _halls(11))
	assert_eq(board.slots[13], "")
	# The rank F quests leave at START + 60, and the waiting slot takes one of them at once.
	board.refill(dispatch, START + 60, _halls(11))
	assert_true(board.slots[13] in rank_f, board.slots[13])
	assert_eq(board.filled_at[13], START + 60)


func test_one_refill_after_an_absence_gives_the_board_refilling_every_second_gives_through_several_expiries_and_refills() -> void:
	# Nothing sent: over twenty minutes every slot's quest leaves and refills several times.
	var end := START + 1_200
	var away := _play([], NO_HALLS, end, 0)
	var watched := _play([], NO_HALLS, end, 1)
	assert_eq(away.slots, watched.slots)
	assert_eq(away.filled_at, watched.filled_at)
	assert_eq(away.refill_at, watched.refill_at)
	for slot: int in 3:
		# Each slot's latest quest came long after the first ones left, at START + 120 at the latest.
		assert_gt(away.refill_at[slot], START + 900, str(slot))
	# Sends mixed in, a Quest hall finished while away, and a rank-E guild drawing rank D quests.
	var sends: Array = [[START + 5, 0, ["bram"]], [START + 30, 1, ["ilse"]], [START + 50, 2, ["tobin"]]]
	var halls := PackedInt64Array([START + 300])
	away = _play(sends, halls, end, 0, "E")
	watched = _play(sends, halls, end, 1, "E")
	assert_eq(away.slots, watched.slots)
	assert_eq(away.filled_at, watched.filled_at)
	assert_eq(_play(sends, halls, end, 13, "E").slots, away.slots)
	# Fourteen slots, thirteen quests: a slot waiting for a free quest takes one as soon as another
	# leaves the board, while away.
	var rats := _board(_four(START), 11).slots.find("rats")
	sends = [[START + 10, rats, ["bram"]], [START + 11, 0, ["ilse"]]]
	away = _play(sends, _halls(11), end, 0)
	watched = _play(sends, _halls(11), end, 1)
	assert_eq(away.slots, watched.slots)
	assert_eq(away.filled_at, watched.filled_at)


func test_a_clock_set_back_never_brings_back_a_quest_that_left_the_board() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	board.refill(dispatch, START + 70, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["", "wolves", "crypt"]))
	board.refill(dispatch, START + 30, NO_HALLS)
	assert_eq(board.slots, PackedStringArray(["", "wolves", "crypt"]))
	assert_eq(board.seconds_to_refill(0, dispatch, START + 30), 10)
	assert_eq(board.seconds_to_leave("wolves", dispatch, START + 30), 50)
	assert_false(board.send(dispatch, "moonherbs", ["bram"], 1, START + 30, NO_HALLS))


func test_a_quest_that_left_the_board_cannot_be_sent() -> void:
	var dispatch := _four(START)
	var board := _board(dispatch, 0)
	assert_false(board.send(dispatch, "moonherbs", Fixtures.party(dispatch, ["bram"]), 1, START + 60, NO_HALLS))
	assert_true(dispatch.outings.is_empty())
	assert_eq(board.slots, PackedStringArray(["", "wolves", "crypt"]))
	# A second before, it could be.
	var other := _four(START)
	var still := _board(other, 0)
	assert_true(still.send(other, "moonherbs", Fixtures.party(other, ["bram"]), 1, START + 59, NO_HALLS))


func test_the_map_room_reveals_only_quests_still_on_the_board_at_their_reveal_time() -> void:
	# The Map room finishes at START + 55, so the first quests' reveal comes at START + 65: the
	# wolves and the crypt are still there, moonherbs left at START + 60 and its slot refills at
	# START + 80.
	var map_room := START + 55
	for step: int in [0, 1]:
		_play([], NO_HALLS, START + 79, step, "F", map_room)
		assert_eq(_revealed, ["crypt", "wolves"] as Array[String], str(step))
	# A quest leaving the moment it would be revealed has left first.
	var dispatch := _four(START)
	var board := _old_board()
	board.refill(dispatch, START, NO_HALLS, PackedInt64Array([START + 50]))
	board.refill(dispatch, START + 61, NO_HALLS, PackedInt64Array([START + 50]))
	assert_eq(dispatch.unknown_challenges("moonherbs"), PackedStringArray(["Attrition"]))
	assert_true(dispatch.unknown_challenges("wolves").is_empty())


func test_the_boards_next_change_is_the_map_rooms_reveal_when_that_comes_first() -> void:
	# Moonherbs, the wolves and the crypt are put on the board at START: revealed at START + 10, and
	# the first to leave goes at START + 60.
	var dispatch := _four(START)
	var board := _old_board()
	board.refill(dispatch, START, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.next_change(dispatch, START), START + 10)
	board.refill(dispatch, START + 10, NO_HALLS, MAP_ROOM_EARLY)
	assert_eq(board.next_change(dispatch, START + 10), START + 60)
	# With no Map room, nothing is revealed: the first change is a quest leaving.
	var unmapped := _board(_four(START), 0)
	assert_eq(unmapped.next_change(_four(START), START), START + 60)


func test_a_redrawn_board_is_the_same_for_the_same_save_and_time_whatever_the_board_held() -> void:
	var at := START + 50_000
	var drawn: Array[PackedStringArray] = []
	# One board as first filled, one stepped through the day before.
	for step: int in [0, 997]:
		var dispatch := _four(START)
		var board := _board(dispatch, 0)
		for second: int in range(START, at, step if step > 0 else at - START):
			board.refill(dispatch, second, NO_HALLS)
		dispatch.checkpoint(at)
		board.redraw(dispatch, at, NO_HALLS)
		assert_eq(board.filled(), 3)
		assert_eq(board.filled_at, PackedInt64Array([at, at, at]))
		drawn.append(board.slots)
	assert_eq(drawn[0], drawn[1])
	# Drawn at other times, the board comes out otherwise.
	var boards := {}
	for seconds: int in 10:
		var dispatch := _four(START)
		var board := _board(dispatch, 0)
		board.redraw(dispatch, at + seconds, NO_HALLS)
		boards[str(board.slots)] = true
	assert_gt(boards.size(), 1)


func test_a_redrawn_board_fills_every_slot_its_halls_give_with_quests_the_guilds_ranks_allow_never_one_twice() -> void:
	var ranks_drawn := {}
	for rank: String in ["F", "E"]:
		for at: int in range(START + 10_000, START + 30_000, 997):
			var dispatch := _guild(rank)
			var board := _board(dispatch, 2, rank)
			board.redraw(dispatch, at, _halls(2), PackedInt64Array(), PackedInt64Array(), rank)
			assert_eq(board.slots.size(), 5)
			assert_eq(board.filled(), 5)
			for quest: String in board.slots:
				assert_eq(board.slots.count(quest), 1, quest)
				ranks_drawn[rank + Dispatch.QUESTS[quest]["rank"]] = true
				if rank == "F":
					assert_has(F_AND_E_QUESTS, quest)
	# A rank F guild is never offered rank D; a rank E guild of rank E adventurers is, and rank F too.
	assert_eq(ranks_drawn.keys().filter(func(key: String) -> bool: return key.begins_with("F")).size(), 2)
	assert_has(ranks_drawn, "ED")
	assert_has(ranks_drawn, "EF")


func test_a_redrawn_board_never_shows_a_quest_that_is_out() -> void:
	# Fourteen slots, thirteen quests: with the rats and the letters out, eleven are free.
	var dispatch := _four(START)
	var board := _board(dispatch, 11)
	assert_true(board.send(dispatch, "rats", Fixtures.party(dispatch, ["bram"]), 1, START + 1, _halls(11)))
	assert_true(board.send(dispatch, "letters", Fixtures.party(dispatch, ["ilse"]), 1, START + 1, _halls(11)))
	dispatch.checkpoint(START + 2)
	board.redraw(dispatch, START + 2, _halls(11))
	assert_eq(board.filled(), 11)
	assert_does_not_have(board.slots, "rats")
	assert_does_not_have(board.slots, "letters")
	# Back by START + 5, they go on the board.
	dispatch.checkpoint(START + 10)
	board.refill(dispatch, START + 10, _halls(11))
	assert_eq(board.filled(), 13)
	assert_has(board.slots, "rats")
	assert_has(board.slots, "letters")


func test_a_slot_draws_each_quest_at_its_ranks_weight_shared_among_that_ranks_quests() -> void:
	# A rank F guild: rank F 70 and rank E 20 of 90, among 7 and 6 quests; never rank D.
	var guild := _four(START).adventurers
	assert_almost_eq(Board.draw_chance("rats", guild, "F"), 70.0 / 90.0 / 7.0, 1e-9)
	assert_almost_eq(Board.draw_chance("wolves", guild, "F"), 20.0 / 90.0 / 6.0, 1e-9)
	assert_eq(Board.draw_chance("maze", guild, "F"), 0.0)
	# A rank E guild of rank E adventurers: F 10, E 70 and D 20 of 100, among 7, 6 and 5 quests.
	var ranked := _guild("E").adventurers
	assert_almost_eq(Board.draw_chance("rats", ranked, "E"), 10.0 / 100.0 / 7.0, 1e-9)
	assert_almost_eq(Board.draw_chance("wolves", ranked, "E"), 70.0 / 100.0 / 6.0, 1e-9)
	assert_almost_eq(Board.draw_chance("maze", ranked, "E"), 20.0 / 100.0 / 5.0, 1e-9)
