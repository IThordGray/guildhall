extends GutTest

const PARTY: PackedStringArray = ["bram", "ilse", "tobin"]


func test_a_challenges_chance_is_even_when_the_total_meets_the_requirement_and_moves_two_points_per_point() -> void:
	assert_eq(Outcome.challenge_chance(20, 20), 50)
	assert_eq(Outcome.challenge_chance(21, 20), 52)
	assert_eq(Outcome.challenge_chance(12, 20), 34)
	assert_eq(Outcome.challenge_chance(35, 20), 80)


func test_a_challenges_chance_never_rises_above_95_or_falls_below_5() -> void:
	assert_eq(Outcome.challenge_chance(42, 20), 94)
	assert_eq(Outcome.challenge_chance(43, 20), 95)
	assert_eq(Outcome.challenge_chance(80, 20), 95)
	assert_eq(Outcome.challenge_chance(-2, 20), 6)
	assert_eq(Outcome.challenge_chance(-3, 20), 5)
	assert_eq(Outcome.challenge_chance(0, 90), 5)


func test_a_quests_chance_is_its_challenges_average_with_the_weakest_counted_twice() -> void:
	assert_eq(Outcome.chance_percent([70]), 70)
	# A plain average would be 60.
	assert_eq(Outcome.chance_percent([90, 30]), 50)
	assert_eq(Outcome.chance_percent([30, 90]), 50)
	# (80 + 60 + 40 + 40) ÷ 4.
	assert_eq(Outcome.chance_percent([80, 60, 40]), 55)
	# 220 ÷ 3, rounded down.
	assert_eq(Outcome.chance_percent([80, 70]), 73)


func test_the_bonus_comes_on_after_the_average_kept_within_5_to_95() -> void:
	assert_eq(Outcome.chance_percent([90, 30], 7), 57)
	assert_eq(Outcome.chance_percent([95, 90], 15), 95)
	assert_eq(Outcome.chance_percent([5, 5], 0), 5)


func test_a_lucky_break_lifts_only_the_weakest_challenge_only_to_50_and_only_when_below_it() -> void:
	# The weakest, 30, counts at 50: (90 + 50 + 50) ÷ 3.
	assert_eq(Outcome.chance_percent([90, 30], 0, true), 63)
	# Only the weakest: 40 stays 40, so it becomes the weakest; (90 + 50 + 40 + 40) ÷ 4.
	assert_eq(Outcome.chance_percent([90, 30, 40], 0, true), 55)
	# Of two equally weak, only one is lifted: (50 + 30 + 30) ÷ 3.
	assert_eq(Outcome.chance_percent([30, 30], 0, true), 36)
	# Never above 50: a single challenge at 10 counts at exactly 50.
	assert_eq(Outcome.chance_percent([10], 0, true), 50)
	# The weakest at 50 or more is left as it is.
	assert_eq(Outcome.chance_percent([90, 60], 0, true), Outcome.chance_percent([90, 60]))
	assert_eq(Outcome.chance_percent([90, 50], 0, true), Outcome.chance_percent([90, 50]))


func test_a_lucky_break_comes_2_percent_a_point_of_luck_at_most_25_and_never_without_luck() -> void:
	const SEEDS: int = 4_000
	var breaks := {0: 0, 1: 0, 5: 0, 12: 0, 13: 0, 40: 0}
	for roll_seed: int in SEEDS:
		for luck: int in breaks:
			if Outcome.lucky_break(roll_seed, luck):
				breaks[luck] += 1
	assert_eq(breaks[0], 0)
	# 2%, 10% and 24% of 4,000 within 1.5 points, then capped at 25%.
	assert_between(breaks[1], 20, 140)
	assert_between(breaks[5], 340, 460)
	assert_between(breaks[12], 900, 1_020)
	assert_between(breaks[13], 940, 1_060)
	assert_between(breaks[40], 940, 1_060)


func test_the_same_seed_always_gives_the_same_lucky_break() -> void:
	var any := false
	for roll_seed: int in 200:
		assert_eq(Outcome.lucky_break(roll_seed, 10), Outcome.lucky_break(roll_seed, 10))
		any = any or Outcome.lucky_break(roll_seed, 10)
	assert_true(any)


func test_the_same_seed_always_gives_the_same_outcome_and_damage() -> void:
	var successes := 0
	for roll_seed: int in 100:
		var first := Outcome.roll(roll_seed, 50, 12, PARTY, 4, 6)
		var again := Outcome.roll(roll_seed, 50, 12, PARTY, 4, 6)
		assert_eq(again.success, first.success)
		assert_eq(again.damage, first.damage)
		if first.success:
			successes += 1
	assert_between(successes, 1, 99, "both outcomes occur, so the seed decides")


func test_over_2000_seeds_a_60_percent_chance_succeeds_60_percent_of_the_time_within_4_points() -> void:
	var successes := 0
	for roll_seed: int in 2_000:
		if Outcome.roll(roll_seed, 60, 7, PARTY).success:
			successes += 1
	assert_between(successes, 1_120, 1_280)


func test_a_success_deals_each_member_0_to_half_the_most_damage_and_a_failure_half_to_all_of_it() -> void:
	var seen := {true: {}, false: {}}
	for roll_seed: int in 600:
		var outcome := Outcome.roll(roll_seed, 50, 11, PARTY)
		assert_eq(outcome.damage.keys(), Array(PARTY))
		for adventurer: String in PARTY:
			seen[outcome.success][outcome.damage[adventurer]] = true
	var on_success: Array = seen[true].keys()
	var on_failure: Array = seen[false].keys()
	on_success.sort()
	on_failure.sort()
	assert_eq(on_success, [0, 1, 2, 3, 4, 5])
	assert_eq(on_failure, [5, 6, 7, 8, 9, 10, 11])


