extends GutTest

const SAVE_PATH: String = "user://test_dispatch_save.cfg"
const PARTY: PackedStringArray = ["bram", "ilse", "tobin"]
const EVERYONE: Array[String] = ["bram", "ilse", "tobin", "maren"]
## An adventurer who leans Defence and Presence, with no Luck, growing evenly.
const WREN_STATS: Dictionary = {"strength": 4, "agility": 2, "perception": 2, "mind": 1, "spirit": 2, "defence": 8, "endurance": 3, "presence": 5, "luck": 0}
const WREN_GROWTH: Dictionary = {"strength": 0.5, "agility": 0.5, "perception": 0.5, "mind": 0.5, "spirit": 0.5, "defence": 0.5, "endurance": 0.5, "presence": 0.5, "luck": 0.5}


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


## A hall with the six ground-floor rooms of one saved before guild ranks, at `at`, at a rank that
## opens every room type and Extend.
func _six_room_hall(at: int) -> Hall:
	var hall := Hall.new(at)
	hall.layout = Hall.OLD_LAYOUT
	hall.rank = "D"
	return hall


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A seed with which `party` on `quest` succeeds, or fails when `success` is false, sent from a
## guild of all four starters, a lucky break counted as sending would.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var guild := _guild(0)
	var luck := guild.party_stat(party, "luck")
	for roll_seed: int in 10_000:
		var lucky: bool = Outcome.lucky_break(roll_seed, luck) and guild.challenge_chances(quest, party).min() < Outcome.EVEN_CHANCE
		if Outcome.roll(roll_seed, guild.success_chance(quest, party, lucky), 0, party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


## Makes `adventurer`, out on a quest, have left with 1 health, so coming home leaves them under a
## quarter of their health, whatever the damage.
func _worn_out(dispatch: Dispatch, adventurer: String) -> void:
	for outing: Dictionary in dispatch.outings:
		if adventurer in outing["party"]:
			outing["health"][adventurer] = 1


## Sends PARTY on `quest` with a seed it succeeds with.
func _send_to_succeed(dispatch: Dispatch, quest: String, now: int) -> bool:
	return dispatch.send(quest, PARTY, _seed(quest, PARTY, true), now)


func _debriefed_quests(dispatch: Dispatch) -> Array[String]:
	var quests: Array[String] = []
	for debrief: Dictionary in dispatch.debriefs:
		quests.append(debrief["quest"])
	return quests


func _statuses(dispatch: Dispatch, now: int) -> Array[String]:
	var statuses: Array[String] = []
	for adventurer: String in EVERYONE:
		statuses.append(dispatch.status(adventurer, now))
	return statuses


## Reads every debrief waiting, oldest first, paying each into `gold`.
func _read_all(dispatch: Dispatch, gold: Gold) -> void:
	while not dispatch.debriefs.is_empty():
		dispatch.read_debrief(0, gold)


func test_the_pool_has_7_f_6_e_and_5_d_quests_longer_and_richer_by_rank_each_paying_its_gold_after_its_duration() -> void:
	# Old saves refer to these by id.
	for quest: String in ["rats", "moonherbs", "goblins", "letters", "wolves", "crypt"]:
		assert_has(Dispatch.QUESTS, quest)
	var count := {"F": 0, "E": 0, "D": 0}
	var shortest := {"F": 2, "E": 10, "D": 30}
	var longest := {"F": 6, "E": 20, "D": 60}
	var least_gold := {}
	var most_gold := {}
	for quest: String in Dispatch.QUESTS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		var rank: String = info["rank"]
		count[rank] += 1
		assert_between(int(info["seconds"]), int(shortest[rank]), int(longest[rank]), quest)
		least_gold[rank] = mini(least_gold.get(rank, info["gold"]), info["gold"])
		most_gold[rank] = maxi(most_gold.get(rank, info["gold"]), info["gold"])
		# A rank D quest needs a party of rank E or higher.
		var gold := Gold.new(0)
		var dispatch := _guild(1_000)
		for adventurer: String in PARTY:
			dispatch.adventurers.roster[adventurer]["rank"] = "E"
		assert_true(_send_to_succeed(dispatch, quest, 1_000), quest)
		assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_000), info["seconds"], quest)
		dispatch.checkpoint(1_000 + info["seconds"] - 1)
		assert_eq(gold.amount, 0, quest)
		dispatch.checkpoint(1_000 + info["seconds"])
		_read_all(dispatch, gold)
		assert_eq(gold.amount, info["gold"], quest)
	assert_eq(count, {"F": 7, "E": 6, "D": 5})
	assert_lt(most_gold["F"], least_gold["E"])
	assert_lt(most_gold["E"], least_gold["D"])


## Every pair of the four starters.
func _pairs() -> Array[PackedStringArray]:
	var pairs: Array[PackedStringArray] = []
	for i: int in EVERYONE.size():
		for j: int in range(i + 1, EVERYONE.size()):
			pairs.append(PackedStringArray([EVERYONE[i], EVERYONE[j]]))
	return pairs


func test_the_four_starters_have_good_odds_on_every_f_quest_fair_odds_together_on_e_and_little_hope_on_d() -> void:
	var dispatch := _guild(1_000)
	var all_four := PackedStringArray(EVERYONE)
	assert_eq(_pairs().size(), 6)
	var checked := {"F": 0, "E": 0, "D": 0}
	for quest: String in Dispatch.QUESTS:
		var together := dispatch.success_chance(quest, all_four)
		var pair_chances: Array[int] = []
		for pair: PackedStringArray in _pairs():
			pair_chances.append(dispatch.success_chance(quest, pair))
		match Dispatch.QUESTS[quest]["rank"]:
			"F":
				assert_true(pair_chances.any(func(chance: int) -> bool: return chance >= 60 and chance <= 85), "%s: some pair has 60–85%%, %s" % [quest, pair_chances])
				assert_gte(together, 90, quest)
			"E":
				assert_between(together, 45, 75, quest)
				assert_lte(pair_chances.max(), 40, quest)
			"D":
				assert_lte(together, 25, quest)
		checked[Dispatch.QUESTS[quest]["rank"]] += 1
	assert_eq(checked, {"F": 7, "E": 6, "D": 5})


## How many of `seeds` returns of `party` from `quest`, sent from full health and made to end as
## `success`, bring at least one member home injured.
func _injuring_returns(quest: String, party: PackedStringArray, success: bool, seeds: int) -> int:
	var injuring := 0
	for roll_seed: int in seeds:
		var dispatch := _guild(1_000)
		assert_true(dispatch.send(quest, party, roll_seed, 1_000))
		dispatch.outings[0]["chance"] = 100 if success else 0
		dispatch.checkpoint(9_999)
		assert_eq(dispatch.debriefs[0]["success"], success)
		if not dispatch.debriefs[0]["injured"].is_empty():
			injuring += 1
	return injuring


func test_from_full_health_a_failed_f_quest_rarely_injures_a_failed_e_quest_often_does_and_a_won_f_quest_never_does() -> void:
	# Of 400 failures with all four starters: under 10% for an F quest, 20–45% for an E one.
	const SEEDS: int = 400
	var all_four := PackedStringArray(EVERYONE)
	for quest: String in Dispatch.QUESTS:
		match Dispatch.QUESTS[quest]["rank"]:
			"F":
				assert_lt(_injuring_returns(quest, all_four, false, SEEDS), 40, quest)
				assert_eq(_injuring_returns(quest, all_four, true, SEEDS), 0, quest)
				# Nor alone, with nobody else's Spirit to lessen the damage.
				for adventurer: String in EVERYONE:
					assert_eq(_injuring_returns(quest, [adventurer], true, 100), 0, "%s %s" % [quest, adventurer])
			"E":
				assert_between(_injuring_returns(quest, all_four, false, SEEDS), 80, 180, quest)
	# A won F quest still hurts: it never injures, but not for want of damage.
	var damaged := false
	for roll_seed: int in 20:
		var won := _guild(1_000)
		won.send("rats", ["tobin"], roll_seed, 1_000)
		won.outings[0]["chance"] = 100
		won.checkpoint(1_060)
		damaged = damaged or int(won.debriefs[0]["damage"]["tobin"]) > 0
	assert_true(damaged)


func test_the_roster_has_two_rank_f_adventurers_bram_and_tobin_both_resting_in_a_new_game() -> void:
	var expected := {
		"bram": ["Bram", "Fighter", "F"],
		"tobin": ["Tobin", "Scout", "F"],
	}
	var roster := Dispatch.new(1_000).adventurers.roster
	assert_eq(roster.keys(), expected.keys())
	for adventurer: String in expected:
		var info: Dictionary = roster[adventurer]
		assert_eq([info["name"], Dispatch.new(1_000).adventurers.title(adventurer), info["rank"]], expected[adventurer])
		# Each starter's face is their own, from their id.
		assert_eq(Faces.seed_of(adventurer, info), hash(adventurer))
	var dispatch := Dispatch.new(1_000)
	assert_eq([dispatch.status("bram", 1_000), dispatch.status("tobin", 1_000)], ["Resting", "Resting"])
	# Between them they meet the commonest rank-F challenges, on Rats in the cellar and the
	# labyrinth's mouth.
	assert_true(dispatch.challenge_met("rats", "Brute force", ["bram", "tobin"]))
	assert_true(dispatch.challenge_met("mouth", "Traps", ["bram", "tobin"]))
	assert_true(dispatch.challenge_met("mouth", "Navigation", ["bram", "tobin"]))


func test_an_added_adventurer_can_be_sent_counts_with_their_own_stats_and_comes_home_with_xp() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.adventurers.add("wren", {"name": "Wren", "rank": "F"}, WREN_STATS, WREN_GROWTH)
	assert_eq(dispatch.status("wren", 1_000), "Resting")
	# Letters needs 1 for both. Navigation 2 + 1: 54. Negotiation 2 × 5 + 1: 70. (54 + 70 + 54) ÷ 3.
	assert_eq(dispatch.success_chance("letters", ["wren"]), 59)
	assert_true(dispatch.send("letters", ["wren", "tobin"], 7, 1_000))
	assert_eq(dispatch.status("wren", 1_000), "On quest: Carry letters to the abbey")
	dispatch.checkpoint(1_120)
	assert_eq(dispatch.debriefs[0]["party"], PackedStringArray(["wren", "tobin"]))
	var xp: int = dispatch.debriefs[0]["xp"]
	_read_all(dispatch, gold)
	assert_gt(dispatch.adventurers.xp["wren"], 0)
	assert_eq(dispatch.adventurers.xp["wren"], xp)


func test_the_success_chance_is_from_the_picked_party_against_the_quest() -> void:
	# Moonherbs needs 2 for Navigation and 3 for Attrition. Bram and Tobin bring Navigation 5 + 12:
	# 80; Attrition 17 + 9: 95. (80 + 95 + 80) ÷ 3.
	assert_eq(_guild(1_000).success_chance("moonherbs", ["bram", "tobin"]), 85)
	# Bram and Ilse bring Navigation 5 + 14: 84; Attrition 17 + 9: 95. (84 + 95 + 84) ÷ 3.
	assert_eq(_guild(1_000).success_chance("moonherbs", ["bram", "ilse"]), 87)
	# Goblin camp needs 53 for Brute force, 53 for Traps and 35 for Navigation. Bram, Ilse and Maren
	# bring 23 + 9 + 9: 26; 9 + 9 + 9: 5; 5 + 14 + 9: 36. (26 + 5 + 36 + 5) ÷ 4.
	assert_eq(_guild(1_000).success_chance("goblins", ["bram", "ilse", "maren"]), 18)
	# Rats needs 11 for Brute force; Tobin brings 9.
	assert_eq(_guild(1_000).success_chance("rats", ["tobin"]), 46)


func test_four_one_person_parties_can_be_out() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("moonherbs", ["tobin"], 0, 1_000))
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_002), 4)
	assert_eq(dispatch.party_refusal("rats", ["maren"], 1_002), "")
	assert_true(dispatch.send("rats", ["maren"], 0, 1_003))
	assert_true(dispatch.send("goblins", ["bram"], 0, 1_003))
	assert_true(dispatch.send("crypt", ["ilse"], 0, 1_004))
	assert_eq(dispatch.outings.size(), 4)
	assert_eq(_statuses(dispatch, 1_004), ["On quest: Goblin camp", "On quest: Clear the old crypt", "On quest: Gather moonherbs", "On quest: Rats in the cellar"])
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_004), 2)
	# With everyone out, nobody is left to send.
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 1_004), "Tobin can't go")


func test_the_party_shows_as_on_its_quest_and_the_others_as_resting() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("goblins", ["ilse", "maren"], 7, 1_000))
	assert_eq(_statuses(dispatch, 1_100), ["Resting", "On quest: Goblin camp", "Resting", "On quest: Goblin camp"])


func test_a_party_is_one_to_four_adventurers_who_are_home_and_well() -> void:
	var dispatch := _guild(1_000)
	assert_eq(dispatch.party_refusal("rats", [], 1_000), "Pick at least one adventurer")
	assert_false(dispatch.send("rats", [], 1, 1_000))
	assert_true(dispatch.outings.is_empty())
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 1_000), "")
	assert_eq(dispatch.party_refusal("rats", ["bram", "ilse", "tobin", "maren"], 1_000), "")
	assert_true(dispatch.send("rats", ["bram", "ilse", "tobin", "maren"], 1, 1_000))
	assert_eq(_statuses(dispatch, 1_000), ["On quest: Rats in the cellar", "On quest: Rats in the cellar", "On quest: Rats in the cellar", "On quest: Rats in the cellar"])


func test_party_of_five_is_refused() -> void:
	var dispatch := _guild(1_000)
	var five: PackedStringArray = ["bram", "ilse", "tobin", "maren", "bram"]
	assert_eq(dispatch.party_refusal("rats", five, 1_000), "At most 4 in a party")
	assert_false(dispatch.send("rats", five, 1, 1_000))
	assert_true(dispatch.outings.is_empty())


func test_an_injured_adventurer_cannot_be_picked_until_recovered() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_025)
	assert_false(dispatch.can_go("tobin", 1_025))
	assert_true(dispatch.can_go("bram", 1_025))
	assert_eq(dispatch.party_refusal("rats", ["bram", "tobin"], 1_025), "Tobin can't go")
	assert_false(dispatch.send("rats", ["bram", "tobin"], 1, 1_025))
	assert_true(dispatch.outings.is_empty())
	_read_all(dispatch, gold)
	assert_false(dispatch.can_go("tobin", 1_029))
	assert_true(dispatch.can_go("tobin", 1_030))
	assert_true(dispatch.send("rats", ["bram", "tobin"], 1, 1_030))


