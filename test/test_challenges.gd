extends GutTest

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
const ALL_CHALLENGES: Array[String] = ["Brute force", "Curse", "Traps", "Navigation", "Attrition", "Protect", "Negotiation"]


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


func test_the_quests_old_saves_name_keep_their_rank_and_challenges() -> void:
	var expected := {
		"rats": ["F", ["Brute force"]],
		"moonherbs": ["F", ["Navigation", "Attrition"]],
		"goblins": ["E", ["Brute force", "Traps", "Navigation"]],
		"letters": ["F", ["Navigation", "Negotiation"]],
		"wolves": ["E", ["Brute force", "Attrition"]],
		"crypt": ["E", ["Curse", "Traps", "Attrition"]],
	}
	for quest: String in expected:
		assert_eq([Dispatch.QUESTS[quest]["rank"], Dispatch.QUESTS[quest]["challenges"]], expected[quest], quest)


func test_every_quest_has_one_to_three_challenges_and_every_challenge_appears_at_ranks_f_e_d_and_c_negotiation_at_f_d_and_c() -> void:
	var seen := {"F": {}, "E": {}, "D": {}, "C": {}}
	for quest: String in Dispatch.QUESTS:
		var challenges: Array = Dispatch.QUESTS[quest]["challenges"]
		assert_between(challenges.size(), 1, 3, quest)
		for challenge: String in challenges:
			assert_has(ALL_CHALLENGES, challenge, quest)
			seen[Dispatch.QUESTS[quest]["rank"]][challenge] = true
	for rank: String in seen:
		var at_rank: Array[String] = []
		at_rank.assign(seen[rank].keys())
		at_rank.sort()
		var all := ALL_CHALLENGES.duplicate()
		if rank == "E":
			all.erase("Negotiation")
		all.sort()
		assert_eq(at_rank, all, rank)


func test_ranks_run_from_f_to_s_and_an_adventurer_can_join_a_quest_at_most_one_rank_above_their_own() -> void:
	assert_eq(Challenges.RANKS, PackedStringArray(["F", "E", "D", "C", "B", "A", "S"]))
	assert_true(Challenges.can_join("F", "F"))
	assert_true(Challenges.can_join("F", "E"))
	assert_false(Challenges.can_join("F", "D"))
	assert_false(Challenges.can_join("F", "S"))
	assert_true(Challenges.can_join("D", "C"))
	assert_false(Challenges.can_join("D", "B"))
	assert_true(Challenges.can_join("A", "F"))
	# The rank F starters can all go on a rank E quest.
	assert_eq(_guild(1_000).party_refusal("goblins", EVERYONE, 1_000), "")


func test_each_challenge_sums_its_weighted_stats_over_the_party_gear_included() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# Ilse, with her gear: Strength 2, Agility 3, Perception 3, Mind 8 + 3, Spirit 3, Defence 5,
	# Endurance 3, Presence 6.
	var expected := {
		"Brute force": 2 * 2 + 5,
		"Traps": 2 * 3 + 3,
		"Navigation": 3 + 11,
		"Curse": 2 * 11 + 3,
		"Protect": 2 * 5 + 6,
		"Attrition": 2 * 3 + 3,
		"Negotiation": 2 * 6 + 11,
	}
	for challenge: String in ALL_CHALLENGES:
		assert_eq(Challenges.party_total(challenge, ["ilse"], adventurers), expected[challenge], challenge)
	# Over a party: Bram's Strength 6 + 1 and Defence 7 + 2, and Tobin's 3 and 3.
	assert_eq(Challenges.party_total("Brute force", ["bram", "tobin"], adventurers), 2 * 7 + 9 + 2 * 3 + 3)
	# Without his sword, Bram brings 2 less.
	adventurers.gear.stash_cap = 6
	assert_true(adventurers.gear.take_off("bram", "weapon"))
	assert_eq(Challenges.party_total("Brute force", ["bram", "tobin"], adventurers), 2 * 6 + 9 + 2 * 3 + 3)


func test_luck_is_never_tested_by_a_challenge() -> void:
	for challenge: String in Challenges.WEIGHTS:
		assert_false(Challenges.WEIGHTS[challenge].has("luck"), challenge)
	assert_eq(Challenges.WEIGHTS.size(), 7)


func test_a_challenge_needs_the_quests_difficulty_scaled_by_its_weight() -> void:
	# Brute force weighs 3, Navigation 2.
	assert_eq(Challenges.requirement("Brute force", 30), 30)
	assert_eq(Challenges.requirement("Navigation", 30), 20)
	assert_eq(Challenges.requirement("Navigation", 7), 5)
	assert_eq(Challenges.requirement("Curse", 0), 0)
