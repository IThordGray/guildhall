extends GutTest

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
const ALL_CHALLENGES: Array[String] = ["Brute force", "Curse", "Traps", "Navigation", "Attrition", "Protect"]


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
		"letters": ["F", ["Navigation", "Protect"]],
		"wolves": ["E", ["Brute force", "Attrition"]],
		"crypt": ["E", ["Curse", "Traps", "Attrition"]],
	}
	for quest: String in expected:
		assert_eq([Dispatch.QUESTS[quest]["rank"], Dispatch.QUESTS[quest]["challenges"]], expected[quest], quest)


func test_every_quest_has_one_to_three_challenges_and_every_challenge_appears_at_ranks_f_e_and_d() -> void:
	var seen := {"F": {}, "E": {}, "D": {}}
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


func test_each_class_covers_its_own_challenges_and_no_others() -> void:
	var expected := {
		"bram": ["Brute force"],
		"ilse": ["Curse"],
		"tobin": ["Traps", "Navigation"],
		"maren": ["Attrition"],
	}
	for adventurer: String in expected:
		var covered: Array[String] = []
		for challenge: String in ALL_CHALLENGES:
			if Challenges.covered_by(challenge, [adventurer], Adventurers.STARTERS) == PackedStringArray([adventurer]):
				covered.append(challenge)
		assert_eq(covered, expected[adventurer], adventurer)
	assert_eq(Challenges.COVERS["Shield bearer"], ["Protect"])
	# Nobody in the guild is a Shield bearer, so nobody covers Protect yet.
	assert_eq(Challenges.covered_by("Protect", EVERYONE, Adventurers.STARTERS), PackedStringArray())


func test_a_challenge_is_covered_only_by_the_members_whose_class_covers_it() -> void:
	assert_eq(Challenges.covered_by("Navigation", ["bram", "tobin", "maren"], Adventurers.STARTERS), PackedStringArray(["tobin"]))
	assert_eq(Challenges.covered_by("Brute force", ["ilse", "tobin"], Adventurers.STARTERS), PackedStringArray())