func test_an_adventurer_out_on_a_quest_cannot_be_picked_and_is_free_once_home() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("rats", ["bram"], _seed("rats", ["bram"], true), 1_000)
	assert_false(dispatch.can_go("bram", 1_030))
	assert_true(dispatch.can_go("ilse", 1_030))
	dispatch.checkpoint(1_060)
	_read_all(dispatch, gold)
	assert_true(dispatch.can_go("bram", 1_060))


func test_a_success_pays_the_full_reward_and_injures_nobody() -> void:
	var gold := Gold.new(5)
	var dispatch := _guild(1_000)
	dispatch.send("rats", ["bram", "maren"], _seed("rats", ["bram", "maren"], true), 1_000)
	dispatch.checkpoint(1_002)
	# Rats' 1 XP shared by two would be 0 each, but every member gains at least 1.
	assert_eq(dispatch.debriefs, [{"quest": "rats", "returned_at": 1_002, "success": true, "party": PackedStringArray(["bram", "maren"]), "damage": {"bram": 4, "maren": 1}, "injured": {}, "gold": 3, "xp": 2, "revealed": PackedStringArray(), "loot": PackedStringArray(), "paid": false, "xp_given": true}])
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 8)
	assert_eq(_statuses(dispatch, 1_002), ["Resting", "Resting", "Resting", "Resting"])


func test_a_failure_pays_no_gold_and_injures_a_worn_out_member_for_ten_seconds_from_return() -> void:
	var gold := Gold.new(40)
	var dispatch := _guild(1_000)
	var injured := "tobin"
	dispatch.send("moonherbs", PARTY, _seed("moonherbs", PARTY, false), 1_000)
	_worn_out(dispatch, injured)
	# Returns at 1_006; the checkpoint comes 2 s later, as on opening the app.
	dispatch.checkpoint(1_008)
	assert_eq(dispatch.debriefs[0]["injured"], {injured: 10})
	assert_eq(dispatch.debriefs[0]["gold"], 0)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 40)
	var hurt: Array[String] = []
	for adventurer: String in EVERYONE:
		if not dispatch.can_go(adventurer, 1_008):
			hurt.append(adventurer)
	assert_eq(hurt, [injured])
	assert_eq(dispatch.injury_left(injured, 1_008), 8)
	assert_eq(dispatch.injury_seconds(injured), 10)
	assert_eq(dispatch.status(injured, 1_008), "Injured · 0:08")
	assert_eq(dispatch.injury_left(injured, 1_015), 1)
	assert_eq(dispatch.status(injured, 1_016), "Resting")


func test_a_failed_goblin_camp_pays_no_gold_and_names_the_injured() -> void:
	var gold := Gold.new(20)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_020)
	assert_eq(dispatch.debriefs[0]["injured"], {"tobin": 10})
	assert_eq(dispatch.debriefs[0]["gold"], 0)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 20)


func test_the_outcome_is_not_revealed_before_the_party_returns() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	dispatch.checkpoint(1_019)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.status("tobin", 1_019), "On quest: Goblin camp")
	dispatch.checkpoint(1_020)
	assert_eq(dispatch.debriefs.size(), 1)


func test_the_reward_lands_exactly_when_the_quest_ends_and_not_a_second_before() -> void:
	var gold := Gold.new(10)
	var dispatch := _guild(1_000)
	_send_to_succeed(dispatch, "rats", 1_000)
	dispatch.checkpoint(1_001)
	assert_eq(gold.amount, 10)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_001), 1)
	assert_eq(dispatch.outings.size(), 1)
	dispatch.checkpoint(1_002)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 13)
	assert_true(dispatch.outings.is_empty())


func test_the_reward_is_paid_once_however_many_checkpoints_follow() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	_send_to_succeed(dispatch, "rats", 1_000)
	for now: int in [1_002, 1_003, 1_200, 5_000, 5_000]:
		dispatch.checkpoint(now)
	_read_all(dispatch, gold)
	dispatch.checkpoint(6_000)
	assert_eq(gold.amount, 3)


func test_a_quest_that_ended_while_the_app_was_closed_pays_on_the_first_checkpoint_after() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	_send_to_succeed(dispatch, "goblins", 1_000)
	dispatch.checkpoint(1_010)
	assert_false(dispatch.returned_since_checkpoint(1_015))
	assert_true(dispatch.returned_since_checkpoint(9_000))
	dispatch.checkpoint(9_000)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 42)
	assert_false(dispatch.returned_since_checkpoint(9_000))


func test_an_injury_runs_out_while_the_app_is_closed() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_010)
	dispatch.checkpoint(1_000 + 20 + 9)
	_read_all(dispatch, gold)
	assert_eq(dispatch.status("tobin", 1_029), "Injured · 0:01")
	dispatch.checkpoint(1_000 + 20 + 10)
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.status("tobin", 1_030), "Resting")


func test_a_clock_set_back_after_the_return_pays_nothing_extra_and_does_not_rerun_the_quest() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	_send_to_succeed(dispatch, "rats", 1_000)
	dispatch.checkpoint(1_100)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 3)

	dispatch.checkpoint(990)
	assert_eq(gold.amount, 3)
	assert_true(dispatch.outings.is_empty())
	assert_true(dispatch.can_go("bram", 990))
	assert_false(dispatch.returned_since_checkpoint(990))
	dispatch.checkpoint(1_100)
	dispatch.checkpoint(2_000)
	assert_eq(gold.amount, 3)


func test_a_clock_set_back_after_a_failure_never_rerolls_repays_or_heals_early() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_022)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.injury_left("tobin", 1_022), 8)

	dispatch.checkpoint(500)
	assert_eq(dispatch.injury_left("tobin", 500), 8)
	assert_eq(dispatch.status("tobin", 500), "Injured · 0:08")
	assert_false(dispatch.can_go("tobin", 500))
	dispatch.checkpoint(1_000)
	dispatch.checkpoint(1_020)
	assert_eq(gold.amount, 0)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(dispatch.injury_left("tobin", 1_029), 1)
	assert_true(dispatch.can_go("tobin", 1_030))


func test_a_clock_set_back_mid_quest_adds_no_time_to_the_countdown() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	_send_to_succeed(dispatch, "moonherbs", 1_000)
	dispatch.checkpoint(1_003)
	dispatch.checkpoint(500)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 500), 3)
	dispatch.checkpoint(1_006)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 10)


func test_with_the_party_home_time_passing_adds_no_gold() -> void:
	var gold := Gold.new(70)
	var dispatch := _guild(1_000)
	dispatch.checkpoint(1_000 + 3_600)
	assert_eq(gold.amount, 70)
	assert_true(_send_to_succeed(dispatch, "rats", 4_600))
	dispatch.checkpoint(4_602 + 3_600)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 73)


func test_a_quest_in_progress_survives_save_and_load() -> void:
	var gold := Gold.new(30)
	var dispatch := _guild(1_000)
	_send_to_succeed(dispatch, "moonherbs", 1_000)
	dispatch.checkpoint(1_003)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded.outings[0]["quest"], "moonherbs")
	assert_eq(loaded.seconds_left(loaded.outings[0], 1_003), 3)
	assert_eq(loaded.outings.size(), 1)
	loaded.checkpoint(1_005)
	assert_eq(loaded_gold.amount, 30)
	loaded.checkpoint(1_006)
	_read_all(loaded, loaded_gold)
	assert_eq(loaded_gold.amount, 40)


func test_a_party_out_and_an_injury_survive_save_and_load_with_the_same_outcome() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_022)
	var party: PackedStringArray = ["bram", "maren"]
	var roll_seed := _seed("moonherbs", party, false)
	dispatch.send("moonherbs", party, roll_seed, 1_023)
	dispatch.checkpoint(1_024)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 99_999)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(_statuses(loaded, 1_024), ["On quest: Gather moonherbs", "Resting", "Debrief waiting", "On quest: Gather moonherbs"])
	assert_eq(loaded.injury_left("tobin", 1_024), 6)
	assert_eq(loaded.debriefs, [{"quest": "goblins", "returned_at": 1_020, "success": false, "party": PackedStringArray(["tobin"]), "damage": {"tobin": 22}, "injured": {"tobin": 10}, "gold": 0, "xp": 7, "revealed": PackedStringArray(["Navigation"]), "loot": PackedStringArray(), "paid": false, "xp_given": true}])
	assert_eq(loaded.outings[0]["seed"], roll_seed)
	assert_eq(loaded.seconds_left(loaded.outings[0], 1_024), 5)
	loaded.checkpoint(1_040)
	dispatch.checkpoint(1_040)
	assert_eq(loaded.debriefs, dispatch.debriefs)
	assert_eq(_statuses(loaded, 1_040), _statuses(dispatch, 1_040))
	_read_all(loaded, loaded_gold)
	assert_eq(loaded_gold.amount, 0)


func test_an_m2_save_loads_with_its_gold_kept_and_the_party_home() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 300)
	file.set_value("gold", "saved_at", 1_000)
	Hall.new(1_000).write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_true(dispatch.outings.is_empty())
	assert_true(dispatch.can_go("bram", 2_000))
	dispatch.checkpoint(2_000)
	assert_eq(gold.amount, 300)
	assert_true(_send_to_succeed(dispatch, "rats", 2_000))


func _m3_save(quest: String) -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 20)
	file.set_value("dispatch", "quest", quest)
	file.set_value("dispatch", "quest_since", 1_000)
	file.set_value("dispatch", "checked_at", 1_010)
	assert_eq(file.save(SAVE_PATH), OK)


func test_an_m3_save_with_the_party_out_pays_that_quest_in_full_on_return_with_no_injuries() -> void:
	_m3_save("goblins")
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_eq(dispatch.outings.size(), 1)
	assert_eq(_statuses(dispatch, 1_010), ["Resting", "Resting", "Resting", "Resting"])
	dispatch.checkpoint(1_019)
	assert_eq(gold.amount, 20)
	dispatch.checkpoint(1_020)
	assert_eq(dispatch.debriefs, [{"quest": "goblins", "returned_at": 1_020, "success": true, "party": PackedStringArray(), "damage": {}, "injured": {}, "gold": 42, "xp": 30, "revealed": PackedStringArray(["Navigation"]), "loot": PackedStringArray(), "paid": false, "xp_given": true}])
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 62)
	assert_eq(_statuses(dispatch, 1_020), ["Resting", "Resting", "Resting", "Resting"])
	assert_true(dispatch.outings.is_empty())


func test_an_m3_save_with_the_party_home_loads_with_all_four_resting() -> void:
	_m3_save("")
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_true(dispatch.outings.is_empty())
	assert_eq(_statuses(dispatch, 2_000), ["Resting", "Resting", "Resting", "Resting"])
	assert_eq(gold.amount, 20)
	assert_true(_send_to_succeed(dispatch, "rats", 2_000))


func test_a_save_naming_an_unknown_quest_loads_with_nobody_out() -> void:
	_m3_save("dragons")
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_true(dispatch.outings.is_empty())
	assert_true(dispatch.can_go("bram", 2_000))
	dispatch.checkpoint(99_000)
	assert_eq(gold.amount, 20)
	assert_true(dispatch.debriefs.is_empty())
	assert_true(_send_to_succeed(dispatch, "rats", 99_000))


## A hall at 1_000 converting `back_left` into `type`: restored by 1_001, converted from 1_120 to
## 1_122.
func _hall_converting(type: String, gold: Gold) -> Hall:
	var hall := _six_room_hall(1_000)
	assert_true(hall.restore("back_left", gold, 1_000))
	assert_true(hall.convert_room("back_left", type, gold, 1_120))
	return hall


func test_save_from_previous_build_loads() -> void:
	var start := 20_001 * 86_400
	var gold := Gold.new(1_000)
	var hall := _six_room_hall(start)
	assert_true(hall.restore("back_left", gold, start))
	assert_true(hall.convert_room("back_left", "quest_hall", gold, start + 120))
	hall.checkpoint(start + 180)
	var dispatch := _guild(start)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), start + 200)
	_worn_out(dispatch, "tobin")
	dispatch.send("goblins", ["bram", "ilse"], 1, start + 205)
	dispatch.checkpoint(start + 206)
	_read_all(dispatch, gold)
	# The previous build wrote these three sections, and no board.
	var file := ConfigFile.new()
	gold.write(file)
	hall.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	var loaded_hall := Hall.load_or_start(SAVE_PATH, start + 207)
	var loaded := Dispatch.load_or_start(SAVE_PATH, start + 207)
	var board := Board.load_or_start(SAVE_PATH)
	board.reception_slots = loaded_hall.reception("board_slots")
	assert_eq(loaded_gold.amount, 1_000 - 60 - 60)
	assert_eq(loaded_hall.room_type("back_left"), "quest_hall")
	assert_eq(loaded_hall.rooms_done("quest_hall", start + 207), 1)
	assert_eq(_statuses(loaded, start + 207), ["On quest: Goblin camp", "On quest: Goblin camp", "Injured · 0:05", "Resting"])
	assert_eq(loaded.seconds_left(loaded.outings[0], start + 207), 18)
	# Four slots with the Quest hall, filled with any quest but goblins, still out.
	board.refill(loaded, start + 207, PackedInt64Array([start + 122]))
	assert_eq(board.slots, PackedStringArray(["wolves", "spiders", "cartographer", "mouth"]))


func test_an_injury_lasts_5_seconds_with_an_infirmary_finished_before_the_return() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	var dispatch := _guild(1_000)
	# Returns at 1_220; the Infirmary finished at 1_122, while the app was away.
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_200)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_222, hall.first_done_at("infirmary"))
	_read_all(dispatch, gold)
	assert_eq(dispatch.injury_left("tobin", 1_222), 3)
	assert_eq(dispatch.injury_seconds("tobin"), 5)
	assert_eq(dispatch.status("tobin", 1_222), "Injured · 0:03")
	assert_true(dispatch.can_go("tobin", 1_225))


func test_an_injury_lasts_10_seconds_when_the_infirmary_finishes_after_the_return() -> void:
	var gold := Gold.new(1_000)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_001)
	hall.convert_room("back_left", "infirmary", gold, 1_019)
	# Away until 1_022: the party returned at 1_020, the Infirmary finished at 1_021, and the hall
	# took its checkpoint first.
	hall.checkpoint(1_022)
	dispatch.checkpoint(1_022, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_022), 8)
	dispatch.checkpoint(1_025, hall.first_done_at("infirmary"))
	_read_all(dispatch, gold)
	assert_eq(dispatch.injury_seconds("tobin"), 10)
	assert_eq(dispatch.injury_left("tobin", 1_029), 1)
	assert_true(dispatch.can_go("tobin", 1_030))


