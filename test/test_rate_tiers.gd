extends GutTest

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]


## A new game's hall at 1_000, ranked D, with its side room a finished `type` from 1_005 and its
## backroom restored and empty, the builder free, paid from `gold`.
func _hall_with_room(type: String, gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	hall.rank = "D"
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_001)
	assert_true(hall.restore("back_left", gold, 1_001))
	hall.checkpoint(1_003)
	assert_true(hall.convert_room("side_left", type, gold, 1_003), type)
	hall.checkpoint(1_005)
	return hall


## A guild of the four starters at `at`, nobody out or training.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


# --- Tavern ---


func test_a_taverns_gold_grows_at_20_then_40_then_60_a_minute_each_tier_counting_from_when_it_was_reached() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("tavern", gold)
	assert_eq(hall.tavern_gold("side_left", 1_065), 20)
	# Tier 2 from 1_069: 64 s at 20 a minute, then 30 s at 40.
	assert_true(hall.upgrade("side_left", gold, 1_065))
	assert_eq(hall.tavern_gold("side_left", 1_069), 21)
	assert_eq(hall.tavern_gold("side_left", 1_099), 41)
	var before := gold.amount
	assert_eq(hall.collect("side_left", gold, 1_099), 41)
	assert_eq(gold.amount, before + 41)
	assert_eq(hall.tavern_gold("side_left", 1_099), 0)
	assert_eq(hall.tavern_gold("side_left", 1_129), 20)
	# Tier 3 from 1_139: 40 s at 40 a minute since the collect, then 30 s at 60.
	hall.checkpoint(1_129)
	assert_true(hall.upgrade("side_left", gold, 1_129))
	assert_eq(hall.tavern_gold("side_left", 1_138), 26)
	assert_eq(hall.tavern_gold("side_left", 1_169), 56)
	before = gold.amount
	assert_eq(hall.collect("side_left", gold, 1_169), 56)
	assert_eq(gold.amount, before + 56)
	assert_eq(hall.tavern_gold("side_left", 1_229), 60)


func test_a_tavern_stops_at_40_then_120_then_300_by_its_tier() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("tavern", gold)
	assert_eq(hall.tavern_gold("side_left", 4_605), 40)
	assert_eq(hall.collect("side_left", gold, 4_605), 40)
	assert_true(hall.upgrade("side_left", gold, 4_605))
	assert_eq(hall.tavern_gold("side_left", 8_205), 120)
	assert_eq(hall.tavern_gold("side_left", 8_205 + 86_400), 120)
	assert_eq(hall.collect("side_left", gold, 8_205), 120)
	hall.checkpoint(8_205)
	assert_true(hall.upgrade("side_left", gold, 8_205))
	# Tier 3 from 8_215: 10 s at 40 a minute, then 60 a minute.
	assert_eq(hall.tavern_gold("side_left", 8_505), 296)
	assert_eq(hall.tavern_gold("side_left", 8_515), 300)
	assert_eq(hall.tavern_gold("side_left", 8_515 + 86_400), 300)
	var before := gold.amount
	assert_eq(hall.collect("side_left", gold, 8_515 + 86_400), 300)
	assert_eq(gold.amount, before + 300)
	assert_eq(hall.tavern_gold("side_left", 8_515 + 86_400 + 60), 60)


func test_a_full_tavern_reaching_its_next_tier_holds_its_old_cap_then_grows_at_the_new_rate() -> void:
	var gold := Gold.new(10_000)
	var away := _hall_with_room("tavern", gold)
	var watched := _hall_with_room("tavern", gold)
	assert_eq(away.tavern_gold("side_left", 4_605), 40)
	# Full at 40 since 1_125; tier 2 from 4_609.
	assert_true(away.upgrade("side_left", gold, 4_605))
	assert_true(watched.upgrade("side_left", gold, 4_605))
	var seen := {}
	for now: int in range(4_605, 4_639 + 1):
		watched.checkpoint(now)
		seen[now] = watched.tavern_gold("side_left", now)
	assert_eq(seen[4_609], 40)
	assert_eq(away.tavern_gold("side_left", 4_609), 40)
	assert_eq(away.tavern_gold("side_left", 4_639), 60)
	assert_eq(seen[4_639], 60)
	assert_eq(away.tavern_gold("side_left", 4_609 + 120), 120)
	assert_eq(away.tavern_gold("side_left", 4_609 + 86_400), 120)


func test_one_read_after_an_absence_spanning_a_tavern_upgrade_equals_reading_every_second() -> void:
	var away_gold := Gold.new(10_000)
	var away := _hall_with_room("tavern", away_gold)
	var watched_gold := Gold.new(10_000)
	var watched := _hall_with_room("tavern", watched_gold)
	assert_true(away.upgrade("side_left", away_gold, 1_065))
	assert_true(watched.upgrade("side_left", watched_gold, 1_065))
	var seen := 0
	for now: int in range(1_065, 1_159 + 1):
		watched.checkpoint(now)
		var held := watched.tavern_gold("side_left", now)
		assert_true(held >= seen, str(now))
		seen = held
	# 64 s at 20 a minute, then 90 s at 40 from tier 2 at 1_069.
	assert_eq(seen, 81)
	assert_eq(away.tavern_gold("side_left", 1_159), 81)
	assert_eq(away.collect("side_left", away_gold, 1_159), 81)
	assert_eq(watched.collect("side_left", watched_gold, 1_159), 81)


