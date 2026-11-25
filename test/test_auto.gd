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
	_dispatch.adventurers.gear.stash_cap = 0
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


# The quests tried, sorted.
func _tried() -> Array:
	var quests := _dispatch.tries.keys()
	quests.sort()
	return quests


# A board of three slots, as a guild of `guild_rank` first fills it at `at`.
func _new_board(at: int, guild_rank: String = "F") -> Board:
	var board := Board.new()
	board.reception_slots = 3
	board.refill(_dispatch, at, PackedInt64Array(), -1, guild_rank)
	return board


func test_a_long_absence_draws_the_board_afresh_three_hours_before_now_then_plays_those_hours_exactly_as_watching() -> void:
	# Nobody with Auto, Bram and Tobin sent by hand at first: ten minutes settled, then three hours
	# played out, once or as one watching those hours from the board drawn afresh.
	var halls := PackedInt64Array([4_600])
	var end := 1_000 + 600 + Auto.REPLAY_SECONDS
	var away := _two_auto_parties()
	_parties.set_auto(_first, false)
	_parties.set_auto(_second, false)
	assert_true(away.send(_dispatch, away.slots[0], PackedStringArray(["bram", "tobin"]), 3, 1_000, halls, 2_800, 1_600))
	Auto.checkpoint(_dispatch, away, end, halls, 2_800, 1_600)
	var once := _saved(away)
	var watched := _two_auto_parties()
	_parties.set_auto(_first, false)
	_parties.set_auto(_second, false)
	assert_true(watched.send(_dispatch, watched.slots[0], PackedStringArray(["bram", "tobin"]), 3, 1_000, halls, 2_800, 1_600))
	_dispatch.checkpoint(1_600, 2_800)
	watched.redraw(_dispatch, 1_600, halls, 1_600)
	var drawn := watched.slots.duplicate()
	for second: int in range(1_600, end + 1, 5):
		Auto.checkpoint(_dispatch, watched, second, halls, 2_800, 1_600)
	assert_eq(_saved(watched), once)
	# The board changed through those hours, and the quest sent came back.
	assert_ne(watched.slots, drawn)
	assert_eq(_quests_done(), 1)
	# With Auto, three hours and a second away settle that first second, which playing it doesn't.
	var averaged := _two_auto_parties()
	Auto.checkpoint(_dispatch, averaged, 1_001 + Auto.REPLAY_SECONDS, halls, 2_800, 1_600)
	var stepped := _two_auto_parties()
	Auto.checkpoint(_dispatch, stepped, 1_001, halls, 2_800, 1_600)
	Auto.checkpoint(_dispatch, stepped, 1_001 + Auto.REPLAY_SECONDS, halls, 2_800, 1_600)
	assert_ne(_saved(stepped), _saved(averaged))


# The guild's gold and quests done, as [gold, quests].
func _gold_and_quests() -> Vector2:
	return Vector2(_dispatch.gold.amount, _quests_done())


# A fresh guild set up as `scenario` from `start`, with room for any loot; its guild rank.
func _scenario(scenario: String, start: int) -> String:
	before_each()
	_dispatch.checked_at = start
	_dispatch.adventurers.gear.stash_cap = 100_000
	match scenario:
		"one Safe party, guild F":
			_auto(_first)
		"two Bold parties, guild E":
			_auto(_first, Parties.BOLD)
			_auto(_second, Parties.BOLD)
			return "E"
		"three parties of both modes":
			assert_true(_parties.move("maren", Parties.NEW_PARTY, _dispatch))
			_auto(_first)
			_auto(_second, Parties.BOLD)
			_auto(_parties.party_of("maren"), Parties.BOLD)
	return "F"


# What `scenario` brings from `start` in 12 hours, as [gold, quests]: [played out, averaged]. Played:
# checkpointed every three hours, so exactly. Averaged: checkpointed once 15 hours on, so 12 hours
# settled and three played, those three taken off as playing them out brought them.
func _twelve_hours(scenario: String, start: int) -> Array[Vector2]:
	var guild_rank := _scenario(scenario, start)
	var board := _new_board(start, guild_rank)
	var played: Array[Vector2] = []
	for hours: int in [3, 6, 9, 12, 15]:
		Auto.checkpoint(_dispatch, board, start + hours * 3_600, PackedInt64Array(), -1, -1, guild_rank)
		played.append(_gold_and_quests())
	guild_rank = _scenario(scenario, start)
	Auto.checkpoint(_dispatch, _new_board(start, guild_rank), start + 15 * 3_600, PackedInt64Array(), -1, -1, guild_rank)
	return [played[3], _gold_and_quests() - (played[4] - played[3])]