func test_an_injury_keeps_its_length_through_save_and_load() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	var dispatch := _guild(1_000)
	dispatch.send("rats", ["bram"], _seed("rats", ["bram"], false), 1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_110)
	_worn_out(dispatch, "tobin")
	_worn_out(dispatch, "bram")
	# Bram returned at 1_002, before the Infirmary; Tobin at 1_130, after it.
	dispatch.checkpoint(1_100, hall.first_done_at("infirmary"))
	dispatch.checkpoint(1_132, hall.first_done_at("infirmary"))
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_132)
	assert_eq(loaded.injury_seconds("tobin"), 5)
	assert_eq(loaded.injury_seconds("bram"), 10)
	assert_eq(loaded.injury_left("tobin", 1_132), 3)


func test_an_injury_saved_before_lengths_were_kept_loads_as_the_long_injury() -> void:
	var file := ConfigFile.new()
	file.set_value("dispatch", "outings", [])
	file.set_value("dispatch", "injured_until", {"tobin": 1_750})
	file.set_value("dispatch", "checked_at", 1_700)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_700)
	assert_eq(loaded.injury_left("tobin", 1_700), 50)
	assert_eq(loaded.injury_seconds("tobin"), 10)


func test_two_infirmaries_still_heal_in_5_seconds() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	hall.restore("back_right", gold, 1_180)
	# A second Infirmary, as a save from before rooms were unique can hold.
	hall.converted["back_right"] = {"type": "infirmary", "done_at": 1_360}
	hall.checkpoint(1_360)
	assert_eq(hall.rooms_done("infirmary", 1_360), 2)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_400)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_421, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_421), 4)


func test_two_parties_back_in_the_same_checkpoint_come_home_in_the_order_they_returned() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["bram", "ilse"], _seed("goblins", ["bram", "ilse"], true), 1_000)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), 1_010)
	# Rats came back at 1_012, the goblin camp at 1_020, though the goblin camp left first.
	dispatch.checkpoint(2_000)
	assert_true(dispatch.outings.is_empty())
	assert_eq(_debriefed_quests(dispatch), ["rats", "goblins"])
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 42)


func test_a_clock_set_back_never_changes_an_injury_already_decided() -> void:
	var gold := Gold.new(1_000)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_001)
	hall.convert_room("back_left", "infirmary", gold, 1_019)
	hall.checkpoint(1_025)
	dispatch.checkpoint(1_025, hall.first_done_at("infirmary"))
	_read_all(dispatch, gold)
	assert_eq(dispatch.injury_left("tobin", 1_025), 5)
	assert_eq(gold.amount, 1_000 - 60 - 60)

	# Set back to before the return and the Infirmary: nothing is re-decided, repaid or re-charged.
	hall.checkpoint(1_015)
	dispatch.checkpoint(1_015, hall.first_done_at("infirmary"))
	assert_eq(hall.state("back_left", 1_015), Hall.State.CONVERTED)
	assert_eq(dispatch.injury_left("tobin", 1_015), 5)
	assert_true(dispatch.outings.is_empty())
	dispatch.checkpoint(1_027, hall.first_done_at("infirmary"))
	assert_eq(dispatch.injury_left("tobin", 1_029), 1)
	assert_eq(gold.amount, 1_000 - 60 - 60)


var rats_debrief: Dictionary = {"quest": "rats", "returned_at": 1_012, "success": false, "party": PackedStringArray(["tobin"]), "damage": {"tobin": 12}, "injured": {}, "gold": 0, "xp": 1, "revealed": PackedStringArray(), "loot": PackedStringArray(), "paid": false, "xp_given": true}
var goblins_debrief: Dictionary = {"quest": "goblins", "returned_at": 1_020, "success": true, "party": PackedStringArray(["bram", "ilse"]), "damage": {"bram": 8, "ilse": 10}, "injured": {}, "gold": 42, "xp": 15, "revealed": PackedStringArray(["Navigation"]), "loot": PackedStringArray(["short_sword"]), "paid": false, "xp_given": true}


## Goblin camp succeeds for Bram and Ilse, sent at 1_000 (back at 1_020); Rats in the cellar
## fails for Tobin, sent at 1_010 (back at 1_012). Brought home at 1_015 and 2_000.
func _two_returns() -> Dispatch:
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["bram", "ilse"], _seed("goblins", ["bram", "ilse"], true), 1_000)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), 1_010)
	dispatch.checkpoint(1_015)
	dispatch.checkpoint(2_000)
	return dispatch


func test_a_returned_party_adds_a_debrief_with_its_quest_result_party_injured_member_and_gold() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_converting("infirmary", gold)
	var dispatch := _guild(1_000)
	dispatch.send("moonherbs", PARTY, _seed("moonherbs", PARTY, false), 1_120)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_125, hall.first_done_at("infirmary"))
	assert_true(dispatch.debriefs.is_empty())
	dispatch.checkpoint(1_200, hall.first_done_at("infirmary"))
	# A failure's 1 XP shared by three would be 0 each, but every member gains at least 1.
	assert_eq(dispatch.debriefs, [{"quest": "moonherbs", "returned_at": 1_126, "success": false, "party": PARTY, "damage": {"bram": 5, "ilse": 8, "tobin": 8}, "injured": {"tobin": 5}, "gold": 0, "xp": 1, "revealed": PackedStringArray(["Attrition"]), "loot": PackedStringArray(["leather_jerkin"]), "paid": false, "xp_given": true}])


func test_two_returns_give_two_debriefs_in_the_order_they_came_back() -> void:
	var dispatch := _two_returns()
	assert_eq(dispatch.debriefs, [rats_debrief, goblins_debrief])


func test_reading_a_debrief_files_only_that_one_and_pays_only_its_party() -> void:
	var gold := Gold.new(0)
	var dispatch := _two_returns()
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.injury_left("tobin", 2_000), 0)
	dispatch.read_debrief(0, gold)
	assert_eq(dispatch.debriefs, [goblins_debrief])
	assert_eq(gold.amount, 0)
	assert_eq(_statuses(dispatch, 2_000), ["Debrief waiting", "Debrief waiting", "Resting", "Resting"])
	dispatch.checkpoint(2_100)
	assert_eq(gold.amount, 0)
	dispatch.read_debrief(0, gold)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 42)
	assert_eq(_statuses(dispatch, 2_100), ["Resting", "Resting", "Resting", "Resting"])


func test_reading_a_debrief_leaves_an_injury_running() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_005)
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.status("tobin", 1_005), "Debrief waiting")
	dispatch.read_debrief(0, gold)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 0)
	assert_eq(dispatch.status("tobin", 1_005), "Injured · 0:07")


func test_debriefs_survive_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := _two_returns()
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 2_000)
	assert_eq(loaded.debriefs, [rats_debrief, goblins_debrief])
	loaded.read_debrief(1, gold)
	loaded.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	assert_eq(Dispatch.load_or_start(SAVE_PATH, 2_000).debriefs, [rats_debrief])


## Bram and Ilse sent at 1_000 on Goblin camp with a seed they succeed with and bring loot back
## from: back at 1_020 with 42 gold, 15 XP each and the loot.
func _goblins_with_loot() -> Dispatch:
	var party: PackedStringArray = ["bram", "ilse"]
	var chance := _guild(0).success_chance("goblins", party)
	var roll_seed := -1
	for candidate: int in 10_000:
		if Outcome.roll(candidate, chance, Outcome.MOST_DAMAGE["E"], party).success and not Gear.loot(candidate, "E").is_empty():
			roll_seed = candidate
			break
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("goblins", party, roll_seed, 1_000))
	return dispatch


func test_after_a_return_its_xp_is_given_but_gold_and_the_stash_are_unchanged_and_the_party_cannot_go() -> void:
	var gold := Gold.new(100)
	var dispatch := _goblins_with_loot()
	dispatch.checkpoint(1_020)
	assert_eq(dispatch.debriefs.size(), 1)
	assert_eq(gold.amount, 100)
	# XP comes home with the party, so a member can level up from the debrief.
	assert_eq(_xp(dispatch), [15, 15, 0, 0])
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray())
	assert_eq(_statuses(dispatch, 1_020), ["Debrief waiting", "Debrief waiting", "Resting", "Resting"])
	assert_false(dispatch.can_go("bram", 1_020))
	assert_true(dispatch.can_go("tobin", 1_020))
	assert_eq(dispatch.party_refusal("rats", ["tobin", "bram"], 1_020), "Bram can't go")
	assert_false(dispatch.send("rats", ["bram"], 1, 1_020))
	# However long it waits unread, nothing more is paid and nobody is freed.
	dispatch.checkpoint(9_000)
	assert_eq(gold.amount, 100)
	assert_eq(_xp(dispatch), [15, 15, 0, 0])
	assert_false(dispatch.can_go("ilse", 9_000))


func test_while_the_debrief_waits_healing_and_injuries_count_from_the_return() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("goblins", ["bram"], _seed("goblins", ["bram"], false), 1_000))
	_worn_out(dispatch, "bram")
	# Tobin fails Gather moonherbs with seed 127: back at 1_020 with 5 of his 16 health.
	assert_true(dispatch.send("moonherbs", ["tobin"], 127, 1_014))
	# Both came back at 1_020; the first checkpoint after is at 1_022, and nothing is read.
	dispatch.checkpoint(1_022)
	assert_eq(dispatch.debriefs.size(), 2)
	assert_eq(dispatch.health("tobin", 1_022), 8)
	assert_eq(dispatch.injury_left("bram", 1_022), 8)
	assert_eq(dispatch.status("bram", 1_022), "Debrief waiting")
	# Reading changes neither.
	_read_all(dispatch, gold)
	assert_eq(dispatch.health("tobin", 1_022), 8)
	assert_eq(dispatch.injury_left("bram", 1_022), 8)
	assert_eq(dispatch.status("bram", 1_022), "Injured · 0:08")


func test_reading_the_debrief_pays_exactly_its_gold_and_loot_gives_no_xp_twice_and_frees_its_party() -> void:
	var gold := Gold.new(100)
	var dispatch := _goblins_with_loot()
	var item := Gear.loot(dispatch.outings[0]["seed"], "E")
	dispatch.checkpoint(1_020)
	assert_eq(dispatch.debriefs[0]["gold"], 42)
	assert_eq(dispatch.debriefs[0]["xp"], 15)
	assert_eq(dispatch.debriefs[0]["loot"], PackedStringArray([item]))
	dispatch.read_debrief(0, gold)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 142)
	assert_eq(_xp(dispatch), [15, 15, 0, 0])
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray([item]))
	assert_eq(_statuses(dispatch, 1_020), ["Resting", "Resting", "Resting", "Resting"])
	assert_true(dispatch.can_go("bram", 1_020))
	assert_true(dispatch.send("rats", ["bram", "ilse"], 1, 1_020))


func test_loot_that_finds_the_stash_full_when_the_debrief_is_read_is_lost_and_the_debrief_says_so() -> void:
	var gold := Gold.new(0)
	var dispatch := _goblins_with_loot()
	var item := Gear.loot(dispatch.outings[0]["seed"], "E")
	var expected := PackedStringArray()
	for i: int in dispatch.adventurers.gear.stash_cap - 1:
		assert_true(dispatch.adventurers.gear.stow("belt"))
		expected.append("belt")
	dispatch.checkpoint(1_020)
	# One place left as the party comes back: reading now would stow it.
	assert_eq(dispatch.debrief_loot(dispatch.debriefs[0]), {"loot": PackedStringArray([item]), "lost": PackedStringArray()})
	# The stash fills before the debrief is read.
	assert_true(dispatch.adventurers.gear.stow("sash"))
	expected.append("sash")
	assert_eq(dispatch.debrief_loot(dispatch.debriefs[0]), {"loot": PackedStringArray(), "lost": PackedStringArray([item])})
	dispatch.read_debrief(0, gold)
	assert_eq(dispatch.adventurers.gear.stash, expected)
	assert_eq(gold.amount, 42)


func test_a_member_with_two_unread_debriefs_is_available_only_once_both_are_read() -> void:
	# The build before reading paid let Bram go again with his debrief unread.
	var file := ConfigFile.new()
	file.set_value("dispatch", "debriefs", [{"quest": "rats", "returned_at": 900, "success": true, "party": PackedStringArray(["bram"]), "damage": {"bram": 1}, "injured": {}, "gold": 50, "xp": 4, "revealed": PackedStringArray(), "loot": PackedStringArray(), "lost": PackedStringArray()}])
	file.set_value("dispatch", "outings", [{"quest": "rats", "since": 1_000, "party": PackedStringArray(["bram"]), "seed": _seed("rats", ["bram"], true)}])
	file.set_value("dispatch", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)
	var gold := Gold.new(0)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	dispatch.checkpoint(1_002)
	assert_eq(dispatch.debriefs.size(), 2)
	assert_false(dispatch.can_go("bram", 1_002))
	dispatch.read_debrief(1, gold)
	assert_false(dispatch.can_go("bram", 1_002))
	assert_eq(dispatch.status("bram", 1_002), "Debrief waiting")
	dispatch.read_debrief(0, gold)
	assert_true(dispatch.can_go("bram", 1_002))
	assert_eq(dispatch.status("bram", 1_002), "Resting")
	# Only the debrief from this build paid.
	assert_eq(gold.amount, 3)


func test_an_unread_debrief_saved_before_xp_came_home_with_the_party_gives_its_xp_when_read() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 100)
	file.set_value("dispatch", "debriefs", [{"quest": "goblins", "returned_at": 900, "success": true, "party": PackedStringArray(["bram", "ilse"]), "damage": {"bram": 9, "ilse": 12}, "injured": {}, "gold": 500, "xp": 40, "revealed": PackedStringArray(), "loot": PackedStringArray(), "paid": false}])
	file.set_value("dispatch", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_eq(_xp(dispatch), [0, 0, 0, 0])
	dispatch.read_debrief(0, gold)
	assert_eq(gold.amount, 600)
	assert_eq(_xp(dispatch), [40, 40, 0, 0])


func test_a_debrief_saved_before_reading_paid_is_not_paid_again_when_read() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 640)
	file.set_value("dispatch", "debriefs", [{"quest": "goblins", "returned_at": 900, "success": true, "party": PackedStringArray(["bram", "ilse"]), "damage": {"bram": 9, "ilse": 12}, "injured": {}, "gold": 500, "xp": 40, "revealed": PackedStringArray(), "loot": PackedStringArray(["night_cloak"]), "lost": PackedStringArray(["sash"])}])
	file.set_value("dispatch", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	# It shows what it paid then.
	assert_eq(dispatch.debrief_loot(dispatch.debriefs[0]), {"loot": PackedStringArray(["night_cloak"]), "lost": PackedStringArray(["sash"])})
	dispatch.read_debrief(0, gold)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 640)
	assert_eq(_xp(dispatch), [0, 0, 0, 0])
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray())
	assert_true(dispatch.can_go("bram", 1_000))


