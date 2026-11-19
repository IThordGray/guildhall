extends GutTest

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
const ALL_CHALLENGES: Array[String] = ["Brute force", "Curse", "Traps", "Navigation", "Attrition", "Protect"]


func test_each_quest_has_its_rank_and_the_challenges_that_make_it_hard() -> void:
	var expected := {
		"rats": ["F", ["Brute force"]],
		"moonherbs": ["F", ["Navigation", "Attrition"]],
		"goblins": ["E", ["Brute force", "Traps", "Navigation"]],
		"letters": ["F", ["Navigation", "Protect"]],
		"wolves": ["E", ["Brute force", "Attrition"]],
		"crypt": ["E", ["Curse", "Traps", "Attrition"]],
	}
	assert_eq(Dispatch.QUESTS.keys(), expected.keys())
	for quest: String in expected:
		assert_eq([Dispatch.QUESTS[quest]["rank"], Dispatch.QUESTS[quest]["challenges"]], expected[quest], quest)


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
	assert_eq(Dispatch.new(1_000).party_refusal("goblins", EVERYONE, 1_000), "")


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
			if Challenges.covered_by(challenge, [adventurer]) == PackedStringArray([adventurer]):
				covered.append(challenge)
		assert_eq(covered, expected[adventurer], adventurer)
	assert_eq(Challenges.COVERS["Shield bearer"], ["Protect"])
	# Nobody in the guild is a Shield bearer, so nobody covers Protect yet.
	assert_eq(Challenges.covered_by("Protect", EVERYONE), PackedStringArray())


func test_a_challenge_is_covered_only_by_the_members_whose_class_covers_it() -> void:
	assert_eq(Challenges.covered_by("Navigation", ["bram", "tobin", "maren"]), PackedStringArray(["tobin"]))
	assert_eq(Challenges.covered_by("Brute force", ["ilse", "tobin"]), PackedStringArray())
