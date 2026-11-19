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


func test_the_same_seed_always_gives_the_same_outcome_and_damage() -> void:
	var successes := 0
	for roll_seed: int in 100:
		var first := Outcome.roll(roll_seed, 50, 12, PARTY)
		var again := Outcome.roll(roll_seed, 50, 12, PARTY)
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


func test_a_success_deals_each_member_0_to_half_the_difficulty_and_a_failure_half_to_all_of_it() -> void:
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


func test_each_challenge_nobody_covers_takes_15_points_off_the_chance_kept_within_5_to_95() -> void:
	assert_eq(Outcome.chance_percent(7, 7, 0), 50)
	assert_eq(Outcome.chance_percent(7, 7, 1), 35)
	assert_eq(Outcome.chance_percent(7, 7, 2), 20)
	assert_eq(Outcome.chance_percent(7, 7, 3), 5)
	assert_eq(Outcome.chance_percent(7, 7, 4), 5)
	# The 15 comes off the power chance as kept within 95: far too strong still loses it.
	assert_eq(Outcome.chance_percent(16, 3, 1), 80)


func test_a_party_with_a_healer_takes_half_the_damage_rounded_down() -> void:
	var healed: PackedStringArray = ["bram", "maren"]
	var unhealed: PackedStringArray = ["bram", "tobin"]
	var seen := {true: {}, false: {}}
	for roll_seed: int in 600:
		var with_healer := Outcome.roll(roll_seed, 50, 11, healed)
		var without := Outcome.roll(roll_seed, 50, 11, unhealed)
		assert_eq(with_healer.success, without.success)
		assert_eq(with_healer.damage["bram"], floori(without.damage["bram"] / 2.0))
		for adventurer: String in healed:
			seen[with_healer.success][with_healer.damage[adventurer]] = true
	var on_success: Array = seen[true].keys()
	var on_failure: Array = seen[false].keys()
	on_success.sort()
	on_failure.sort()
	assert_eq(on_success, [0, 1, 2])
	assert_eq(on_failure, [2, 3, 4, 5])


func test_the_range_shown_is_the_chance_widened_by_10_with_no_unknown_challenges() -> void:
	assert_eq(Outcome.chance_range(7, 7, 0, 0), Vector2i(40, 60))
	assert_eq(Outcome.chance_range(7, 7, 1, 0), Vector2i(25, 45))
	assert_eq(Outcome.chance_range(16, 3, 0, 0), Vector2i(85, 95))


func test_the_range_counts_one_unknown_challenge_uncovered_at_the_low_end_and_covered_at_the_high() -> void:
	assert_eq(Outcome.chance_range(7, 7, 0, 1), Vector2i(25, 60))
	assert_eq(Outcome.chance_range(8, 7, 1, 1), Vector2i(20, 55))


func test_the_range_counts_two_unknown_challenges_and_never_goes_below_5() -> void:
	assert_eq(Outcome.chance_range(7, 7, 0, 2), Vector2i(10, 60))
	assert_eq(Outcome.chance_range(7, 7, 1, 2), Vector2i(5, 45))


func test_the_true_chance_always_lies_inside_the_range_shown() -> void:
	var checked := 0
	for power: int in 16:
		for difficulty: int in range(3, 13):
			for uncovered: int in 4:
				for unknown: int in 3:
					var shown := Outcome.chance_range(power, difficulty, uncovered, unknown)
					# However many of the unknown challenges the party turns out to cover.
					for covered: int in unknown + 1:
						var chance := Outcome.chance_percent(power, difficulty, uncovered + unknown - covered)
						assert_between(chance, shown.x, shown.y)
						checked += 1
	assert_gt(checked, 0)