func test_an_unpaid_debrief_survives_save_and_load_and_pays_once_when_read() -> void:
	var gold := Gold.new(100)
	var dispatch := _goblins_with_loot()
	var item := Gear.loot(dispatch.outings[0]["seed"], "E")
	dispatch.checkpoint(1_020)
	var file := ConfigFile.new()
	gold.write(file)
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_020)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded.debriefs, dispatch.debriefs)
	assert_eq(loaded_gold.amount, 100)
	assert_false(loaded.can_go("bram", 1_020))
	loaded.read_debrief(0, loaded_gold)
	assert_eq(loaded_gold.amount, 142)
	assert_eq(_xp(loaded), [15, 15, 0, 0])
	assert_eq(loaded.adventurers.gear.stash, PackedStringArray([item]))
	assert_true(loaded.can_go("bram", 1_020))
	# Saved and loaded again, nothing is paid twice.
	file = ConfigFile.new()
	loaded_gold.write(file)
	loaded.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var again := Dispatch.load_or_start(SAVE_PATH, 1_020)
	var again_gold := Gold.load_or_start(SAVE_PATH)
	_read_all(again, again_gold)
	assert_eq(again_gold.amount, 142)
	assert_eq(_xp(again), [15, 15, 0, 0])
	assert_eq(again.adventurers.gear.stash, PackedStringArray([item]))


func test_one_checkpoint_after_an_absence_equals_checkpointing_every_second() -> void:
	var runs: Array[Dispatch] = []
	var golds: Array[Gold] = []
	for every_second: bool in [false, true]:
		var gold := Gold.new(0)
		var dispatch := _guild(1_000)
		dispatch.send("goblins", ["bram", "ilse"], _seed("goblins", ["bram", "ilse"], true), 1_000)
		dispatch.send("rats", ["tobin"], _seed("rats", ["tobin"], false), 1_010)
		_worn_out(dispatch, "tobin")
		if every_second:
			for now: int in range(1_011, 2_000):
				dispatch.checkpoint(now)
		dispatch.checkpoint(2_000)
		runs.append(dispatch)
		golds.append(gold)
	assert_eq(runs[1].debriefs, runs[0].debriefs)
	assert_eq(runs[0].debriefs.size(), 2)
	assert_eq(_healths(runs[1], 2_000), _healths(runs[0], 2_000))
	assert_eq(_statuses(runs[1], 2_000), _statuses(runs[0], 2_000))
	assert_eq(golds[1].amount, golds[0].amount)
	# Each return is a try, counted once however often the guild checked.
	assert_eq(runs[0].tries, {"goblins": 1, "rats": 1})
	assert_eq(runs[1].tries, runs[0].tries)
	for i: int in 2:
		_read_all(runs[i], golds[i])
	assert_eq(golds[0].amount, 42)
	assert_eq(golds[1].amount, 42)
	assert_eq(_xp(runs[1]), _xp(runs[0]))
	assert_eq(runs[1].adventurers.gear.stash, runs[0].adventurers.gear.stash)
	assert_eq(_statuses(runs[1], 2_000), _statuses(runs[0], 2_000))


func test_a_debrief_says_how_many_whole_minutes_ago_the_party_came_back() -> void:
	var dispatch := _two_returns()
	assert_eq(dispatch.back_label(goblins_debrief, 2_000), "Back 16 min ago")
	# Rats came back 8 seconds before the goblin camp.
	assert_eq(dispatch.back_label(rats_debrief, 2_032), "Back 17 min ago")
	assert_eq(dispatch.back_label(goblins_debrief, 2_032), "Back 16 min ago")
	assert_eq(dispatch.back_label(goblins_debrief, 2_039), "Back 16 min ago")
	assert_eq(dispatch.back_label(goblins_debrief, 2_040), "Back 17 min ago")
	# A clock set back never makes a return more recent.
	assert_eq(dispatch.back_label(goblins_debrief, 1_000), "Back 16 min ago")
	var fresh := _guild(1_000)
	_send_to_succeed(fresh, "rats", 1_000)
	fresh.checkpoint(1_002)
	assert_eq(fresh.back_label(fresh.debriefs[0], 1_061), "Back just now")
	assert_eq(fresh.back_label(fresh.debriefs[0], 1_062), "Back 1 min ago")


func test_a_save_from_before_debriefs_loads_with_none_and_nothing_lost() -> void:
	# What the build before debriefs wrote: the latest return in words, and no debriefs.
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 640)
	file.set_value("dispatch", "outings", [{"quest": "rats", "since": 1_049, "party": PackedStringArray(["bram"]), "seed": _seed("rats", ["bram"], true)}])
	file.set_value("dispatch", "injured_until", {"tobin": 1_200})
	file.set_value("dispatch", "injury_lengths", {"tobin": 150})
	file.set_value("dispatch", "last_return", "Goblin camp: failed · +125 gold · Tobin injured")
	file.set_value("dispatch", "checked_at", 1_050)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_050)
	assert_true(dispatch.debriefs.is_empty())
	assert_eq(gold.amount, 640)
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_050), 1)
	assert_eq(dispatch.injury_left("tobin", 1_050), 150)
	assert_eq(dispatch.injury_seconds("tobin"), 150)
	dispatch.checkpoint(1_051)
	assert_eq(dispatch.debriefs, [{"quest": "rats", "returned_at": 1_051, "success": true, "party": PackedStringArray(["bram"]), "damage": {"bram": 2}, "injured": {}, "gold": 3, "xp": 4, "revealed": PackedStringArray(), "loot": PackedStringArray(), "paid": false, "xp_given": true}])
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 643)


func _xp(dispatch: Dispatch) -> Array[int]:
	var xp: Array[int] = []
	for adventurer: String in EVERYONE:
		xp.append(dispatch.adventurers.xp[adventurer])
	return xp


func test_every_member_of_a_returning_party_gains_an_equal_share_of_its_xp_and_a_quarter_as_much_on_a_failure() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("moonherbs", ["bram", "maren"], _seed("moonherbs", ["bram", "maren"], true), 1_000)
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	dispatch.checkpoint(1_005)
	assert_eq(_xp(dispatch), [0, 0, 0, 0])
	# Moonherbs gives 8 XP, 4 each for two; goblin camp 30, a quarter rounded down for failing: 7.
	dispatch.checkpoint(1_006)
	assert_eq(dispatch.debriefs[0]["xp"], 4)
	_read_all(dispatch, gold)
	assert_eq(_xp(dispatch), [4, 0, 0, 4])
	dispatch.checkpoint(1_020)
	assert_eq(dispatch.debriefs[0]["xp"], 7)
	_read_all(dispatch, gold)
	assert_eq(_xp(dispatch), [4, 0, 7, 4])
	dispatch.checkpoint(5_000)
	assert_eq(_xp(dispatch), [4, 0, 7, 4])


## The debrief XP and each starter's XP after `party` comes back from `quest`, sent with a seed
## that ends in `success`.
func _xp_from(quest: String, party: PackedStringArray, success: bool) -> Array:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send(quest, party, _seed(quest, party, success), 1_000))
	dispatch.checkpoint(1_000 + int(Dispatch.QUESTS[quest]["seconds"]))
	return [dispatch.debriefs[0]["xp"], _xp(dispatch)]


func test_a_solo_member_gains_a_quests_whole_xp_and_each_of_four_a_quarter_rounded_down_but_at_least_1() -> void:
	# Escorting the cartographer gives 7 XP: 1 each for four. Rats gives 4 XP: 2 each for two.
	assert_eq(_xp_from("cartographer", ["bram"], true), [7, [7, 0, 0, 0]])
	assert_eq(_xp_from("cartographer", PackedStringArray(EVERYONE), true), [1, [1, 1, 1, 1]])
	assert_eq(_xp_from("rats", ["bram", "tobin"], true), [2, [2, 0, 2, 0]])
	# Goblin camp gives 30 XP: 7 each for four.
	assert_eq(_xp_from("goblins", ["tobin"], true), [30, [0, 0, 30, 0]])
	assert_eq(_xp_from("goblins", PackedStringArray(EVERYONE), true), [7, [7, 7, 7, 7]])


func test_a_failure_pays_no_gold_and_a_quarter_of_the_xp_but_at_least_1_shared_by_the_party() -> void:
	# Goblin camp's 30 XP, a quarter rounded down for failing: 7 alone, and at least 1 each for four.
	assert_eq(_xp_from("goblins", ["tobin"], false), [7, [0, 0, 7, 0]])
	assert_eq(_xp_from("goblins", PackedStringArray(EVERYONE), false), [1, [1, 1, 1, 1]])
	# Rats' 4 XP: a quarter is 1; two would share it as 0 each, but every member gains at least 1.
	assert_eq(_xp_from("rats", ["tobin"], false), [1, [0, 0, 1, 0]])
	assert_eq(_xp_from("rats", ["bram", "tobin"], false), [1, [1, 0, 1, 0]])
	var gold := Gold.new(50)
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000))
	dispatch.checkpoint(1_020)
	assert_false(dispatch.debriefs[0]["success"])
	assert_eq(dispatch.debriefs[0]["gold"], 0)
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 50)
	assert_eq(_xp(dispatch), [0, 0, 7, 0])


func test_a_success_pays_each_quests_new_gold_in_its_debrief() -> void:
	var expected := {"rats": 3, "well": 5, "letters": 7, "spiders": 7, "cartographer": 8, "mouth": 8, "moonherbs": 10, "wolves": 22, "sealed_door": 25, "lurker": 30, "crypt": 33, "pilgrims": 38, "goblins": 42, "maze": 87, "chapel": 100, "minotaur": 113, "envoy": 125, "vault": 150}
	var paid := {}
	for quest: String in Dispatch.QUESTS:
		var dispatch := _guild(1_000)
		for adventurer: String in PARTY:
			dispatch.adventurers.roster[adventurer]["rank"] = "E"
		assert_true(_send_to_succeed(dispatch, quest, 1_000), quest)
		dispatch.checkpoint(1_000 + int(Dispatch.QUESTS[quest]["seconds"]))
		paid[quest] = dispatch.debriefs[0]["gold"]
	assert_eq(paid, expected)


func test_each_quest_takes_its_own_seconds_and_a_success_gives_its_party_its_own_xp() -> void:
	var seconds := {"rats": 2, "well": 3, "letters": 4, "spiders": 4, "cartographer": 5, "mouth": 5, "moonherbs": 6, "wolves": 10, "sealed_door": 12, "lurker": 14, "crypt": 16, "pilgrims": 18, "goblins": 20, "maze": 30, "chapel": 36, "minotaur": 40, "envoy": 50, "vault": 60}
	var xp := {"rats": 4, "well": 5, "letters": 6, "spiders": 6, "cartographer": 7, "mouth": 7, "moonherbs": 8, "wolves": 15, "sealed_door": 18, "lurker": 21, "crypt": 24, "pilgrims": 27, "goblins": 30, "maze": 50, "chapel": 60, "minotaur": 67, "envoy": 83, "vault": 100}
	var took := {}
	var gave := {}
	for quest: String in Dispatch.QUESTS:
		var dispatch := _guild(1_000)
		# Alone, so the debrief's share is the whole; rank E, so rank D quests take him.
		dispatch.adventurers.roster["bram"]["rank"] = "E"
		assert_true(dispatch.send(quest, ["bram"], _seed(quest, ["bram"], true), 1_000), quest)
		took[quest] = dispatch.seconds_left(dispatch.outings[0], 1_000)
		dispatch.checkpoint(1_000 + took[quest])
		assert_true(dispatch.debriefs[0]["success"], quest)
		gave[quest] = dispatch.debriefs[0]["xp"]
	assert_eq(took, seconds)
	assert_eq(gave, xp)


func test_an_unread_debrief_saved_before_smaller_rewards_pays_the_gold_and_xp_it_holds() -> void:
	# A failed Goblin camp as the build before wrote it: a quarter of 500 gold, half of 40 XP.
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 100)
	file.set_value("dispatch", "debriefs", [{"quest": "goblins", "returned_at": 900, "success": false, "party": PackedStringArray(["bram", "ilse"]), "damage": {"bram": 9, "ilse": 12}, "injured": {}, "gold": 125, "xp": 20, "revealed": PackedStringArray(), "loot": PackedStringArray(), "paid": false, "xp_given": true}])
	# Its XP came home with the party.
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gain_xp("bram", 20)
	adventurers.gain_xp("ilse", 20)
	adventurers.write(file)
	file.set_value("dispatch", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)
	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_eq(dispatch.debriefs[0]["gold"], 125)
	assert_eq(dispatch.debriefs[0]["xp"], 20)
	dispatch.read_debrief(0, gold)
	assert_eq(gold.amount, 225)
	assert_eq(_xp(dispatch), [20, 20, 0, 0])


func test_xp_banks_past_several_level_ups_and_an_adventurer_with_one_waiting_can_still_be_sent() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	var party: PackedStringArray = ["bram", "ilse"]
	var now := 1_000
	for quest: int in 2:
		assert_true(dispatch.send("goblins", party, _seed("goblins", party, true), now))
		# Back after 20 s, then healed to full before the next.
		now += 1_000
		dispatch.checkpoint(now)
		_read_all(dispatch, gold)
	# 15 XP each a goblin camp shared by two: two are enough for level 2 (10) and level 3 (20).
	assert_eq(dispatch.adventurers.xp["bram"], 30)
	assert_true(dispatch.adventurers.level_up_ready("bram"))
	assert_true(dispatch.can_go("bram", now))
	assert_eq(dispatch.adventurers.level_up("bram").size(), 9)
	assert_eq(dispatch.adventurers.xp["bram"], 20)
	assert_true(dispatch.adventurers.level_up_ready("bram"))
	dispatch.adventurers.level_up("bram")
	assert_eq(dispatch.adventurers.levels["bram"], 3)
	assert_eq(dispatch.adventurers.xp["bram"], 0)
	assert_false(dispatch.adventurers.level_up_ready("bram"))
	assert_eq(dispatch.adventurers.levels["ilse"], 1)


