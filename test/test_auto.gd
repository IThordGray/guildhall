extends GutTest

## Shown chance low ends for the starters (Dispatch.chance_range), which these tests are built on:
## Bram and Tobin: rats 82, well 72, letters 50, spiders 55, cartographer 55, mouth 55, moonherbs 50,
## wolves 29. Ilse and Maren: well 85, cartographer 55, moonherbs 54. Gold: rats 3, well 5, letters 7,
## spiders 7, cartographer 8, mouth 8, moonherbs 10, wolves 22.

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]

var _dispatch: Dispatch
var _parties: Parties
## Bram and Tobin's party, then Ilse and Maren's, in that order.
var _first: String
var _second: String


func before_each() -> void:
	_dispatch = Dispatch.new(1_000)
	_dispatch.adventurers = Adventurers.new(EVERYONE)
	_parties = _dispatch.adventurers.parties
	assert_true(_parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	assert_true(_parties.move("maren", _parties.party_of("ilse"), _dispatch))
	_first = _parties.party_of("bram")
	_second = _parties.party_of("ilse")


# A board of `quests` in that order, each put there at `at`.
func _board(quests: Array[String], at: int) -> Board:
	var board := Board.new()
	board.reception_slots = quests.size()
	board.slots = PackedStringArray(quests)
	board.refill_at.resize(quests.size())
	board.filled_at.resize(quests.size())
	board.filled_at.fill(at)
	board.checked_at = at
	return board


# Turns Auto on for the party with `id`, in `mode`.
func _auto(id: String, mode: String = Parties.SAFE) -> void:
	_parties.set_auto(id, true)
	_parties.set_mode(id, mode)


# The quest and the time the party with `id` left on, as [quest, since]; [] while home.
func _out(id: String) -> Array:
	for outing: Dictionary in _dispatch.outings:
		if outing["party_id"] == id:
			return [outing["quest"], outing["since"]]
	return []


func test_auto_is_off_and_safe_until_set_both_are_saved_and_a_save_from_before_auto_loads_with_it_off() -> void:
	assert_false(_parties.auto(_first))
	assert_eq(_parties.mode(_first), Parties.SAFE)
	_auto(_first, Parties.BOLD)
	var file := ConfigFile.new()
	_parties.write(file)
	var again := ConfigFile.new()
	assert_eq(again.parse(file.encode_to_text()), OK)
	var loaded := Parties.read(again, [])
	assert_true(loaded.auto(_first))
	assert_eq(loaded.mode(_first), Parties.BOLD)
	assert_false(loaded.auto(_second))
	assert_eq(loaded.mode(_second), Parties.SAFE)
	var old := ConfigFile.new()
	old.set_value("parties", "parties", [{"id": "party_1", "name": "The Iron Wolves", "seed": 1, "members": PackedStringArray(["bram"])}])
	old.set_value("parties", "next_id", 2)
	var from_old := Parties.read(old, [])
	assert_false(from_old.auto("party_1"))
	assert_eq(from_old.mode("party_1"), Parties.SAFE)


func test_a_party_with_auto_on_takes_a_quest_at_the_check_and_one_with_auto_off_stays_home_until_turned_on() -> void:
	var board := _board(["well", "moonherbs"], 1_000)
	_auto(_first)
	Auto.checkpoint(_dispatch, board, 1_000, PackedInt64Array())
	assert_eq(_out(_first), ["well", 1_000])
	assert_eq(_out(_second), [])
	# Turned on while ready, at 1_001: it goes at that check.
	Auto.checkpoint(_dispatch, board, 1_001, PackedInt64Array())
	_auto(_second, Parties.BOLD)
	Auto.checkpoint(_dispatch, board, 1_001, PackedInt64Array())
	assert_eq(_out(_second), ["moonherbs", 1_001])


# The quest Bram and Tobin's party takes in `mode` from a board of `quests` at 1_000; "" for none.
func _taken(mode: String, quests: Array[String]) -> String:
	before_each()
	_auto(_first, mode)
	Auto.checkpoint(_dispatch, _board(quests, 1_000), 1_000, PackedInt64Array())
	return "" if _out(_first).is_empty() else _out(_first)[0]


func test_safe_takes_the_best_paying_quest_with_a_low_end_of_at_least_70_and_bold_at_least_40() -> void:
	# Not the surest (rats), nor the best paying (wolves, 29), nor, on Safe, moonherbs (50).
	assert_eq(_taken(Parties.SAFE, ["rats", "well", "moonherbs", "wolves"]), "well")
	assert_eq(_taken(Parties.BOLD, ["rats", "well", "moonherbs", "wolves"]), "moonherbs")
	# None good enough: it stays home.
	assert_eq(_taken(Parties.SAFE, ["moonherbs", "wolves"]), "")


func test_a_tie_on_gold_goes_to_the_higher_low_end_then_the_earlier_slot() -> void:
	# Letters (50) and spiders (55) both pay 7.
	assert_eq(_taken(Parties.BOLD, ["letters", "spiders"]), "spiders")
	# The cartographer and the mouth both pay 8, at 55.
	assert_eq(_taken(Parties.BOLD, ["mouth", "cartographer"]), "mouth")
	assert_eq(_taken(Parties.BOLD, ["cartographer", "mouth"]), "cartographer")


func test_a_party_takes_no_quest_above_what_its_rank_allows() -> void:
	# Strong enough for the maze (D, 87 gold), but at rank F it takes the wolves (E, 22 gold).
	for adventurer: String in ["bram", "tobin"]:
		for stat: String in Adventurers.STATS:
			_dispatch.adventurers.stats[adventurer][stat] = 60
	_dispatch.revealed.append("maze")
	_auto(_first, Parties.BOLD)
	Auto.checkpoint(_dispatch, _board(["maze", "wolves"], 1_000), 1_000, PackedInt64Array())
	assert_eq(_out(_first), ["wolves", 1_000])
	# At rank E, one below the maze's, it takes the maze.
	_dispatch.outings.clear()
	for adventurer: String in ["bram", "tobin"]:
		_dispatch.adventurers.roster[adventurer]["rank"] = "E"
	Auto.checkpoint(_dispatch, _board(["maze", "wolves"], 1_000), 1_000, PackedInt64Array())
	assert_eq(_out(_first), ["maze", 1_000])


func test_a_party_goes_the_moment_every_member_is_home_at_full_health_and_not_injured() -> void:
	var board := _board(["well"], 1_000)
	_auto(_first)
	# Bram is 9 short of full at 1_000, full at 1_006; Tobin is injured until 1_010.
	_dispatch.wounds["bram"] = {"health": _dispatch.adventurers.max_health("bram") - 9, "at": 1_000}
	_dispatch.injured_until["tobin"] = 1_010
	# Back at 1_013 from the well, which takes 3 seconds.
	Auto.checkpoint(_dispatch, board, 1_012, PackedInt64Array())
	assert_eq(_out(_first), ["well", 1_010])


func test_a_party_with_someone_training_or_loot_waiting_stays_home_until_that_ends() -> void:
	var board := _board(["well"], 1_000)
	_auto(_first)
	_dispatch.training["tobin"] = 1_000
	Auto.checkpoint(_dispatch, board, 1_005, PackedInt64Array())
	assert_eq(_out(_first), [])
	_dispatch.stop_training("tobin", 1_005)
	_dispatch.waiting_loot.append({"quest": "rats", "party": PackedStringArray(["bram", "tobin"]), "item": "belt"})
	Auto.checkpoint(_dispatch, board, 1_010, PackedInt64Array())
	assert_eq(_out(_first), [])
	_dispatch.let_loot_go(0)
	Auto.checkpoint(_dispatch, board, 1_010, PackedInt64Array())
	assert_eq(_out(_first), ["well", 1_010])


func test_with_no_quest_good_enough_it_waits_and_goes_when_the_board_changes() -> void:
	# Ilse and Maren on Bold: the wolves (10) won't do. The wolves leave at 1_120 and the slot
	# refills 60 seconds later, with the town well (85).
	var board := _board(["wolves"], 1_000)
	_auto(_second, Parties.BOLD)
	Auto.checkpoint(_dispatch, board, 1_100, PackedInt64Array())
	assert_eq(_out(_second), [])
	Auto.checkpoint(_dispatch, board, 1_181, PackedInt64Array())
	assert_eq(_out(_second), ["well", 1_180])


func test_parties_ready_together_pick_in_party_order_and_a_quest_one_takes_is_gone_for_the_next() -> void:
	var board := _board(["cartographer", "well", "moonherbs"], 1_000)
	_auto(_first, Parties.BOLD)
	_auto(_second, Parties.BOLD)
	Auto.checkpoint(_dispatch, board, 1_000, PackedInt64Array())
	assert_eq(_out(_first), ["moonherbs", 1_000])
	assert_eq(_out(_second), ["cartographer", 1_000])


func test_turning_auto_off_while_out_lets_the_party_finish_its_quest_and_stay_home() -> void:
	var board := _board(["well", "rats"], 1_000)
	_auto(_first)
	Auto.checkpoint(_dispatch, board, 1_000, PackedInt64Array())
	assert_eq(_out(_first), ["well", 1_000])
	Auto.checkpoint(_dispatch, board, 1_001, PackedInt64Array())
	_parties.set_auto(_first, false)
	Auto.checkpoint(_dispatch, board, 1_050, PackedInt64Array())
	# Back from the well at 1_003, home, with the rats still on the board.
	assert_eq(_dispatch.tries, {"well": 1})
	assert_eq(_out(_first), [])
	assert_has(board.slots, "rats")
	# With Auto on, it would have taken them.
	_parties.set_auto(_first, true)
	Auto.checkpoint(_dispatch, board, 1_050, PackedInt64Array())
	assert_eq(_out(_first), ["rats", 1_050])


func test_a_party_with_auto_on_can_still_be_sent_by_hand() -> void:
	var board := _board(["moonherbs"], 1_000)
	_auto(_first)
	Auto.checkpoint(_dispatch, board, 1_000, PackedInt64Array())
	assert_eq(_out(_first), [])
	assert_true(board.send(_dispatch, "moonherbs", PackedStringArray(["bram", "tobin"]), 7, 1_000, PackedInt64Array()))
	assert_eq(_out(_first), ["moonherbs", 1_000])


# Everything the guild and board save, as text: gold, XP, health, stash, loot waiting, board, outings.
func _saved(board: Board) -> String:
	var file := ConfigFile.new()
	_dispatch.gold.write(file)
	_dispatch.write(file)
	board.write(file)
	return file.encode_to_text()


# Bram and Tobin on Safe and Ilse and Maren on Bold from 1_000, with a fresh board of three slots, a
# stash with room for 40 more items, a Map room finished at 1_600 and an Infirmary at 2_800, and a
# Quest hall adding a slot at 4_600.
func _two_auto_parties() -> Board:
	# The same party names each time.
	seed(7)
	before_each()
	_auto(_first)
	_auto(_second, Parties.BOLD)
	_dispatch.adventurers.gear.stash_cap = _dispatch.adventurers.gear.stash.size() + 40
	var board := Board.new()
	board.reception_slots = 3
	board.refill(_dispatch, 1_000, PackedInt64Array())
	return board


# How many quests parties have come back from.
func _quests_done() -> int:
	var total := 0
	for quest: String in _dispatch.tries:
		total += _dispatch.tries[quest]
	return total


func test_one_checkpoint_after_hours_away_gives_exactly_what_checkpointing_every_second_gives() -> void:
	var end := 1_000 + 3 * 3_600
	var halls := PackedInt64Array([4_600])
	var away := _two_auto_parties()
	Auto.checkpoint(_dispatch, away, end, halls, 2_800, 1_600)
	var once := _saved(away)
	var watched := _two_auto_parties()
	# The quests done when the full stash first stops a party.
	var done_at_first_stop := -1
	for second: int in range(1_000, end + 1):
		Auto.checkpoint(_dispatch, watched, second, halls, 2_800, 1_600)
		if done_at_first_stop == -1 and not _dispatch.waiting_loot.is_empty():
			done_at_first_stop = _quests_done()
	assert_eq(_saved(watched), once)
	# What it played out: a full stash stopped one party, and the other went on questing.
	assert_gt(done_at_first_stop, 100)
	assert_gt(_quests_done(), done_at_first_stop)
	assert_false(_dispatch.waiting_loot.is_empty())


func test_the_same_save_plays_out_the_same_whatever_the_global_generator_gives() -> void:
	var results: Array[String] = []
	for global_seed: int in [1, 2]:
		var board := _two_auto_parties()
		seed(global_seed)
		Auto.checkpoint(_dispatch, board, 1_000 + 3_600, PackedInt64Array())
		results.append(_saved(board))
	assert_eq(results[0], results[1])
	assert_gt(_dispatch.tries.size(), 0)