# --- Training room ---


func test_a_stint_gives_up_to_20_xp_at_tier_1_and_40_at_tiers_2_and_3_still_1_xp_per_6_seconds() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("training_room", gold)
	var dispatch := _guild(1_005)
	assert_true(dispatch.train("bram", hall.training_places(1_005), 1_005))
	assert_eq(dispatch.training_xp("bram", 1_245, hall.stint_xp(1_245)), 20)
	assert_eq(dispatch.training_seconds_left("bram", 1_005, hall.stint_xp(1_005)), 120)
	# The cap is the tier's when read: tier 2 from 1_249 lifts the running stint to 40.
	hall.checkpoint(1_245)
	assert_true(hall.upgrade("side_left", gold, 1_245))
	assert_eq(dispatch.training_xp("bram", 1_248, hall.stint_xp(1_248)), 20)
	assert_eq(dispatch.training_xp("bram", 1_249, hall.stint_xp(1_249)), 40)
	assert_eq(dispatch.stop_training("bram", 1_249, hall.stint_xp(1_249)), 40)
	assert_eq(dispatch.adventurers.xp["bram"], 40)
	# A stint at tier 2.
	assert_true(dispatch.train("bram", hall.training_places(1_249), 1_249))
	assert_eq(dispatch.training_seconds_left("bram", 1_249, hall.stint_xp(1_249)), 240)
	for at: Array in [[1_249 + 120, 20], [1_249 + 239, 39], [1_249 + 240, 40], [1_249 + 86_400, 40]]:
		assert_eq(dispatch.training_xp("bram", at[0], hall.stint_xp(at[0])), at[1], str(at[0]))
	var stopped := 1_249 + 86_400
	assert_eq(dispatch.stop_training("bram", stopped, hall.stint_xp(stopped)), 40)
	# A stint at tier 3.
	hall.checkpoint(stopped)
	assert_true(hall.upgrade("side_left", gold, stopped))
	var tier_3 := stopped + 10
	assert_eq(hall.tier("side_left", tier_3), 3)
	assert_true(dispatch.train("bram", hall.training_places(tier_3), tier_3))
	assert_eq(dispatch.training_xp("bram", tier_3 + 86_400, hall.stint_xp(tier_3 + 86_400)), 40)
	assert_eq(dispatch.stop_training("bram", tier_3 + 86_400, hall.stint_xp(tier_3 + 86_400)), 40)
	assert_eq(dispatch.adventurers.xp["bram"], 120)


func test_a_tier_3_training_room_takes_two_trainees_at_once_and_a_third_is_refused() -> void:
	var gold := Gold.new(10_000)
	var hall := _hall_with_room("training_room", gold)
	var dispatch := _guild(1_005)
	assert_true(dispatch.train("bram", hall.training_places(1_005), 1_005))
	assert_eq(dispatch.training_refusal("ilse", hall.training_places(1_005), 1_005), Dispatch.NO_TRAINING_PLACE)
	# Tier 2, from 1_009, still has one place.
	assert_true(hall.upgrade("side_left", gold, 1_005))
	hall.checkpoint(1_009)
	assert_false(dispatch.train("ilse", hall.training_places(1_009), 1_009))
	# Tier 3, from 1_019, has two.
	assert_true(hall.upgrade("side_left", gold, 1_009))
	assert_false(dispatch.train("ilse", hall.training_places(1_018), 1_018))
	assert_true(dispatch.train("ilse", hall.training_places(1_019), 1_019))
	assert_eq(dispatch.training_refusal("tobin", hall.training_places(1_019), 1_019), Dispatch.NO_TRAINING_PLACE)
	assert_false(dispatch.train("tobin", hall.training_places(1_019), 1_019))
	assert_eq(dispatch.training.keys(), ["bram", "ilse"])
	# A stop frees a place for the third.
	dispatch.stop_training("bram", 1_030, hall.stint_xp(1_030))
	assert_true(dispatch.train("tobin", hall.training_places(1_030), 1_030))
	assert_eq(dispatch.training.keys(), ["ilse", "tobin"])


# --- Upgrade cards ---


func test_the_upgrade_cards_for_a_tavern_and_a_training_room_say_what_the_next_tier_adds() -> void:
	var adds: Dictionary[String, Array] = {
		"tavern": ["+20 g a minute, holds more", "+20 g a minute, holds more"],
		"training_room": ["40 XP a stint", "A second trainee"],
	}
	for type: String in adds:
		var gold := Gold.new(10_000)
		var hall := _hall_with_room(type, gold)
		assert_eq(hall.next_upgrade("side_left", 1_005).get("blurb", ""), adds[type][0], type)
		assert_true(hall.upgrade("side_left", gold, 1_005), type)
		hall.checkpoint(1_009)
		assert_eq(hall.next_upgrade("side_left", 1_009).get("blurb", ""), adds[type][1], type)
		assert_true(hall.upgrade("side_left", gold, 1_009), type)
		assert_eq(hall.next_upgrade("side_left", 1_019), {}, type)