func test_a_level_up_while_out_never_changes_how_the_quest_ends() -> void:
	var dispatch := _guild(1_000)
	var grown := _guild(1_000)
	for each: Dispatch in [dispatch, grown]:
		each.adventurers.gain_xp("tobin", 1_000_000)
	for level: int in 10:
		grown.adventurers.level_up("tobin")
	var chance := dispatch.success_chance("goblins", ["tobin"])
	var grown_chance := grown.success_chance("goblins", ["tobin"])
	assert_gt(grown_chance, chance)
	var roll_seed := -1
	for candidate: int in 10_000:
		if not Outcome.roll(candidate, chance, 12, ["tobin"]).success and Outcome.roll(candidate, grown_chance, 12, ["tobin"]).success:
			roll_seed = candidate
			break
	assert_true(dispatch.send("goblins", ["tobin"], roll_seed, 1_000))
	for level: int in 10:
		dispatch.adventurers.level_up("tobin")
	assert_eq(dispatch.success_chance("goblins", ["tobin"]), grown_chance)
	dispatch.checkpoint(1_020)
	assert_false(dispatch.debriefs[0]["success"])


func _grow_defence(dispatch: Dispatch, adventurer: String) -> void:
	dispatch.adventurers.gain_xp(adventurer, 1_000_000)
	var defence_gain := 0
	while defence_gain == 0:
		defence_gain = dispatch.adventurers.level_up(adventurer)["defence"]


func test_a_level_up_while_out_never_changes_the_health_a_member_comes_back_with_or_their_injury() -> void:
	for grow: bool in [false, true]:
		var gold := Gold.new(0)
		var dispatch := _tobin_hurt(gold)
		# Rats in the cellar succeeds with seed 23 and deals Tobin 1: back with 4 of the 16 he left
		# with, exactly a quarter.
		assert_true(dispatch.send("rats", ["tobin"], 23, 1_020))
		assert_true(dispatch.send("rats", ["maren"], 7, 1_020))
		if grow:
			_grow_defence(dispatch, "tobin")
			_grow_defence(dispatch, "maren")
			assert_gt(dispatch.adventurers.max_health("tobin"), 16)
			assert_gt(dispatch.adventurers.max_health("maren"), 20)
		assert_eq(dispatch.health("tobin", 1_021), 5, "grown %s" % grow)
		assert_eq(dispatch.health("maren", 1_021), 20, "grown %s" % grow)
		dispatch.checkpoint(1_022)
		assert_eq(dispatch.health("tobin", 1_022), 4, "grown %s" % grow)
		for debrief: Dictionary in dispatch.debriefs:
			assert_true(debrief["injured"].is_empty(), "grown %s" % grow)
		_read_all(dispatch, gold)
		assert_true(dispatch.can_go("tobin", 1_022))


func _healths(dispatch: Dispatch, now: int) -> Array[int]:
	var healths: Array[int] = []
	for adventurer: String in EVERYONE:
		healths.append(dispatch.health(adventurer, now))
	return healths


## Tobin, at 16 health, fails Gather moonherbs sent at 1_014 with seed 127, which deals him 11:
## back at 1_020 with 5, his debrief read.
func _tobin_hurt(gold: Gold, infirmary_from: int = -1) -> Dispatch:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("moonherbs", ["tobin"], 127, 1_014))
	dispatch.checkpoint(1_020, infirmary_from)
	assert_eq(dispatch.debriefs[0]["damage"], {"tobin": 11})
	_read_all(dispatch, gold)
	return dispatch


func test_the_four_starters_are_at_full_health_from_defence() -> void:
	var dispatch := _guild(1_000)
	# Bram's iron cap and round shield add 2 to his Defence of 7.
	assert_eq(_healths(dispatch, 1_000), [28, 20, 16, 20])
	for adventurer: String in EVERYONE:
		assert_eq(dispatch.seconds_to_full(adventurer, 1_000), 0)


func test_damage_heals_three_points_every_2_seconds_in_whole_points_up_to_the_maximum() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	assert_eq(dispatch.health("tobin", 1_020), 5)
	assert_eq(dispatch.health("tobin", 1_021), 6)
	assert_eq(dispatch.health("tobin", 1_022), 8)
	assert_eq(dispatch.health("tobin", 1_027), 15)
	# Eleven points short: 22 seconds' worth at a point per 20, here 8 seconds.
	assert_eq(dispatch.seconds_to_full("tobin", 1_020), 8)
	assert_eq(dispatch.seconds_to_full("tobin", 1_024), 4)
	assert_eq(dispatch.health("tobin", 1_028), 16)
	assert_eq(dispatch.seconds_to_full("tobin", 1_028), 0)
	assert_eq(dispatch.health("tobin", 9_000), 16)
	assert_eq(dispatch.health("bram", 1_020), 28)


func test_an_infirmary_doubles_healing_from_the_moment_it_is_finished_not_before() -> void:
	var gold := Gold.new(1_000)
	var hall := _six_room_hall(1_000)
	hall.restore("back_left", gold, 1_000)
	hall.checkpoint(1_001)
	hall.convert_room("back_left", "infirmary", gold, 1_020)
	assert_eq(hall.first_done_at("infirmary"), 1_022)
	var dispatch := _tobin_hurt(gold, hall.first_done_at("infirmary"))
	assert_eq(dispatch.seconds_to_full("tobin", 1_020), 5)
	assert_eq(dispatch.health("tobin", 1_022), 8)
	# 2 s slow, then 1 s at double speed: 4 s worth, where all-slow gives 3 and all-fast 6.
	assert_eq(dispatch.health("tobin", 1_023), 11)
	assert_eq(dispatch.health("tobin", 1_024), 14)
	assert_eq(dispatch.health("tobin", 1_025), 16)


func test_a_clock_set_back_never_lowers_health_or_undoes_healing() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	dispatch.checkpoint(1_024)
	assert_eq(dispatch.health("tobin", 1_024), 11)
	dispatch.checkpoint(1_010)
	assert_eq(dispatch.health("tobin", 1_010), 11)
	assert_eq(dispatch.seconds_to_full("tobin", 1_010), 4)
	dispatch.checkpoint(1_022)
	assert_eq(dispatch.health("tobin", 1_022), 11)
	assert_eq(dispatch.health("tobin", 1_025), 12)


func test_a_hurt_adventurer_can_be_sent_heals_nothing_while_out_and_takes_damage_on_top() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	assert_true(dispatch.can_go("tobin", 1_020))
	assert_eq(dispatch.status("tobin", 1_020), "Resting")
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 1_020), "")
	# Rats in the cellar succeeds with seed 23 and deals him 1.
	assert_true(dispatch.send("rats", ["tobin"], 23, 1_020))
	assert_eq(dispatch.health("tobin", 1_021), 5)
	# No countdown to full while out: nobody heals there.
	assert_eq(dispatch.seconds_to_full("tobin", 1_021), 0)
	dispatch.checkpoint(1_022)
	assert_eq(dispatch.debriefs[0]["damage"], {"tobin": 1})
	assert_eq(dispatch.health("tobin", 1_022), 4)
	assert_eq(dispatch.health("tobin", 1_023), 5)
	# Exactly a quarter is not under it.
	assert_true(dispatch.debriefs[0]["injured"].is_empty())
	_read_all(dispatch, gold)
	assert_true(dispatch.can_go("tobin", 1_022))


func test_damage_never_takes_health_below_1_and_under_a_quarter_injures_until_the_timer_ends() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	# 22 more damage from a failed goblin camp, with 5 health left.
	assert_true(dispatch.send("goblins", ["tobin"], 0, 1_020))
	dispatch.checkpoint(1_040)
	assert_eq(dispatch.debriefs[0]["damage"], {"tobin": 22})
	assert_eq(dispatch.health("tobin", 1_040), 1)
	assert_eq(dispatch.debriefs[0]["injured"], {"tobin": 10})
	_read_all(dispatch, gold)
	assert_eq(dispatch.status("tobin", 1_040), "Injured · 0:10")
	assert_eq(dispatch.party_refusal("rats", ["tobin"], 1_049), "Tobin can't go")
	assert_false(dispatch.send("rats", ["tobin"], 7, 1_049))
	assert_true(dispatch.can_go("tobin", 1_050))
	assert_eq(dispatch.health("tobin", 1_050), 16)


func test_a_success_can_still_leave_a_worn_out_member_injured_while_the_others_are_not() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("rats", ["tobin", "bram"], _seed("rats", ["tobin", "bram"], true), 1_000))
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_002)
	assert_eq(dispatch.debriefs[0]["injured"], {"tobin": 10})
	_read_all(dispatch, gold)
	assert_eq(gold.amount, 3)
	assert_false(dispatch.can_go("tobin", 1_002))
	assert_true(dispatch.can_go("bram", 1_002))


func test_health_survives_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := _tobin_hurt(gold)
	dispatch.send("rats", ["tobin"], 23, 1_020)
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_021)
	loaded.checkpoint(1_021)
	assert_eq(loaded.health("tobin", 1_021), 5)
	loaded.checkpoint(1_022)
	assert_eq(loaded.health("tobin", 1_022), 4)
	assert_eq(loaded.seconds_to_full("tobin", 1_022), 8)
	for now: int in [1_022, 1_024, 1_027]:
		loaded.checkpoint(now)
		dispatch.checkpoint(now)
		assert_eq(_healths(loaded, now), _healths(dispatch, now))
	assert_eq(loaded.health("tobin", 1_027), 11)


func test_a_save_from_before_health_loads_everyone_at_full_health_with_a_running_injury_kept() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	dispatch.send("goblins", ["tobin"], 0, 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_022)
	_read_all(dispatch, gold)
	assert_eq(dispatch.health("tobin", 1_022), 4)
	# The previous build wrote no health.
	var file := ConfigFile.new()
	dispatch.write(file)
	file.erase_section_key("dispatch", "wounds")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_022)
	assert_eq(_healths(loaded, 1_022), [28, 20, 16, 20])
	assert_eq(loaded.injury_left("tobin", 1_022), 8)
	assert_eq(loaded.status("tobin", 1_022), "Injured · 0:08")


## What a new guild doesn't know about each quest.
const STARTING_UNKNOWN: Dictionary = {
	"rats": [],
	"well": [],
	"letters": ["Negotiation"],
	"spiders": ["Attrition"],
	"cartographer": ["Traps"],
	"mouth": ["Navigation"],
	"moonherbs": ["Attrition"],
	"wolves": ["Attrition"],
	"sealed_door": ["Navigation"],
	"lurker": ["Curse"],
	"crypt": ["Attrition"],
	"pilgrims": ["Attrition"],
	"goblins": ["Navigation"],
	"maze": ["Traps"],
	"chapel": ["Attrition"],
	"minotaur": ["Attrition"],
	"envoy": ["Navigation"],
	"vault": ["Protect"],
}


func _unknown(dispatch: Dispatch) -> Dictionary:
	var unknown := {}
	for quest: String in Dispatch.QUESTS:
		unknown[quest] = Array(dispatch.unknown_challenges(quest))
	return unknown


func test_a_new_guild_knows_every_challenge_but_each_quests_last_and_all_of_rats() -> void:
	assert_eq(_unknown(Dispatch.new(1_000)), STARTING_UNKNOWN)


func test_the_range_shown_is_the_known_chance_with_an_unknown_challenge_even_and_the_true_chance_is_what_a_party_leaves_with() -> void:
	var dispatch := _guild(1_000)
	# Rats has nothing unknown: Bram's 74, widened by 10 either way.
	assert_eq(dispatch.chance_range("rats", ["bram"]), Vector2i(64, 84))
	# Moonherbs' Attrition is unknown: Navigation's 80 counts as it is, Attrition as an even match,
	# (80 + 50 + 50) ÷ 3 = 60.
	assert_eq(dispatch.chance_range("moonherbs", ["bram", "tobin"]), Vector2i(50, 70))
	# Maren lifts Navigation to 95: (95 + 50 + 50) ÷ 3 = 65.
	assert_eq(dispatch.chance_range("moonherbs", ["bram", "tobin", "maren"]), Vector2i(55, 75))
	# The true chance may lie outside while a challenge is unknown.
	assert_true(dispatch.send("moonherbs", ["bram", "tobin"], 1, 1_000))
	assert_eq(dispatch.outings[0]["chance"], 85)


func test_a_party_back_from_a_quest_reveals_its_unknown_challenges_for_good() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("moonherbs", ["bram", "tobin"], 1, 1_000))
	dispatch.checkpoint(1_005)
	assert_eq(_unknown(dispatch), STARTING_UNKNOWN, "still out, nothing revealed")
	dispatch.checkpoint(1_006)
	var known := STARTING_UNKNOWN.duplicate()
	known["moonherbs"] = []
	assert_eq(_unknown(dispatch), known)
	assert_eq(dispatch.debriefs[0]["revealed"], PackedStringArray(["Attrition"]))
	# Known now, the range centres on the true 86, its 85 and a point for the try, widened by 10.
	assert_eq(dispatch.chance_range("moonherbs", ["bram", "tobin"]), Vector2i(76, 95))
	# A second trip has nothing left to reveal.
	_read_all(dispatch, gold)
	assert_true(dispatch.send("moonherbs", ["bram", "tobin"], 1, 1_200))
	dispatch.checkpoint(1_206)
	assert_eq(dispatch.debriefs[0]["revealed"], PackedStringArray())
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_400)
	assert_eq(_unknown(loaded), known)
	assert_eq(loaded.debriefs, dispatch.debriefs)


func test_a_save_from_before_challenges_loads_with_the_starting_knowledge_and_nothing_else_lost() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("moonherbs", ["bram"], 1, 1_000))
	dispatch.checkpoint(1_180)
	assert_true(dispatch.send("goblins", ["tobin"], 1, 1_200))
	# The previous build wrote nothing revealed, and debriefs without it.
	var file := ConfigFile.new()
	dispatch.write(file)
	var debriefs: Array = file.get_value("dispatch", "debriefs")
	debriefs[0].erase("revealed")
	file.set_value("dispatch", "debriefs", debriefs)
	file.erase_section_key("dispatch", "revealed")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_200)
	assert_eq(_unknown(loaded), STARTING_UNKNOWN)
	assert_eq(loaded.debriefs.size(), 1)
	assert_eq(loaded.debriefs[0]["gold"], dispatch.debriefs[0]["gold"])
	assert_eq(loaded.outings, dispatch.outings)
	assert_eq(loaded.adventurers.xp, dispatch.adventurers.xp)