func test_averaged_gold_and_quests_come_within_a_quarter_of_playing_the_same_twelve_hours() -> void:
	for scenario: String in ["one Safe party, guild F", "two Bold parties, guild E", "three parties of both modes"]:
		var played := Vector2()
		var averaged := Vector2()
		# Three saves, each played and averaged, added up, as one alone is noisy.
		for start: int in [1_000, 100_003, 200_017]:
			var both := _twelve_hours(scenario, start)
			played += both[0]
			averaged += both[1]
		var ratio := averaged / played
		gut.p("%s: gold %.2f, quests %.2f of playing (%s against %s)" % [scenario, ratio.x, ratio.y, averaged, played])
		assert_gt(played.y, 200.0, scenario)
		assert_between(ratio.x, 0.75, 1.25, scenario + ": gold")
		assert_between(ratio.y, 0.75, 1.25, scenario + ": quests")


# The reputation `scenario` earns from `start` in 12 hours, as [played out, averaged], each as
# `_twelve_hours` takes them.
func _twelve_hours_reputation(scenario: String, start: int) -> Vector2:
	var guild_rank := _scenario(scenario, start)
	var board := _new_board(start, guild_rank)
	var played: Array[int] = []
	for hours: int in [3, 6, 9, 12, 15]:
		Auto.checkpoint(_dispatch, board, start + hours * 3_600, PackedInt64Array(), -1, -1, guild_rank)
		played.append(_dispatch.reputation)
	guild_rank = _scenario(scenario, start)
	Auto.checkpoint(_dispatch, _new_board(start, guild_rank), start + 15 * 3_600, PackedInt64Array(), -1, -1, guild_rank)
	return Vector2(played[3], _dispatch.reputation - (played[4] - played[3]))


func test_averaged_reputation_comes_within_a_quarter_of_playing_the_same_twelve_hours() -> void:
	for scenario: String in ["one Safe party, guild F", "two Bold parties, guild E", "three parties of both modes"]:
		var both := Vector2()
		for start: int in [1_000, 100_003, 200_017]:
			both += _twelve_hours_reputation(scenario, start)
		var ratio := both.y / both.x
		gut.p("%s: reputation %.2f of playing (%d against %d)" % [scenario, ratio, both.y, both.x])
		assert_gt(both.x, 200.0, scenario)
		assert_between(ratio, 0.75, 1.25, scenario + ": reputation")


func test_a_long_absence_pays_an_auto_party_the_expected_gold_xp_and_tries_of_the_quests_the_board_offers_it() -> void:
	# Ilse and Maren on Safe take only the town well (shown 85–95): 3 seconds, a true 95%, 5 gold, 5 XP
	# shared (2 each on a success, 1 on a failure). With Spirit 12 and Luck 4 a member can expect
	# 0.95 × 4 × 0.76 + 0.05 × 12 × 0.76 × 0.92 = 3.30752 damage, healed in 2.20501 seconds.
	# Three slots draw a quest of rank F 7 in 9 times, E otherwise. Those nobody takes sit for 60 or
	# 120 seconds, on 0.837 of the other two slots at rank F, so a slot draws the well from 6.163 rank
	# F quests: 0.12621 of draws, a draw every 94.650 seconds, the well every 249.989 seconds across
	# the board. A cycle of 255.194 seconds, so 2_551_939 seconds hold 10_000 of them.
	_auto(_second)
	_dispatch.adventurers.gear.stash_cap = 5_000
	Auto.checkpoint(_dispatch, _new_board(1_000), 1_000 + 2_551_939 + Auto.REPLAY_SECONDS, PackedInt64Array())
	assert_eq(_tried(), ["well"])
	# The three hours played out add a well every four minutes or so.
	assert_between(_dispatch.tries["well"], 10_000, 10_080)
	assert_between(_dispatch.gold.amount, 47_500, 47_900)
	for member: String in ["ilse", "maren"]:
		assert_between(_dispatch.adventurers.xp[member], 19_500, 19_660, member)
	# 29% of returns bring an item, Luck 4 counted.
	assert_between(_dispatch.adventurers.gear.stash.size(), 2_900, 2_925)
	var qualities := {}
	for item: String in _dispatch.adventurers.gear.stash:
		qualities[Gear.ITEMS[item]["quality"]] = true
	# Drawn as any loot is: of every quality.
	assert_eq(qualities.size(), Gear.QUALITY_PERCENT.size())


