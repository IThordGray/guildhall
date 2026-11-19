extends GutTest

const PARTY: PackedStringArray = ["bram", "ilse", "tobin"]


func test_the_chance_is_even_at_equal_power_and_moves_ten_points_per_point_of_difference() -> void:
	assert_eq(Outcome.chance_percent(7, 7), 50)
	assert_eq(Outcome.chance_percent(8, 7), 60)
	assert_eq(Outcome.chance_percent(4, 7), 20)
	assert_eq(Outcome.chance_percent(11, 7), 90)


func test_the_chance_never_rises_above_95_or_falls_below_5() -> void:
	assert_eq(Outcome.chance_percent(11, 3), 95)
	assert_eq(Outcome.chance_percent(12, 7), 95)
	assert_eq(Outcome.chance_percent(3, 7), 10)
	assert_eq(Outcome.chance_percent(3, 12), 5)
	assert_eq(Outcome.chance_percent(0, 12), 5)


func test_the_same_seed_always_gives_the_same_outcome() -> void:
	var successes := 0
	for roll_seed: int in 100:
		var first := Outcome.roll(roll_seed, 50, PARTY)
		var again := Outcome.roll(roll_seed, 50, PARTY)
		assert_eq(again.success, first.success)
		assert_eq(again.injured, first.injured)
		if first.success:
			successes += 1
	assert_between(successes, 1, 99, "both outcomes occur, so the seed decides")


func test_over_2000_seeds_a_60_percent_chance_succeeds_60_percent_of_the_time_within_4_points() -> void:
	var successes := 0
	for roll_seed: int in 2_000:
		if Outcome.roll(roll_seed, 60, PARTY).success:
			successes += 1
	assert_between(successes, 1_120, 1_280)


func test_a_failure_injures_one_member_of_the_party_and_a_success_injures_nobody() -> void:
	var injured := {}
	for roll_seed: int in 300:
		var outcome := Outcome.roll(roll_seed, 50, PARTY)
		if outcome.success:
			assert_eq(outcome.injured, "")
		else:
			assert_has(PARTY, outcome.injured)
			injured[outcome.injured] = true
	assert_eq(injured.size(), 3, "the seed picks who, so every member can be the one")