func test_the_same_seed_sends_the_same_party_to_the_same_end() -> void:
	var party: PackedStringArray = ["bram", "tobin", "maren"]
	var successes := 0
	for roll_seed: int in 40:
		var ends: Array[Dictionary] = []
		for run: int in 2:
			var dispatch := _guild(1_000)
			assert_true(dispatch.send("moonherbs", party, roll_seed, 1_000))
			dispatch.checkpoint(1_180)
			ends.append(dispatch.debriefs[0])
		assert_eq(ends[1], ends[0])
		if ends[0]["success"]:
			successes += 1
	assert_between(successes, 1, 39, "both outcomes occur, so the seed decides")


## The first seed that brings back loot from a rank `rank` quest.
func _loot_seed(rank: String) -> int:
	for roll_seed: int in 1_000:
		if not Gear.loot(roll_seed, rank).is_empty():
			return roll_seed
	fail_test("no seed found")
	return -1


func test_a_returning_partys_debrief_lists_its_loot_and_reading_it_puts_it_in_the_stash() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	var roll_seed := _loot_seed("E")
	var item := Gear.loot(roll_seed, "E")
	assert_true(dispatch.send("goblins", ["bram", "ilse"], roll_seed, 1_000))
	dispatch.checkpoint(1_600)
	assert_eq(dispatch.debriefs[0]["loot"], PackedStringArray([item]))
	assert_eq(dispatch.debrief_loot(dispatch.debriefs[0]), {"loot": PackedStringArray([item]), "lost": PackedStringArray()})
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray())
	_read_all(dispatch, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray([item]))
	# A return whose seed brings nothing adds nothing.
	assert_true(dispatch.send("goblins", ["tobin"], 0, 1_600))
	assert_eq(Gear.loot(0, "E"), "")
	dispatch.checkpoint(2_200)
	assert_eq(dispatch.debriefs[0]["loot"], PackedStringArray())
	_read_all(dispatch, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray([item]))


func test_loot_brought_to_a_full_stash_is_lost_and_the_debrief_says_so() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	for i: int in dispatch.adventurers.gear.stash_cap:
		assert_true(dispatch.adventurers.gear.stow("belt"))
	var roll_seed := _loot_seed("F")
	var item := Gear.loot(roll_seed, "F")
	assert_true(dispatch.send("rats", ["bram"], roll_seed, 1_000))
	dispatch.checkpoint(1_060)
	assert_eq(dispatch.debrief_loot(dispatch.debriefs[0]), {"loot": PackedStringArray(), "lost": PackedStringArray([item])})
	_read_all(dispatch, gold)
	assert_eq(dispatch.adventurers.gear.stash.size(), 6)
	assert_does_not_have(dispatch.adventurers.gear.stash, item if item != "belt" else "never")


func test_gear_cannot_be_changed_while_out_and_can_once_home() -> void:
	var dispatch := _guild(1_000)
	dispatch.adventurers.gear.stow("chapel_plate")
	var chance := dispatch.success_chance("rats", ["bram"])
	assert_true(dispatch.send("rats", ["bram"], 1, 1_000))
	assert_false(dispatch.can_change_gear("bram"))
	assert_false(dispatch.wear("bram", 0))
	assert_eq(dispatch.adventurers.gear.worn["bram"]["armour"], "leather_vest")
	assert_eq(dispatch.adventurers.gear.stash[0], "chapel_plate")
	assert_eq(dispatch.outings[0]["chance"], chance)
	# Someone home may change theirs meanwhile.
	assert_true(dispatch.can_change_gear("ilse"))
	dispatch.checkpoint(1_060)
	assert_true(dispatch.can_change_gear("bram"))
	assert_true(dispatch.wear("bram", 0))
	assert_eq(dispatch.adventurers.gear.worn["bram"]["armour"], "chapel_plate")
	assert_eq(dispatch.adventurers.gear.stash[0], "leather_vest")


func test_gear_cannot_be_taken_off_while_out_and_can_once_home_unless_the_stash_is_full() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("rats", ["bram"], 1, 1_000))
	assert_false(dispatch.take_off("bram", "armour"))
	assert_eq(dispatch.adventurers.gear.worn["bram"]["armour"], "leather_vest")
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray())
	dispatch.checkpoint(1_060)
	# Home again: Gear's own refusals still hold, an empty slot and then a full stash.
	assert_false(dispatch.take_off("bram", "back"))
	assert_true(dispatch.take_off("bram", "armour"))
	assert_false(dispatch.adventurers.gear.worn["bram"].has("armour"))
	assert_has(dispatch.adventurers.gear.stash, "leather_vest")
	while dispatch.adventurers.gear.stow("belt"):
		pass
	assert_false(dispatch.take_off("bram", "weapon"))
	assert_eq(dispatch.adventurers.gear.worn["bram"]["weapon"], "short_sword")


func test_taking_off_and_wearing_say_why_they_are_refused_out_on_a_quest_nothing_worn_or_stash_full() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("rats", ["bram"], 1, 1_000))
	assert_eq(dispatch.take_off_refusal("bram", "armour"), "Out on a quest")
	assert_eq(dispatch.wear_refusal("bram"), "Out on a quest")
	# Someone home may.
	assert_eq(dispatch.take_off_refusal("ilse", "weapon"), "")
	assert_eq(dispatch.wear_refusal("ilse"), "")
	dispatch.checkpoint(1_060)
	assert_eq(dispatch.take_off_refusal("bram", "armour"), "")
	assert_eq(dispatch.wear_refusal("bram"), "")
	assert_eq(dispatch.take_off_refusal("bram", "back"), "Nothing worn")
	while dispatch.adventurers.gear.stow("belt"):
		pass
	assert_eq(dispatch.take_off_refusal("bram", "armour"), "Stash full")
	# Wearing swaps, so a full stash doesn't stop it.
	assert_eq(dispatch.wear_refusal("bram"), "")


func test_gear_the_stash_and_loot_in_debriefs_survive_save_and_load() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	var roll_seed := _loot_seed("E")
	assert_true(dispatch.send("goblins", ["tobin"], roll_seed, 1_000))
	dispatch.checkpoint(1_600)
	dispatch.adventurers.gear.stow("night_cloak")
	assert_true(dispatch.wear("ilse", dispatch.adventurers.gear.stash.size() - 1))
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_600)
	assert_eq(loaded.adventurers.gear.worn, dispatch.adventurers.gear.worn)
	assert_eq(loaded.adventurers.gear.worn["ilse"]["back"], "night_cloak")
	assert_eq(loaded.debriefs, dispatch.debriefs)
	assert_eq(loaded.debriefs[0]["loot"], PackedStringArray([Gear.loot(roll_seed, "E")]))
	assert_eq(loaded.adventurers.stat_total("ilse", "agility"), 6)
	loaded.read_debrief(0, gold)
	assert_eq(loaded.adventurers.gear.stash, PackedStringArray([Gear.loot(roll_seed, "E")]))


func test_training_is_refused_with_nothing_changed_when_no_place_is_free_out_on_a_quest_debrief_waiting_or_injured() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	assert_eq(dispatch.training_refusal("bram", 0, 1_000), "No free training place — convert a Training room")
	assert_false(dispatch.train("bram", 0, 1_000))
	assert_true(dispatch.send("rats", ["ilse"], 1, 1_000))
	assert_eq(dispatch.training_refusal("ilse", 1, 1_001), "Out on a quest")
	assert_false(dispatch.train("ilse", 1, 1_001))
	dispatch.send("goblins", ["tobin"], _seed("goblins", ["tobin"], false), 1_000)
	_worn_out(dispatch, "tobin")
	dispatch.checkpoint(1_020)
	assert_eq(dispatch.training_refusal("tobin", 1, 1_020), "Debrief waiting")
	assert_false(dispatch.train("tobin", 1, 1_020))
	_read_all(dispatch, gold)
	assert_eq(dispatch.training_refusal("tobin", 1, 1_020), "Injured")
	assert_false(dispatch.train("tobin", 1, 1_020))
	assert_true(dispatch.training.is_empty())
	assert_eq(dispatch.status("tobin", 1_020), "Injured · 0:10")
	# With a place free, someone home and well can.
	assert_eq(dispatch.training_refusal("bram", 1, 1_020), "")
	assert_true(dispatch.train("bram", 1, 1_020))


func test_training_gives_1_xp_per_whole_6_seconds_so_10_a_minute_up_to_20_a_stint() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.train("bram", 1, 1_000))
	assert_eq(dispatch.training_xp("bram", 1_005), 0)
	assert_eq(dispatch.training_xp("bram", 1_006), 1)
	assert_eq(dispatch.training_xp("bram", 1_011), 1)
	assert_eq(dispatch.training_xp("bram", 1_000 + 60), 10)
	assert_eq(dispatch.training_xp("bram", 1_000 + 75), 12)
	assert_eq(dispatch.training_xp("bram", 1_000 + 119), 19)
	assert_eq(dispatch.training_xp("bram", 1_000 + 120), 20)
	assert_eq(dispatch.training_xp("bram", 1_000 + 86_400), 20)
	assert_eq(dispatch.training_xp("ilse", 1_000 + 120), 0)
	# The XP waits in the stint; nothing is banked until it stops.
	assert_eq(dispatch.adventurers.xp["bram"], 0)


func test_the_training_countdown_ticks_down_to_0_exactly_when_the_stint_reaches_its_cap() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.train("bram", 1, 1_000))
	assert_eq(dispatch.training_seconds_left("bram", 1_000), 120)
	assert_eq(dispatch.training_seconds_left("ilse", 1_000), 0)
	# Checked against the XP itself each second, so it holds whatever the rate and cap.
	var capped_at := -1
	for at: int in range(1_000, 1_000 + 2 * 120):
		var capped := dispatch.training_xp("bram", at) == Dispatch.TRAINING_MAX_XP
		if capped and capped_at == -1:
			capped_at = at
		assert_eq(dispatch.training_seconds_left("bram", at) == 0, capped, str(at))
		if not capped:
			assert_eq(dispatch.training_seconds_left("bram", at), dispatch.training_seconds_left("bram", 1_000) - (at - 1_000), str(at))
	assert_eq(capped_at, 1_000 + 120)
	# A clock set back after a later checkpoint gives no time back.
	dispatch.checkpoint(1_000 + 20)
	assert_eq(dispatch.training_seconds_left("bram", 1_000), 100)
	assert_eq(dispatch.training_seconds_left("bram", 1_000 + 20), 100)


func test_stopping_banks_exactly_the_stints_xp_and_frees_the_adventurer() -> void:
	var dispatch := _guild(1_000)
	dispatch.adventurers.gain_xp("bram", 5)
	assert_true(dispatch.train("bram", 1, 1_000))
	assert_eq(dispatch.stop_training("bram", 1_000 + 75), 12)
	assert_eq(dispatch.adventurers.xp["bram"], 17)
	assert_false(dispatch.training.has("bram"))
	assert_eq(dispatch.status("bram", 1_800), "Resting")
	assert_true(dispatch.can_go("bram", 1_800))
	# Stopping again banks nothing more.
	assert_eq(dispatch.stop_training("bram", 5_000), 0)
	assert_eq(dispatch.adventurers.xp["bram"], 17)
	# A stint past the cap banks the cap.
	assert_true(dispatch.train("bram", 1, 2_000))
	assert_eq(dispatch.stop_training("bram", 2_000 + 7_200), 20)
	assert_eq(dispatch.adventurers.xp["bram"], 37)


func test_an_adventurer_in_training_shows_as_training_and_cannot_be_sent() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.train("bram", 1, 1_000))
	assert_eq(_statuses(dispatch, 1_100), ["Training", "Resting", "Resting", "Resting"])
	assert_false(dispatch.can_go("bram", 1_100))
	assert_true(dispatch.can_go("ilse", 1_100))
	assert_eq(dispatch.party_refusal("rats", ["bram", "ilse"], 1_100), "Bram can't go")
	assert_false(dispatch.send("rats", ["bram", "ilse"], 1, 1_100))
	assert_true(dispatch.outings.is_empty())
	dispatch.stop_training("bram", 1_200)
	assert_true(dispatch.send("rats", ["bram", "ilse"], 1, 1_200))


func test_two_training_rooms_hold_two_and_a_stop_frees_a_place() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.train("bram", 1, 1_000))
	assert_eq(dispatch.training_refusal("ilse", 1, 1_000), "No free training place — convert a Training room")
	assert_true(dispatch.train("ilse", 2, 1_000))
	assert_eq(dispatch.training_refusal("tobin", 2, 1_000), "No free training place — convert a Training room")
	assert_false(dispatch.train("tobin", 2, 1_000))
	dispatch.stop_training("bram", 1_100)
	assert_true(dispatch.train("tobin", 2, 1_100))
	assert_eq(dispatch.training.keys(), ["ilse", "tobin"])


func test_the_growth_hint_names_the_fastest_growing_stat_once_20_seconds_are_trained_across_stints() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.train("tobin", 1, 1_000))
	assert_eq(dispatch.training_hint("tobin", 1_010), "")
	dispatch.stop_training("tobin", 1_010)
	assert_eq(dispatch.training_hint("tobin", 50_000), "")
	assert_true(dispatch.train("tobin", 1, 2_000))
	assert_eq(dispatch.training_hint("tobin", 2_009), "")
	assert_eq(dispatch.training_hint("tobin", 2_010), "Agility")
	dispatch.stop_training("tobin", 2_010)
	# Kept for good once earned.
	assert_eq(dispatch.training_hint("tobin", 2_010), "Agility")
	assert_eq(dispatch.training_hint("ilse", 2_010), "")
	assert_true(dispatch.train("ilse", 1, 3_000))
	assert_eq(dispatch.training_hint("ilse", 3_020), "Mind")


func test_the_growth_hint_breaks_a_tie_by_the_order_stats_are_shown_in() -> void:
	var dispatch := _guild(1_000)
	dispatch.adventurers.add("wren", {"name": "Wren", "rank": "F"}, WREN_STATS, {"strength": 0.2, "agility": 0.5, "perception": 0.1, "mind": 0.5, "spirit": 0.1, "defence": 0.1, "endurance": 0.1, "presence": 0.1, "luck": 0.1})
	assert_true(dispatch.train("wren", 1, 1_000))
	assert_eq(dispatch.training_hint("wren", 1_600), "Agility")