func test_healing_twice_as_fast_from_the_infirmary_on_fits_more_averaged_quests() -> void:
	# Bram and Tobin on Bold take every rank F quest, one coming up every half minute or so, and heal
	# for a few seconds after each.
	var done: Array[int] = []
	for infirmary_from: int in [-1, 1_000]:
		before_each()
		_auto(_first, Parties.BOLD)
		_dispatch.adventurers.gear.stash_cap = 100_000
		Auto.checkpoint(_dispatch, _new_board(1_000), 1_000 + 10 * 86_400, PackedInt64Array(), infirmary_from)
		done.append(_quests_done())
	assert_gt(done[0], 15_000)
	assert_gt(done[1], done[0] + 400)


func test_a_party_averages_over_the_quests_its_rank_allows_the_board_offers_and_its_mode_takes() -> void:
	var end := 1_000 + 86_400
	# Bram and Tobin on Safe: the rats (82) and the well (72).
	_auto(_first)
	_dispatch.adventurers.gear.stash_cap = 100_000
	Auto.checkpoint(_dispatch, _new_board(1_000), end, PackedInt64Array())
	assert_eq(_tried(), ["rats", "well"])
	assert_gt(_dispatch.tries["rats"], 100)
	# On Bold, every rank F quest, but not the wolves (29).
	before_each()
	_auto(_first, Parties.BOLD)
	_dispatch.adventurers.gear.stash_cap = 100_000
	Auto.checkpoint(_dispatch, _new_board(1_000), end, PackedInt64Array())
	var rank_f := ["cartographer", "letters", "moonherbs", "mouth", "rats", "spiders", "well"]
	assert_eq(_tried(), rank_f)
	for quest: String in rank_f:
		assert_gt(_dispatch.tries[quest], 100, quest)
		# Tried, as a party back from it would have, so its challenges are known.
		assert_true(_dispatch.unknown_challenges(quest).is_empty(), quest)
	assert_eq(_dispatch.unknown_challenges("wolves"), PackedStringArray(["Attrition"]))
	# Rank E and strong enough for anything: each rank E quest too, and no rank D quest, which a rank
	# F guild's board never offers.
	before_each()
	for adventurer: String in ["bram", "tobin"]:
		_dispatch.adventurers.roster[adventurer]["rank"] = "E"
		for stat: String in Adventurers.STATS:
			_dispatch.adventurers.stats[adventurer][stat] = 60
	_auto(_first, Parties.BOLD)
	_dispatch.adventurers.gear.stash_cap = 100_000
	Auto.checkpoint(_dispatch, _new_board(1_000), end, PackedInt64Array())
	var rank_e := ["crypt", "goblins", "lurker", "pilgrims", "sealed_door", "wolves"]
	assert_eq(_tried().size(), rank_f.size() + rank_e.size())
	for quest: String in rank_e:
		assert_gt(_dispatch.tries[quest], 10, quest)


func test_loot_from_the_averages_fills_the_stash_and_the_first_item_that_does_not_fit_waits_and_stops_its_party() -> void:
	# Ilse and Maren on the well bring an item in 29% of cycles: the 1st in cycle 4, then 7, 11 and 14.
	_auto(_second)
	_dispatch.adventurers.gear.stash_cap = 3
	Auto.checkpoint(_dispatch, _new_board(1_000), 1_000 + 52_050 + Auto.REPLAY_SECONDS, PackedInt64Array())
	assert_eq(_dispatch.adventurers.gear.stash.size(), 3)
	assert_eq(_dispatch.waiting_loot.size(), 1)
	assert_eq(_dispatch.waiting_loot[0]["party"], PackedStringArray(["ilse", "maren"]))
	assert_eq(_dispatch.waiting_loot[0]["quest"], "well")
	assert_has(Gear.ITEMS, _dispatch.waiting_loot[0]["item"])
	# Fourteen cycles and no more: 4.75 gold and 1.95 XP each a cycle.
	assert_eq(_dispatch.tries, {"well": 14})
	assert_eq(_dispatch.gold.amount, 67)
	assert_eq(_dispatch.adventurers.xp["ilse"], 27)
	# Its loot waiting, it stayed home through the rest.
	assert_eq(_out(_second), [])