func test_members_of_one_party_can_take_different_damage() -> void:
	var differs := false
	for roll_seed: int in 50:
		var damage := Outcome.roll(roll_seed, 50, 12, PARTY).damage
		if damage["bram"] != damage["ilse"]:
			differs = true
	assert_true(differs)


func test_the_partys_spirit_cuts_the_damage_2_percent_a_point_up_to_half() -> void:
	for roll_seed: int in 300:
		var plain := Outcome.roll(roll_seed, 50, 40, PARTY)
		var some := Outcome.roll(roll_seed, 50, 40, PARTY, 10)
		var most := Outcome.roll(roll_seed, 50, 40, PARTY, 25)
		var far_more := Outcome.roll(roll_seed, 50, 40, PARTY, 40)
		# Spirit never changes whether the quest succeeds.
		assert_eq(some.success, plain.success)
		for adventurer: String in PARTY:
			var dealt: int = plain.damage[adventurer]
			assert_eq(some.damage[adventurer], floori(dealt * 80 / 100.0), "10 Spirit takes 20% off")
			assert_eq(most.damage[adventurer], floori(dealt / 2.0), "25 Spirit takes half off")
			assert_eq(far_more.damage[adventurer], floori(dealt / 2.0), "never more than half")


func test_the_partys_luck_shaves_2_percent_a_point_off_a_failures_damage_up_to_30_and_nothing_off_a_success() -> void:
	var failures := 0
	var successes := 0
	for roll_seed: int in 300:
		var plain := Outcome.roll(roll_seed, 50, 40, PARTY)
		var lucky := Outcome.roll(roll_seed, 50, 40, PARTY, 0, 5)
		var luckiest := Outcome.roll(roll_seed, 50, 40, PARTY, 0, 15)
		var beyond := Outcome.roll(roll_seed, 50, 40, PARTY, 0, 60)
		assert_eq(lucky.success, plain.success)
		for adventurer: String in PARTY:
			var dealt: int = plain.damage[adventurer]
			if plain.success:
				assert_eq(beyond.damage[adventurer], dealt, "luck takes nothing off a success")
			else:
				assert_eq(lucky.damage[adventurer], floori(dealt * 90 / 100.0), "5 Luck takes 10% off")
				assert_eq(luckiest.damage[adventurer], floori(dealt * 70 / 100.0), "15 Luck takes 30% off")
				assert_eq(beyond.damage[adventurer], floori(dealt * 70 / 100.0), "never more than 30%")
		if plain.success:
			successes += 1
		else:
			failures += 1
	assert_gt(successes, 0)
	assert_gt(failures, 0)


func test_the_range_shown_is_the_chance_widened_by_10_with_no_unknown_challenges() -> void:
	assert_eq(Outcome.chance_range([50], 0), Vector2i(40, 60))
	assert_eq(Outcome.chance_range([90, 30], 0), Vector2i(40, 60))
	assert_eq(Outcome.chance_range([95, 95], 0), Vector2i(85, 95))
	assert_eq(Outcome.chance_range([50], 0, 15), Vector2i(55, 75))


func test_the_range_counts_an_unknown_challenge_as_an_even_match_in_the_weakest_twice_average() -> void:
	# (80 + 50 + 50) ÷ 3 = 60, the unknown one the weakest; plus or less 10.
	assert_eq(Outcome.chance_range([80], 1), Vector2i(50, 70))
	# (20 + 20 + 50) ÷ 3 = 30, the known one the weakest.
	assert_eq(Outcome.chance_range([20], 1), Vector2i(20, 40))
	# (60 + 50 + 50 + 50) ÷ 4 = 52.
	assert_eq(Outcome.chance_range([60], 2), Vector2i(42, 62))
	# (80 + 50 + 50) ÷ 3 = 60, and 15 points for tries.
	assert_eq(Outcome.chance_range([80], 1, 15), Vector2i(65, 85))


func test_the_range_leaves_a_lucky_break_out() -> void:
	# (90 + 30 + 30) ÷ 3 = 50 without one; a lucky break makes it (90 + 50 + 50) ÷ 3 = 63.
	assert_eq(Outcome.chance_range([90, 30], 0), Vector2i(40, 60))
	assert_eq(Outcome.chance_percent([90, 30], 0, true), 63)


func test_with_every_challenge_known_the_true_chance_lies_inside_the_range_and_with_one_unknown_it_is_counted_at_50() -> void:
	var known_checked := 0
	var unknown_checked := 0
	var samples: Array[int] = [5, 20, 35, 49, 50, 65, 80, 95]
	for a: int in samples:
		for b: int in samples:
			for c: int in samples:
				for bonus: int in [0, 7, 15]:
					var truth: Array[int] = [a, b, c]
					for unknown: int in 3:
						var known: Array[int] = truth.slice(0, 3 - unknown)
						var shown := Outcome.chance_range(known, unknown, bonus)
						assert_lte(shown.y - shown.x, 20, "at most 20 wide")
						if unknown == 0:
							assert_between(Outcome.chance_percent(truth, bonus), shown.x, shown.y)
							known_checked += 1
							continue
						var even := known.duplicate()
						for each: int in unknown:
							even.append(50)
						var middle := Outcome.chance_percent(even, bonus)
						assert_eq(shown, Vector2i(maxi(5, middle - 10), mini(95, middle + 10)))
						unknown_checked += 1
	assert_gt(known_checked, 0)
	assert_gt(unknown_checked, 0)