func test_a_clock_set_back_never_lowers_training_xp_or_the_time_trained() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.train("tobin", 1, 1_000))
	dispatch.checkpoint(1_000 + 30)
	assert_eq(dispatch.training_xp("tobin", 1_010), 5)
	assert_eq(dispatch.training_hint("tobin", 1_010), "Agility")
	assert_eq(dispatch.stop_training("tobin", 1_010), 5)
	assert_eq(dispatch.adventurers.xp["tobin"], 5)
	# A stint started with the clock still back starts from the latest time seen.
	assert_true(dispatch.train("tobin", 1, 1_010))
	assert_eq(dispatch.training_xp("tobin", 1_000 + 30 + 6), 1)


func test_training_survives_save_and_load_mid_stint() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.train("tobin", 1, 1_000))
	dispatch.stop_training("tobin", 1_010)
	assert_true(dispatch.train("tobin", 2, 2_000))
	assert_true(dispatch.train("bram", 2, 2_010))
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 2_020)
	assert_eq(_statuses(loaded, 2_020), ["Training", "Resting", "Training", "Resting"])
	assert_eq(loaded.training_xp("tobin", 2_000 + 72), 12)
	assert_eq(loaded.training_hint("tobin", 2_009), "")
	assert_eq(loaded.training_hint("tobin", 2_010), "Agility")
	assert_eq(loaded.training_refusal("ilse", 2, 2_020), "No free training place — convert a Training room")
	assert_eq(loaded.stop_training("bram", 2_010 + 30), 5)
	assert_eq(loaded.adventurers.xp["bram"], 5)


func test_a_save_from_before_training_loads_with_nobody_training_and_nothing_else_lost() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("goblins", ["tobin"], 1, 1_000))
	var file := ConfigFile.new()
	dispatch.write(file)
	file.erase_section_key("dispatch", "training")
	file.erase_section_key("dispatch", "trained_seconds")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_100)
	assert_true(loaded.training.is_empty())
	assert_eq(_statuses(loaded, 1_100), ["Resting", "Resting", "On quest: Goblin camp", "Resting"])
	assert_eq(loaded.training_hint("bram", 100_000), "")
	assert_eq(loaded.outings, dispatch.outings)
	assert_true(loaded.train("bram", 1, 1_100))


func test_in_a_new_game_bram_and_tobin_together_have_at_least_80_on_every_rank_f_quest_and_each_alone_45_to_75() -> void:
	var dispatch := Dispatch.new(1_000)
	var pair := PackedStringArray(dispatch.adventurers.roster.keys())
	assert_eq(pair, PackedStringArray(["bram", "tobin"]))
	var checked := 0
	for quest: String in Dispatch.QUESTS:
		if Dispatch.QUESTS[quest]["rank"] != "F":
			continue
		checked += 1
		assert_gte(dispatch.success_chance(quest, pair), 80, quest)
		for adventurer: String in pair:
			assert_between(dispatch.success_chance(quest, [adventurer]), 45, 75, "%s %s" % [quest, adventurer])
	assert_eq(checked, 7)


func test_each_party_back_from_a_quest_adds_a_point_to_its_chance_and_both_ends_of_its_range_up_to_15() -> void:
	var gold := Gold.new(0)
	var dispatch := Dispatch.new(1_000)
	assert_eq(dispatch.success_chance("rats", ["tobin"]), 46)
	# Tobin has Luck, but the range leaves a lucky break out.
	assert_eq(dispatch.chance_range("rats", ["tobin"]), Vector2i(36, 56))
	var outcomes := {true: 0, false: 0}
	var now := 1_000
	for tried: int in range(1, 17):
		assert_true(dispatch.send("rats", ["tobin"], tried, now), str(tried))
		now += 100
		dispatch.checkpoint(now)
		outcomes[dispatch.debriefs[0]["success"]] += 1
		_read_all(dispatch, gold)
		if tried == 1:
			assert_eq(dispatch.success_chance("rats", ["tobin"]), 47)
			assert_eq(dispatch.chance_range("rats", ["tobin"]), Vector2i(37, 57))
		if tried == 14:
			assert_eq(dispatch.success_chance("rats", ["tobin"]), 60)
	# Fifteen tries reach the most; a sixteenth adds nothing.
	assert_eq(dispatch.tries["rats"], 16)
	assert_eq(dispatch.success_chance("rats", ["tobin"]), 61)
	assert_eq(dispatch.chance_range("rats", ["tobin"]), Vector2i(51, 71))
	# Successes and failures alike are tries.
	assert_gt(outcomes[true], 0)
	assert_gt(outcomes[false], 0)
	# Only that quest is learnt.
	assert_eq(dispatch.success_chance("well", ["tobin"]), 68)


func test_a_partys_chance_is_fixed_when_it_leaves_whatever_tries_come_back_while_it_is_out() -> void:
	# Seed 172 fails at Tobin's 46% on rats and would succeed at 47%, and brings no lucky break.
	assert_false(Outcome.roll(172, 46, Outcome.MOST_DAMAGE["F"], ["tobin"]).success)
	assert_true(Outcome.roll(172, 47, Outcome.MOST_DAMAGE["F"], ["tobin"]).success)
	assert_false(Outcome.lucky_break(172, 4))
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("rats", ["bram"], 1, 1_000))
	assert_true(dispatch.send("rats", ["tobin"], 172, 1_001))
	# Bram is back first: a try the guild learns from while Tobin is still out.
	dispatch.checkpoint(1_002)
	assert_eq(dispatch.success_chance("rats", ["tobin"]), 47)
	assert_eq(dispatch.outings[0]["chance"], 46)
	dispatch.checkpoint(1_003)
	assert_eq(dispatch.debriefs[1]["party"], PackedStringArray(["tobin"]))
	assert_false(dispatch.debriefs[1]["success"])


func test_tries_survive_save_and_load_and_a_save_from_before_them_has_tried_nothing() -> void:
	var dispatch := Dispatch.new(1_000)
	for now: int in [1_000, 1_100, 1_200]:
		assert_true(dispatch.send("rats", ["bram"], 1, now))
		dispatch.checkpoint(now + 50)
		_read_all(dispatch, Gold.new(0))
	assert_true(dispatch.send("mouth", ["tobin"], 1, 1_300))
	dispatch.checkpoint(1_350)
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_350)
	assert_eq(loaded.tries, {"rats": 3, "mouth": 1})
	assert_eq(loaded.success_chance("rats", ["tobin"]), 49)
	# The build before tries wrote none.
	file.erase_section_key("dispatch", "tries")
	assert_eq(file.save(SAVE_PATH), OK)
	var old := Dispatch.load_or_start(SAVE_PATH, 1_350)
	assert_true(old.tries.is_empty())
	assert_eq(old.success_chance("rats", ["tobin"]), 46)
	assert_eq(old.debriefs, dispatch.debriefs)


func test_a_save_from_before_the_faster_timers_loads_with_nothing_lost_and_its_party_back_sooner() -> void:
	# What the build before wrote: a goblin camp out since 990, back at 1_590 by its 600 s; Tobin
	# injured for 300 s until 1_250; an unread return holding the gold it earned then; no tries.
	var file := ConfigFile.new()
	Gold.new(100).write(file)
	file.set_value("dispatch", "outings", [{"quest": "goblins", "since": 990, "party": PackedStringArray(["bram"]), "seed": 1, "chance": 30, "health": {"bram": 24}, "max_health": {"bram": 24}}])
	file.set_value("dispatch", "injured_until", {"tobin": 1_250})
	file.set_value("dispatch", "injury_lengths", {"tobin": 300})
	file.set_value("dispatch", "debriefs", [{"quest": "goblins", "returned_at": 950, "success": true, "party": PackedStringArray(["ilse"]), "damage": {"ilse": 12}, "injured": {}, "gold": 125, "xp": 40, "revealed": PackedStringArray(), "loot": PackedStringArray(), "paid": false, "xp_given": true}])
	file.set_value("dispatch", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)

	var gold := Gold.load_or_start(SAVE_PATH)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_true(dispatch.tries.is_empty())
	# The party out comes home by today's 20 s, sooner than it would have.
	assert_eq(dispatch.seconds_left(dispatch.outings[0], 1_000), 10)
	# The injury runs to the end it was given.
	assert_eq(dispatch.injury_left("tobin", 1_000), 250)
	assert_eq(dispatch.injury_seconds("tobin"), 300)
	dispatch.checkpoint(1_010)
	assert_eq(dispatch.debriefs.size(), 2)
	assert_eq(dispatch.tries, {"goblins": 1})
	# The unread return pays what it holds.
	dispatch.read_debrief(0, gold)
	assert_eq(gold.amount, 225)


func test_a_challenge_is_met_when_the_partys_total_with_gear_reaches_what_it_needs() -> void:
	var dispatch := _guild(1_000)
	# Rats needs 11 for Brute force: Tobin brings 9, Bram 23.
	assert_false(dispatch.challenge_met("rats", "Brute force", ["tobin"]))
	assert_true(dispatch.challenge_met("rats", "Brute force", ["bram"]))
	# The Goblin-slayer blade's Strength +4 counts twice: 2 × 7 + 3.
	dispatch.adventurers.gear.stow("goblin_slayer_blade")
	assert_true(dispatch.wear("tobin", 0))
	assert_true(dispatch.challenge_met("rats", "Brute force", ["tobin"]))
	# His bow back on, he falls short again.
	assert_true(dispatch.wear("tobin", 0))
	assert_false(dispatch.challenge_met("rats", "Brute force", ["tobin"]))


func test_a_lucky_break_decided_at_send_lifts_a_weak_challenge_to_50_and_the_debrief_records_it() -> void:
	# Tobin alone has 46% on rats and 4 Luck: 8% of seeds bring him a lucky break.
	var lucky_seed := -1
	var plain_seed := -1
	for roll_seed: int in 2_000:
		if Outcome.lucky_break(roll_seed, 4):
			lucky_seed = roll_seed if lucky_seed == -1 else lucky_seed
		elif plain_seed == -1:
			plain_seed = roll_seed
	for roll_seed: int in [lucky_seed, plain_seed]:
		var lucky := roll_seed == lucky_seed
		var dispatch := Dispatch.new(1_000)
		assert_true(dispatch.send("rats", ["tobin"], roll_seed, 1_000))
		assert_eq(dispatch.outings[0]["chance"], 50 if lucky else 46)
		assert_eq(dispatch.outings[0]["lucky_break"], lucky)
		dispatch.checkpoint(1_010)
		assert_eq(dispatch.debriefs[0].get("lucky_break", false), lucky)
		# The same send always gives the same chance.
		var again := Dispatch.new(1_000)
		again.send("rats", ["tobin"], roll_seed, 1_000)
		assert_eq(again.outings[0]["chance"], 50 if lucky else 46)


func test_a_lucky_break_changes_nothing_when_the_weakest_challenge_is_already_even_and_never_comes_without_luck() -> void:
	# Bram has 74% on rats and 1 Luck.
	var lucky_seed := -1
	for roll_seed: int in 2_000:
		if Outcome.lucky_break(roll_seed, 1):
			lucky_seed = roll_seed
			break
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("rats", ["bram"], lucky_seed, 1_000))
	assert_eq(dispatch.outings[0]["chance"], 74)
	assert_false(dispatch.outings[0]["lucky_break"])
	dispatch.checkpoint(1_010)
	assert_false(dispatch.debriefs[0].has("lucky_break"))
	# Wren has no Luck: whatever the seed, her hopeless 5% on Wolves at the mill stays.
	var luckless := Dispatch.new(1_000)
	luckless.adventurers.add("wren", {"name": "Wren", "rank": "F"}, WREN_STATS, WREN_GROWTH)
	var chance := luckless.success_chance("wolves", ["wren"])
	assert_eq(chance, 5)
	for roll_seed: int in 300:
		var probe := Dispatch.new(1_000)
		probe.adventurers.add("wren", {"name": "Wren", "rank": "F"}, WREN_STATS, WREN_GROWTH)
		assert_true(probe.send("wolves", ["wren"], roll_seed, 1_000))
		assert_eq(probe.outings[0]["chance"], chance)


func test_with_every_challenge_known_the_chance_a_party_leaves_with_lies_inside_the_range_shown_unless_a_lucky_break_lifts_it() -> void:
	var parties: Array[PackedStringArray] = [["tobin"], ["bram"], ["maren"], ["bram", "tobin"], ["ilse", "maren"], PackedStringArray(EVERYONE)]
	var lucky := 0
	var checked := 0
	for quest: String in Dispatch.QUESTS:
		for party: PackedStringArray in parties:
			var dispatch := _guild(1_000)
			for adventurer: String in dispatch.adventurers.roster:
				dispatch.adventurers.roster[adventurer]["rank"] = "D"
			dispatch.revealed.append(quest)
			var shown := dispatch.chance_range(quest, party)
			for roll_seed: int in 40:
				assert_true(dispatch.send(quest, party, roll_seed, 1_000))
				var chance := int(dispatch.outings[0]["chance"])
				if dispatch.outings[0]["lucky_break"]:
					assert_gte(chance, shown.x, "%s %s" % [quest, party])
					lucky += 1
				else:
					assert_between(chance, shown.x, shown.y, "%s %s" % [quest, party])
				dispatch.outings.clear()
				checked += 1
	assert_gt(checked, 0)
	assert_gt(lucky, 0)