func test_averaged_members_end_home_at_full_health_uninjured_with_their_xp_banked_and_no_level_up() -> void:
	# Bram and Tobin on Bold, Bram hurt and injured at first: averaged once he is well, until loot
	# finds the stash full, then home through the rest.
	_auto(_first, Parties.BOLD)
	_dispatch.adventurers.gear.stash_cap = 40
	_dispatch.wounds["bram"] = {"health": 2, "at": 1_000}
	_dispatch.injured_until["bram"] = 1_010
	var end := 1_000 + 86_400
	Auto.checkpoint(_dispatch, _new_board(1_000), end, PackedInt64Array())
	assert_gt(_quests_done(), 100)
	for member: String in ["bram", "tobin"]:
		assert_eq(_dispatch.health(member, end), _dispatch.adventurers.max_health(member), member)
		assert_eq(_dispatch.injury_left(member, end), 0, member)
		assert_eq(_dispatch.status(member, end), "Waiting on loot", member)
		assert_eq(_dispatch.adventurers.levels[member], 1, member)
		assert_true(_dispatch.adventurers.level_up_ready(member), member)


func test_a_party_with_auto_off_just_sits_home_and_heals_through_a_long_absence() -> void:
	# Bram and Tobin have Auto off, Bram hurt and injured; Ilse and Maren quest on Safe.
	_auto(_second)
	_dispatch.adventurers.gear.stash_cap = 100_000
	_dispatch.wounds["bram"] = {"health": 2, "at": 1_000}
	_dispatch.injured_until["bram"] = 1_010
	var board := _board(["rats", "well", "moonherbs"], 1_000)
	var end := 1_000 + 86_400
	Auto.checkpoint(_dispatch, board, end, PackedInt64Array())
	assert_eq(_tried(), ["well"])
	assert_gt(_dispatch.adventurers.xp["ilse"], 100)
	for member: String in ["bram", "tobin"]:
		assert_eq(_dispatch.adventurers.xp[member], 0, member)
		assert_eq(_dispatch.health(member, end), _dispatch.adventurers.max_health(member), member)
		assert_eq(_dispatch.injury_left(member, end), 0, member)
	assert_eq(_out(_first), [])


func test_a_party_out_when_a_long_absence_starts_comes_home_as_its_quest_decides_then_is_averaged() -> void:
	# Bram and Tobin, on Safe, left for the wolves at 1_000 with a seed that brings an item.
	_auto(_first)
	_dispatch.adventurers.gear.stash_cap = 100_000
	var luck := _dispatch.party_stat(PackedStringArray(["bram", "tobin"]), "luck")
	var roll_seed := 0
	while Gear.loot(roll_seed, "E", luck).is_empty():
		roll_seed += 1
	var board := _new_board(1_000)
	assert_true(_dispatch.send("wolves", PackedStringArray(["bram", "tobin"]), roll_seed, 1_000))
	Auto.checkpoint(_dispatch, board, 1_000 + 86_400, PackedInt64Array())
	# Back from the wolves once, its item first in the stash; then the rats and the well, averaged.
	assert_eq(_tried(), ["rats", "well", "wolves"])
	assert_eq(_dispatch.tries["wolves"], 1)
	assert_gt(_dispatch.tries["rats"], 100)
	assert_eq(_dispatch.adventurers.gear.stash[0], Gear.loot(roll_seed, "E", luck))
	assert_gt(_dispatch.adventurers.gear.stash.size(), 1)


func test_a_long_absence_settles_the_same_way_for_the_same_save_and_time_whatever_the_global_generator_gives() -> void:
	var results: Array[String] = []
	for global_seed: int in [1, 2]:
		var board := _two_auto_parties()
		_dispatch.adventurers.gear.stash_cap = 1_000
		seed(global_seed)
		Auto.checkpoint(_dispatch, board, 1_000 + 7 * 86_400, PackedInt64Array([4_600]), 2_800, 1_600)
		results.append(_saved(board))
	assert_eq(results[0], results[1])
	assert_gt(_quests_done(), 1_000)


func test_a_clock_set_back_after_a_long_absence_never_removes_progress_nor_settles_again() -> void:
	var board := _two_auto_parties()
	_dispatch.adventurers.gear.stash_cap = 1_000
	var end := 1_000 + 86_400
	Auto.checkpoint(_dispatch, board, end, PackedInt64Array(), 2_800, 1_600)
	var after := _saved(board)
	assert_gt(_dispatch.gold.amount, 0)
	for back: int in [end - 1, end - Auto.REPLAY_SECONDS - 1, 1_000]:
		Auto.checkpoint(_dispatch, board, back, PackedInt64Array(), 2_800, 1_600)
		assert_eq(_saved(board), after, str(back))
