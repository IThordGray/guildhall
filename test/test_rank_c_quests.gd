extends GutTest

const Fixtures := preload("res://test/fixtures.gd")

const START: int = 1_000_000
const NO_HALLS: PackedInt64Array = []
const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
const RANK_C: Array[String] = ["wyrm", "witch", "deeproad", "heirs", "lich", "giants"]


## A guild of the four starters, all of `rank`, in one party, at START.
func _guild(rank: String) -> Dispatch:
	var dispatch := Dispatch.new(START)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	for adventurer: String in EVERYONE:
		dispatch.adventurers.roster[adventurer]["rank"] = rank
	return dispatch


## The quests 40 one-slot boards draw, each filled at its own second for a guild of `guild_rank`
## whose starters are all of `adventurer_rank`.
func _draws(guild_rank: String, adventurer_rank: String) -> Array[String]:
	var dispatch := _guild(adventurer_rank)
	var drawn: Array[String] = []
	for i: int in 40:
		var board := Board.new()
		board.reception_slots = 1
		board.refill(dispatch, START + i, NO_HALLS, PackedInt64Array(), PackedInt64Array(), guild_rank)
		drawn.append(board.slots[0])
	return drawn


## Bram alone, rank D, at level 400 so no damage reaches 1 health, sent on `quest` with `roll_seed`
## and made to end as `success` with no Spirit or Luck, then home. The guild as he comes home.
func _sent_home(quest: String, roll_seed: int, success: bool) -> Dispatch:
	var dispatch := _guild("D")
	dispatch.reputation = 10
	dispatch.adventurers.levels["bram"] = 400
	dispatch.adventurers.gear.stash_cap = 1_000
	assert_true(dispatch.send(quest, Fixtures.party(dispatch, ["bram"]), roll_seed, START))
	var outing := dispatch.outings[0]
	outing["chance"] = 100 if success else 0
	outing["spirit"] = 0
	outing["luck"] = 0
	dispatch.checkpoint(START + int(Dispatch.QUESTS[quest]["seconds"]))
	return dispatch


## A one-slot board for a rank-D guild of rank-D starters holding a rank C quest, filled at the
## first second from START that draws one.
func _rank_c_board(dispatch: Dispatch) -> Board:
	for i: int in 1_000:
		var board := Board.new()
		board.reception_slots = 1
		board.refill(dispatch, START + i, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "D")
		if Dispatch.QUESTS[board.slots[0]]["rank"] == "C":
			return board
	fail_test("no rank C quest drawn")
	return null


func test_the_six_rank_c_quests_exist_with_their_numbers_and_none_is_a_labyrinth_story_or_floor_quest() -> void:
	var expected := {
		"wyrm": ["Drive off the ash wyrm", "C", 80, 210, 140, 98, ["Brute force", "Attrition", "Protect"]],
		"witch": ["Break the witch-queen's circle", "C", 90, 230, 150, 100, ["Curse", "Negotiation"]],
		"deeproad": ["Reopen the deep road", "C", 100, 250, 165, 96, ["Navigation", "Traps", "Attrition"]],
		"heirs": ["Ransom the baron's heirs", "C", 90, 240, 155, 102, ["Negotiation", "Protect"]],
		"lich": ["Lay the lich of the drowned keep", "C", 110, 270, 180, 105, ["Curse", "Traps", "Protect"]],
		"giants": ["Hold the pass against the hill giants", "C", 120, 300, 200, 100, ["Brute force", "Navigation", "Attrition"]],
	}
	var found := {}
	for quest: String in Dispatch.QUESTS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		if info["rank"] == "C" and not Dispatch.is_elite(quest):
			found[quest] = [info["name"], info["rank"], info["seconds"], info["gold"], info["xp"], info["difficulty"], info["challenges"]]
			assert_false(info.get("labyrinth", false), quest)
			assert_false(Dispatch.is_story(quest), quest)
			assert_false(Dispatch.is_floor(quest), quest)
	assert_eq(found, expected)