func test_a_save_with_four_old_stats_classes_a_party_out_and_a_debrief_loads_with_nothing_lost() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	var roll_seed := _seed("goblins", ["bram", "ilse"], true)
	assert_true(dispatch.send("goblins", ["bram", "ilse"], roll_seed, 1_000))
	assert_true(dispatch.send("rats", ["tobin"], 3, 1_000))
	dispatch.checkpoint(1_005)
	var debriefs := dispatch.debriefs.duplicate(true)
	var file := ConfigFile.new()
	dispatch.write(file)
	# What the build before nine stats wrote: four stats, classes, and a party out with only the
	# chance it left with.
	var outing: Dictionary = dispatch.outings[0].duplicate(true)
	for key: String in ["lucky_break", "spirit", "luck"]:
		outing.erase(key)
	outing["chance"] = 93
	file.set_value("dispatch", "outings", [outing])
	file.set_value("adventurers", "roster", {
		"bram": {"name": "Bram", "class": "Swordsman", "rank": "F"},
		"ilse": {"name": "Ilse", "class": "Mage", "rank": "F"},
		"tobin": {"name": "Tobin", "class": "Scout", "rank": "F"},
		"maren": {"name": "Maren", "class": "Healer", "rank": "F"},
	})
	file.set_value("adventurers", "stats", {
		"bram": {"might": 7, "agility": 3, "mind": 2, "grit": 8},
		"ilse": {"might": 2, "agility": 3, "mind": 8, "grit": 5},
		"tobin": {"might": 3, "agility": 7, "mind": 3, "grit": 3},
		"maren": {"might": 2, "agility": 3, "mind": 6, "grit": 5},
	})
	file.set_value("adventurers", "growth", {
		"bram": {"might": 0.6, "agility": 0.3, "mind": 0.15, "grit": 0.55},
		"ilse": {"might": 0.15, "agility": 0.3, "mind": 0.7, "grit": 0.35},
		"tobin": {"might": 0.3, "agility": 0.9, "mind": 0.25, "grit": 0.3},
		"maren": {"might": 0.2, "agility": 0.3, "mind": 0.55, "grit": 0.5},
	})
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_005)
	# The mapped stats: Might is Strength, Grit Defence, the rest each starter's own.
	assert_eq(loaded.adventurers.stats["bram"], {"strength": 7, "agility": 3, "mind": 2, "defence": 8, "perception": 3, "spirit": 3, "endurance": 5, "presence": 3, "luck": 1})
	assert_eq(loaded.adventurers.stats["maren"]["spirit"], 7)
	assert_eq(loaded.adventurers.title("bram"), "Fighter")
	assert_false(loaded.adventurers.roster["bram"].has("class"))
	# Nothing lost: the party out, the debrief waiting, the XP it gave.
	assert_eq(loaded.debriefs, debriefs)
	assert_eq(loaded.adventurers.xp, dispatch.adventurers.xp)
	assert_eq(_statuses(loaded, 1_005), ["On quest: Goblin camp", "On quest: Goblin camp", "Debrief waiting", "Resting"])
	# The party out ends by the chance it left with.
	loaded.checkpoint(1_100)
	assert_eq(loaded.debriefs[1]["quest"], "goblins")
	assert_eq(loaded.debriefs[1]["success"], Outcome.roll(roll_seed, 93, 0, ["bram", "ilse"]).success)
	assert_false(loaded.debriefs[1].has("lucky_break"))
	_read_all(loaded, gold)
	assert_eq(_statuses(loaded, 1_100), ["Resting", "Resting", "Resting", "Resting"])


func test_dismissing_puts_their_gear_in_the_stash_in_slot_order_and_what_does_not_fit_leaves_with_them() -> void:
	var dispatch := _guild(1_000)
	var gear := dispatch.adventurers.gear
	gear.stash = PackedStringArray(["quiver", "belt", "sash"])
	# Bram wears five items, put on last slot first, and the stash of 6 has room for three.
	gear.worn["bram"] = {"off_hand": "round_shield", "weapon": "short_sword", "armour": "leather_vest", "clothes": "red_tunic", "head": "iron_cap"}
	assert_eq(gear.leaving_with("bram"), 2)
	assert_eq(gear.leaving_with("maren"), 0)
	assert_true(dispatch.dismiss("bram"))
	assert_eq(gear.stash, PackedStringArray(["quiver", "belt", "sash", "iron_cap", "red_tunic", "leather_vest"]))
	assert_false(gear.worn.has("bram"))
	assert_true(gear.worn.has("tobin"))


func test_dismissal_is_refused_with_nothing_changed_while_out_waiting_on_a_debrief_or_training() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("rats", PackedStringArray(["bram"]), 1, 1_000))
	assert_true(dispatch.train("ilse", 1, 1_000))
	assert_eq(dispatch.dismiss_refusal("bram"), "Out on a quest")
	assert_eq(dispatch.dismiss_refusal("ilse"), "Training")
	assert_eq(dispatch.dismiss_refusal("tobin"), "")
	dispatch.checkpoint(1_100)
	assert_eq(dispatch.dismiss_refusal("bram"), "Debrief waiting")
	for adventurer: String in ["bram", "ilse"]:
		assert_false(dispatch.dismiss(adventurer))
	assert_eq(dispatch.adventurers.roster.keys(), EVERYONE)
	assert_eq(dispatch.adventurers.gear.worn["bram"], Gear.STARTER_GEAR["bram"])
	assert_true(dispatch.training.has("ilse"))
	# Once the debrief is read and the training stopped, both can go.
	_read_all(dispatch, Gold.new(0))
	dispatch.stop_training("ilse", 1_100)
	assert_true(dispatch.dismiss("bram"))
	assert_true(dispatch.dismiss("ilse"))
	assert_eq(dispatch.adventurers.roster.keys(), ["tobin", "maren"])


func test_the_guilds_last_adventurer_cannot_be_dismissed() -> void:
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.dismiss("bram"))
	assert_eq(dispatch.dismiss_refusal("tobin"), "The guild's last adventurer")
	assert_false(dispatch.dismiss("tobin"))
	assert_eq(dispatch.adventurers.roster.keys(), ["tobin"])


func test_the_save_forgets_a_dismissed_adventurer_wounds_injury_training_and_history_included() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("rats", PackedStringArray(["bram", "tobin"]), 1, 1_000))
	_worn_out(dispatch, "bram")
	dispatch.checkpoint(1_100)
	_read_all(dispatch, Gold.new(0))
	assert_true(dispatch.train("bram", 1, 1_100))
	dispatch.stop_training("bram", 1_200)
	dispatch.adventurers.history["bram"].append({"level": 2, "gains": {"strength": 1}})
	# What there is to forget.
	assert_true(dispatch.wounds.has("bram"))
	assert_true(dispatch.injured_until.has("bram"))
	assert_true(dispatch.trained_seconds.has("bram"))
	assert_true(dispatch.dismiss("bram"))
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var saved := FileAccess.get_file_as_string(SAVE_PATH)
	assert_false(saved.contains("\"bram\""))
	assert_true(saved.contains("\"tobin\""))
	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_200)
	assert_eq(loaded.adventurers.roster.keys(), ["ilse", "tobin", "maren"])
	for kept: Dictionary in [loaded.adventurers.stats, loaded.adventurers.growth, loaded.adventurers.levels, loaded.adventurers.xp, loaded.adventurers.history, loaded.adventurers.gear.worn]:
		assert_false(kept.has("bram"))
		assert_true(kept.has("tobin"))
	assert_false(loaded.wounds.has("bram"))
	assert_false(loaded.injured_until.has("bram"))
	assert_false(loaded.injury_lengths.has("bram"))
	assert_false(loaded.trained_seconds.has("bram"))


func test_a_debrief_naming_someone_no_longer_in_the_guild_still_loads_reads_and_pays() -> void:
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("rats", PackedStringArray(["bram", "ilse"]), _seed("rats", PackedStringArray(["bram", "ilse"]), true), 1_000))
	dispatch.checkpoint(1_100)
	# Ilse is gone while the debrief that names her is kept.
	dispatch.adventurers.remove("ilse")
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_100)
	assert_eq(loaded.debriefs, dispatch.debriefs)
	assert_has(loaded.debriefs[0]["party"], "ilse")
	assert_false(loaded.adventurers.roster.has("ilse"))
	var gold := Gold.new(0)
	var reward := int(loaded.debriefs[0]["gold"])
	assert_gt(reward, 0)
	loaded.read_debrief(0, gold)
	assert_eq(gold.amount, reward)
	assert_true(loaded.debriefs.is_empty())


const FULL_STASH: PackedStringArray = ["belt", "sash", "green_sash", "quiver", "red_cloak", "iron_cap"]


## Bram and Ilse back from Goblin camp at 1_020 with 42 gold and loot, to a stash full of
## FULL_STASH, so the debrief would lose the loot.
func _loot_to_a_full_stash() -> Dispatch:
	var dispatch := _goblins_with_loot()
	for item: String in FULL_STASH:
		assert_true(dispatch.adventurers.gear.stow(item))
	dispatch.checkpoint(1_020)
	# The loot is none of the stash's, so where it ends up shows.
	assert_does_not_have(FULL_STASH, dispatch.debriefs[0]["loot"][0])
	return dispatch


func test_a_swap_puts_loot_a_full_stash_would_lose_in_place_of_the_chosen_item_which_is_gone() -> void:
	var dispatch := _loot_to_a_full_stash()
	var debrief := dispatch.debriefs[0]
	var item: String = debrief["loot"][0]
	assert_eq(dispatch.debrief_loot(debrief), {"loot": PackedStringArray(), "lost": PackedStringArray([item])})
	assert_eq(dispatch.swap_loot_refusal(debrief, item), "")
	assert_true(dispatch.swap_loot(debrief, item, "sash"))
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray(["belt", "green_sash", "quiver", "red_cloak", "iron_cap", item]))
	# The debrief still lists it, no longer lost, and it can't be swapped in again.
	assert_eq(dispatch.debrief_loot(debrief), {"loot": PackedStringArray([item]), "lost": PackedStringArray()})
	assert_eq(dispatch.swap_loot_refusal(debrief, item, "belt"), "Not lost")
	assert_false(dispatch.swap_loot(debrief, item, "belt"))
	assert_has(dispatch.adventurers.gear.stash, "belt")


func test_reading_a_debrief_after_a_swap_stows_nothing_twice_and_still_pays_its_gold_and_xp() -> void:
	var gold := Gold.new(100)
	var dispatch := _loot_to_a_full_stash()
	var item: String = dispatch.debriefs[0]["loot"][0]
	assert_true(dispatch.swap_loot(dispatch.debriefs[0], item, "sash"))
	# Room again before reading, so a second stow would show.
	assert_true(dispatch.adventurers.gear.sell("belt", Gold.new(0)))
	dispatch.read_debrief(0, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray(["green_sash", "quiver", "red_cloak", "iron_cap", item]))
	assert_eq(gold.amount, 142)
	assert_eq(_xp(dispatch), [15, 15, 0, 0])
	assert_true(dispatch.can_go("bram", 1_020))


func test_loot_not_swapped_in_is_lost_when_the_debrief_is_read() -> void:
	var gold := Gold.new(0)
	var dispatch := _guild(1_000)
	for item: String in FULL_STASH:
		assert_true(dispatch.adventurers.gear.stow(item))
	dispatch.debriefs.append({"quest": "rats", "returned_at": 1_000, "success": true, "party": PackedStringArray(["bram"]), "damage": {}, "injured": {}, "gold": 3, "xp": 4, "revealed": PackedStringArray(), "loot": PackedStringArray(["night_cloak", "chapel_plate"]), "paid": false, "xp_given": true})
	var debrief := dispatch.debriefs[0]
	assert_true(dispatch.swap_loot(debrief, "chapel_plate", "quiver"))
	assert_eq(dispatch.debrief_loot(debrief), {"loot": PackedStringArray(["chapel_plate"]), "lost": PackedStringArray(["night_cloak"])})
	dispatch.read_debrief(0, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray(["belt", "sash", "green_sash", "red_cloak", "iron_cap", "chapel_plate"]))
	assert_eq(gold.amount, 3)


func test_a_swap_is_refused_with_nothing_changed_when_the_chosen_item_is_no_longer_in_the_stash() -> void:
	var dispatch := _loot_to_a_full_stash()
	var debrief := dispatch.debriefs[0]
	var item: String = debrief["loot"][0]
	assert_eq(dispatch.swap_loot_refusal(debrief, item, "night_cloak"), "No longer in the stash")
	assert_false(dispatch.swap_loot(debrief, item, "night_cloak"))
	assert_eq(dispatch.adventurers.gear.stash, FULL_STASH)
	assert_eq(dispatch.debrief_loot(debrief), {"loot": PackedStringArray(), "lost": PackedStringArray([item])})
	assert_true(dispatch.swap_loot(debrief, item, "quiver"))


func test_a_swap_made_before_the_debrief_is_read_survives_save_and_load() -> void:
	var gold := Gold.new(100)
	var dispatch := _loot_to_a_full_stash()
	var item: String = dispatch.debriefs[0]["loot"][0]
	assert_true(dispatch.swap_loot(dispatch.debriefs[0], item, "sash"))
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_020)
	var stash := PackedStringArray(["belt", "green_sash", "quiver", "red_cloak", "iron_cap", item])
	assert_eq(loaded.adventurers.gear.stash, stash)
	assert_eq(loaded.debrief_loot(loaded.debriefs[0]), {"loot": PackedStringArray([item]), "lost": PackedStringArray()})
	# Room again before reading, so a second stow would show.
	assert_true(loaded.adventurers.gear.sell("belt", Gold.new(0)))
	loaded.read_debrief(0, gold)
	assert_eq(loaded.adventurers.gear.stash, stash.slice(1))
	assert_eq(gold.amount, 142)


func test_a_debrief_saved_before_swaps_reads_as_before_and_one_paid_before_reading_cannot_swap() -> void:
	var file := ConfigFile.new()
	file.set_value("dispatch", "debriefs", [
		{"quest": "rats", "returned_at": 900, "success": true, "party": PackedStringArray(["bram"]), "damage": {}, "injured": {}, "gold": 3, "xp": 4, "revealed": PackedStringArray(), "loot": PackedStringArray(["night_cloak"]), "paid": false, "xp_given": true},
		{"quest": "goblins", "returned_at": 950, "success": true, "party": PackedStringArray(["ilse"]), "damage": {}, "injured": {}, "gold": 500, "xp": 40, "revealed": PackedStringArray(), "loot": PackedStringArray(), "lost": PackedStringArray(["sash"])},
	])
	file.set_value("dispatch", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)
	var gold := Gold.new(0)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	var unread := dispatch.debriefs[0]
	var paid := dispatch.debriefs[1]
	assert_eq(dispatch.debrief_loot(unread), {"loot": PackedStringArray(["night_cloak"]), "lost": PackedStringArray()})
	# Paid when it came home: it keeps its saved split, and its lost item is gone for good.
	assert_eq(dispatch.debrief_loot(paid), {"loot": PackedStringArray(), "lost": PackedStringArray(["sash"])})
	assert_eq(dispatch.swap_loot_refusal(paid, "sash"), "Already paid")
	assert_true(dispatch.adventurers.gear.stow("belt"))
	assert_false(dispatch.swap_loot(paid, "sash", "belt"))
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray(["belt"]))
	_read_all(dispatch, gold)
	assert_eq(dispatch.adventurers.gear.stash, PackedStringArray(["belt", "night_cloak"]))
	assert_eq(gold.amount, 3)