func test_a_rank_d_guild_whose_highest_party_is_rank_d_is_offered_rank_c_quests_at_the_r_plus_1_share() -> void:
	# E 10, D 70 and C 20 of 100, among 6, 5 and 6 quests.
	var ranked := _guild("D").adventurers
	for quest: String in RANK_C:
		assert_almost_eq(Board.draw_chance(quest, ranked, "D"), 20.0 / 100.0 / 6.0, 1e-9, quest)
	assert_almost_eq(Board.draw_chance("vault", ranked, "D"), 70.0 / 100.0 / 5.0, 1e-9)
	assert_almost_eq(Board.draw_chance("wolves", ranked, "D"), 10.0 / 100.0 / 6.0, 1e-9)
	assert_eq(Board.draw_chance("rats", ranked, "D"), 0.0)
	# About one fill in five draws one.
	var drawn := 0
	var dispatch := _guild("D")
	for i: int in 1_000:
		var board := Board.new()
		board.reception_slots = 1
		board.refill(dispatch, START + i, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "D")
		drawn += 1 if Dispatch.QUESTS[board.slots[0]]["rank"] == "C" else 0
	assert_between(drawn, 150, 250)
	# With the highest party rank E, a rank-D guild is offered none: E's 10 and D's 70 share it all.
	var capped := _guild("E").adventurers
	for quest: String in RANK_C:
		assert_eq(Board.draw_chance(quest, capped, "D"), 0.0, quest)
	assert_almost_eq(Board.draw_chance("vault", capped, "D"), 70.0 / 80.0 / 5.0, 1e-9)


func test_guilds_of_rank_f_and_e_draw_exactly_as_before_even_with_rank_d_parties() -> void:
	# What these fills drew before rank C quests existed.
	var rank_f: Array[String] = [
		"moonherbs", "well", "goblins", "lurker", "mouth", "wolves", "goblins", "spiders", "letters", "spiders",
		"well", "wolves", "wolves", "crypt", "cartographer", "moonherbs", "rats", "well", "moonherbs", "wolves",
		"goblins", "sealed_door", "letters", "wolves", "spiders", "well", "spiders", "rats", "spiders", "letters",
		"wolves", "mouth", "letters", "well", "letters", "spiders", "lurker", "lurker", "letters", "rats",
	]
	var rank_e: Array[String] = [
		"lurker", "crypt", "goblins", "lurker", "sealed_door", "wolves", "goblins", "goblins", "lurker", "lurker",
		"maze", "minotaur", "wolves", "crypt", "vault", "wolves", "goblins", "maze", "lurker", "wolves",
		"envoy", "envoy", "wolves", "wolves", "vault", "sealed_door", "lurker", "chapel", "sealed_door", "pilgrims",
		"wolves", "minotaur", "lurker", "minotaur", "sealed_door", "spiders", "letters", "lurker", "envoy", "rats",
	]
	assert_eq(_draws("F", "D"), rank_f)
	assert_eq(_draws("E", "D"), rank_e)
	var ranked := _guild("D").adventurers
	for quest: String in RANK_C:
		assert_eq(Board.draw_chance(quest, ranked, "E"), 0.0, quest)
	assert_almost_eq(Board.draw_chance("maze", ranked, "E"), 20.0 / 100.0 / 5.0, 1e-9)


func test_a_failed_rank_c_quest_deals_35_to_70_damage_injuring_but_never_killing() -> void:
	var dealt: Array[int] = []
	for roll_seed: int in 100:
		var dispatch := _sent_home("wyrm", roll_seed, false)
		dealt.append(dispatch.adventurers.max_health("bram") - dispatch.health("bram", START + 80))
	assert_gte(dealt.min(), 35)
	assert_eq(dealt.max(), 70)
	# From 20 health, the most leaves 1: injured, never dead.
	var worn := _guild("D")
	assert_true(worn.send("lich", Fixtures.party(worn, ["bram"]), 1, START))
	worn.outings[0]["chance"] = 0
	worn.outings[0]["health"]["bram"] = 20
	worn.checkpoint(START + 110)
	assert_eq(worn.health("bram", START + 110), 1)
	assert_true(worn.injured_until.has("bram"))


func test_a_rank_c_quest_brings_loot_about_nine_times_in_ten() -> void:
	var looted := 0
	for roll_seed: int in 200:
		looted += 1 if not _sent_home("witch", roll_seed, true).adventurers.gear.stash.is_empty() else 0
	assert_between(looted, 168, 192)


func test_a_rank_c_success_earns_4_reputation_and_a_failure_takes_1() -> void:
	assert_eq(_sent_home("heirs", 1, true).reputation, 14)
	assert_eq(_sent_home("heirs", 1, false).reputation, 9)


func test_a_rank_c_quests_slot_refills_180_seconds_after_a_send_and_a_rank_c_quest_left_on_the_board_leaves_after_360() -> void:
	var dispatch := _guild("D")
	var board := _rank_c_board(dispatch)
	var filled_at := board.filled_at[0]
	var quest := board.slots[0]
	assert_eq(board.seconds_to_leave(quest, dispatch, filled_at), 360)
	board.refill(dispatch, filled_at + 359, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "D")
	assert_eq(board.slots[0], quest)
	board.refill(dispatch, filled_at + 360, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "D")
	assert_eq(board.slots[0], "")
	assert_eq(board.seconds_to_refill(0, dispatch, filled_at + 360), 180)
	# Sent, its slot refills after 180.
	var sending := _guild("D")
	var sent := _rank_c_board(sending)
	var at := sent.filled_at[0]
	assert_true(sent.send(sending, sent.slots[0], PackedStringArray(EVERYONE), 1, at, NO_HALLS, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "D"))
	assert_eq(sent.seconds_to_refill(0, sending, at), 180)


func test_autos_averaged_settle_takes_rank_c_quests_and_counts_their_reputation_and_successes() -> void:
	var dispatch := _guild("D")
	# Strong enough, and Bold, that every rank C quest is taken, its last challenge still unknown.
	for adventurer: String in EVERYONE:
		for stat: String in Adventurers.STATS:
			dispatch.adventurers.stats[adventurer][stat] = 60
	dispatch.adventurers.gear.stash_cap = 1_000
	var parties := dispatch.adventurers.parties
	parties.set_auto(parties.party_of("bram"), true)
	parties.set_mode(parties.party_of("bram"), Parties.BOLD)
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, START, NO_HALLS, PackedInt64Array(), PackedInt64Array(), "D")
	Auto.checkpoint(dispatch, board, START + Auto.REPLAY_SECONDS + 24 * 3_600, NO_HALLS, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "D")
	assert_gt(int(dispatch.adventurers.successes["bram"].get("C", 0)), 0)
	assert_gt(dispatch.reputation, 0)


func test_a_rank_d_adventurer_at_level_10_with_5_rank_c_successes_can_be_promoted_to_c_raising_two_stats_and_not_before() -> void:
	var cases: Array = [
		# Level, rank C successes, out on a quest.
		[9, 5, false],
		[10, 4, false],
		[10, 5, true],
	]
	for case: Array in cases:
		var refused := Adventurers.new(EVERYONE)
		refused.roster["bram"]["rank"] = "D"
		refused.levels["bram"] = case[0]
		refused.add_successes("bram", "D", 50)
		refused.add_successes("bram", "C", case[1])
		assert_eq(refused.next_rank("bram"), "C", str(case))
		assert_false(refused.can_promote("bram", case[2]), str(case))
		assert_false(refused.promote("bram", case[2]), str(case))
		assert_eq(refused.roster["bram"]["rank"], "D", str(case))
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.roster["bram"]["rank"] = "D"
	adventurers.levels["bram"] = 10
	adventurers.add_successes("bram", "C", 5)
	var before: Dictionary = adventurers.stats["bram"].duplicate()
	var raised := adventurers.promotion_stats("bram")
	assert_eq(raised.size(), 2)
	assert_true(adventurers.can_promote("bram", false))
	# Meeting it promotes nobody: the player presses Promote.
	assert_eq(adventurers.roster["bram"]["rank"], "D")
	assert_true(adventurers.promote("bram", false))
	assert_eq(adventurers.roster["bram"]["rank"], "C")
	for stat: String in Adventurers.STATS:
		assert_eq(adventurers.stats["bram"][stat], before[stat] + (1 if stat in raised else 0), stat)
