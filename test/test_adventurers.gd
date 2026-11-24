extends GutTest

const Fixtures := preload("res://test/fixtures.gd")

const SAVE_PATH: String = "user://test_adventurers_save.cfg"
const EVERYONE: Array[String] = ["bram", "ilse", "tobin", "maren"]
const BRAM_STATS: Dictionary = {"strength": 6, "agility": 3, "perception": 3, "mind": 2, "spirit": 3, "defence": 7, "endurance": 5, "presence": 3, "luck": 1}
const TOBIN_STATS: Dictionary = {"strength": 3, "agility": 7, "perception": 6, "mind": 3, "spirit": 3, "defence": 3, "endurance": 3, "presence": 3, "luck": 4}
## Someone leaning Strength and Defence: 25 in all.
const WREN_STATS: Dictionary = {"strength": 4, "agility": 2, "perception": 2, "mind": 1, "spirit": 2, "defence": 8, "endurance": 3, "presence": 2, "luck": 1}


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_everyone_starts_in_their_design_gear_which_adds_to_their_stats() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.gear.worn["bram"], {"head": "iron_cap", "clothes": "red_tunic", "armour": "leather_vest", "weapon": "short_sword", "off_hand": "round_shield"})
	assert_eq(adventurers.gear.worn["ilse"], {"head": "pointed_hat", "clothes": "apprentice_robe", "neck": "moonstone_amulet", "weapon": "oak_staff"})
	assert_eq(adventurers.gear.worn["tobin"], {"head": "scouts_hood", "clothes": "leather_jerkin", "weapon": "hunting_bow", "back": "quiver"})
	assert_eq(adventurers.gear.worn["maren"], {"clothes": "healers_robe", "belt": "green_sash", "weapon": "bell_mace"})
	assert_eq(adventurers.gear.stash, PackedStringArray())
	# Bram's iron cap and round shield add 2 to his Defence of 7.
	assert_eq(adventurers.max_health("bram"), 28)
	assert_eq(adventurers.max_health("tobin"), 16)


func test_a_stat_is_own_plus_gear_and_health_counts_the_total() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gear.stow("chapel_plate")
	adventurers.gear.wear("tobin", 0)
	# Tobin's own Defence 3 and Spirit 3 with Chapel plate's Defence +4, Spirit +2; his other gear
	# adds 2 to Agility.
	assert_eq(adventurers.stat_total("tobin", "defence"), 7)
	assert_eq(adventurers.stat_total("tobin", "spirit"), 5)
	assert_eq(adventurers.stat_total("tobin", "agility"), 9)
	assert_eq(adventurers.stats["tobin"], TOBIN_STATS)
	assert_eq(adventurers.max_health("tobin"), 24)
	# Swapping it for a leather vest, Endurance +1.
	adventurers.gear.stow("leather_vest")
	adventurers.gear.wear("tobin", 0)
	assert_eq(adventurers.gear.worn["tobin"]["armour"], "leather_vest")
	assert_eq(adventurers.stat_total("tobin", "defence"), 3)
	assert_eq(adventurers.stat_total("tobin", "endurance"), 4)
	assert_eq(adventurers.max_health("tobin"), 16)


func test_everyone_starts_at_level_one_with_no_xp_and_their_starting_stats() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.stats["bram"], BRAM_STATS)
	assert_eq(adventurers.stats["ilse"], {"strength": 2, "agility": 3, "perception": 3, "mind": 8, "spirit": 3, "defence": 5, "endurance": 3, "presence": 6, "luck": 1})
	assert_eq(adventurers.stats["tobin"], TOBIN_STATS)
	assert_eq(adventurers.stats["maren"], {"strength": 2, "agility": 3, "perception": 3, "mind": 6, "spirit": 7, "defence": 5, "endurance": 3, "presence": 3, "luck": 1})
	for adventurer: String in EVERYONE:
		assert_eq(adventurers.levels[adventurer], 1)
		assert_eq(adventurers.xp[adventurer], 0)
		assert_false(adventurers.level_up_ready(adventurer))


func test_maximum_health_is_ten_plus_two_per_defence_and_a_level_up_that_raises_defence_raises_it() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.max_health("bram"), 28)
	assert_eq(adventurers.max_health("ilse"), 20)
	assert_eq(adventurers.max_health("tobin"), 16)
	assert_eq(adventurers.max_health("maren"), 20)
	adventurers.gain_xp("bram", 1_000_000)
	var defence_gain := 0
	while defence_gain == 0:
		defence_gain = adventurers.level_up("bram")["defence"]
	# His gear adds 2 to his own Defence.
	assert_eq(adventurers.max_health("bram"), 10 + 2 * (int(adventurers.stats["bram"]["defence"]) + 2) + 3 * (adventurers.levels["bram"] - 1))
	assert_gt(adventurers.max_health("bram"), 28)


func test_a_quest_gives_its_party_its_whole_xp_on_success_and_a_quarter_rounded_down_but_at_least_1_on_failure() -> void:
	assert_eq(Adventurers.quest_xp(40, true), 40)
	assert_eq(Adventurers.quest_xp(40, false), 10)
	assert_eq(Adventurers.quest_xp(13, true), 13)
	assert_eq(Adventurers.quest_xp(13, false), 3)
	assert_eq(Adventurers.quest_xp(7, false), 1)
	assert_eq(Adventurers.quest_xp(3, true), 3)
	assert_eq(Adventurers.quest_xp(3, false), 1)
	assert_eq(Adventurers.quest_xp(1, true), 1)
	assert_eq(Adventurers.quest_xp(1, false), 1)


func test_a_level_up_needs_the_xp_its_level_asks_and_spends_it_keeping_the_rest() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.xp_needed("ilse"), 10)
	adventurers.gain_xp("ilse", 9)
	assert_false(adventurers.level_up_ready("ilse"))
	assert_eq(adventurers.level_up("ilse"), {})
	assert_eq(adventurers.levels["ilse"], 1)
	assert_eq(adventurers.xp["ilse"], 9)
	adventurers.gain_xp("ilse", 22)
	assert_true(adventurers.level_up_ready("ilse"))
	assert_false(adventurers.level_up("ilse").is_empty())
	assert_eq(adventurers.levels["ilse"], 2)
	assert_eq(adventurers.xp["ilse"], 21)
	assert_eq(adventurers.xp_needed("ilse"), 20)
	assert_true(adventurers.level_up_ready("ilse"))
	adventurers.level_up("ilse")
	assert_eq(adventurers.levels["ilse"], 3)
	assert_eq(adventurers.xp["ilse"], 1)
	assert_eq(adventurers.xp_needed("ilse"), 40)
	assert_false(adventurers.level_up_ready("ilse"))
	assert_eq(adventurers.levels["bram"], 1)


func test_the_xp_to_the_next_level_follows_the_curve_then_grows_30_percent_a_level_and_never_falls() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var curve: Array[int] = [10, 20, 40, 60, 100, 140, 200, 270, 350, 450]
	for level: int in range(1, 11):
		adventurers.levels["ilse"] = level
		assert_eq(adventurers.xp_needed("ilse"), curve[level - 1], "level %d" % level)
	# 450 × 1.3 = 585, to the nearest 10; then 590 × 1.3 = 767.
	adventurers.levels["ilse"] = 11
	assert_eq(adventurers.xp_needed("ilse"), 590)
	adventurers.levels["ilse"] = 12
	assert_eq(adventurers.xp_needed("ilse"), 770)
	var before := 0
	for level: int in range(1, 41):
		adventurers.levels["ilse"] = level
		assert_gte(adventurers.xp_needed("ilse"), before, "level %d" % level)
		before = adventurers.xp_needed("ilse")


func test_a_level_up_raises_each_stat_by_zero_to_two_the_same_for_the_same_adventurer_and_level() -> void:
	var first := Adventurers.new(EVERYONE)
	var second := Adventurers.new(EVERYONE)
	for adventurer: String in EVERYONE:
		first.gain_xp(adventurer, 1_000_000)
		second.gain_xp(adventurer, 1_000_000)
		for level: int in 10:
			var before: Dictionary = first.stats[adventurer].duplicate()
			var gains := first.level_up(adventurer)
			assert_eq(second.level_up(adventurer), gains, "%s level %d" % [adventurer, level + 2])
			assert_eq(gains.keys(), ["strength", "agility", "perception", "mind", "spirit", "defence", "endurance", "presence", "luck"])
			for stat: String in gains:
				assert_between(int(gains[stat]), 0, 2)
				assert_eq(first.stats[adventurer][stat], before[stat] + gains[stat])
		assert_eq(first.stats[adventurer], second.stats[adventurer])


func test_tobins_agility_grows_faster_than_any_of_his_other_stats() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gain_xp("tobin", 1_000_000)
	var start: Dictionary = adventurers.stats["tobin"].duplicate()
	for level: int in 20:
		adventurers.level_up("tobin")
	var agility_gained: int = adventurers.stats["tobin"]["agility"] - start["agility"]
	for stat: String in Adventurers.STATS:
		if stat != "agility":
			assert_gt(agility_gained, adventurers.stats["tobin"][stat] - start[stat], stat)


func test_the_history_records_each_level_up_with_what_it_gave() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.history["maren"], [])
	adventurers.gain_xp("maren", 120)
	var to_two := adventurers.level_up("maren")
	var to_three := adventurers.level_up("maren")
	assert_eq(adventurers.history["maren"], [{"level": 2, "gains": to_two}, {"level": 3, "gains": to_three}])
	assert_eq(adventurers.history["bram"], [])


func test_stats_levels_xp_and_history_survive_save_and_load() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gain_xp("tobin", 40)
	adventurers.level_up("tobin")
	adventurers.level_up("tobin")
	adventurers.gain_xp("bram", 25)
	var file := ConfigFile.new()
	adventurers.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Adventurers.load_or_start(SAVE_PATH)
	assert_eq(loaded.levels["tobin"], 3)
	assert_eq(loaded.xp["tobin"], 10)
	assert_eq(loaded.xp["bram"], 25)
	assert_eq(loaded.stats, adventurers.stats)
	assert_eq(loaded.history["tobin"], adventurers.history["tobin"])
	assert_eq(loaded.history["tobin"].size(), 2)
	# The next level-up after loading grows as it would have without the reload.
	loaded.gain_xp("tobin", 120)
	adventurers.gain_xp("tobin", 120)
	assert_eq(loaded.level_up("tobin"), adventurers.level_up("tobin"))


func test_a_save_from_the_previous_build_loads_with_starter_stats_and_nothing_else_lost() -> void:
	var gold := Gold.new(300)
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("goblins", Fixtures.party(dispatch, ["bram", "ilse"]), 1, 1_000))
	# The previous build kept no chance with a party out, and wrote no adventurers.
	dispatch.outings[0].erase("chance")
	var file := ConfigFile.new()
	gold.write(file)
	Hall.new(1_000).write(file)
	dispatch.write(file)
	file.erase_section("adventurers")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_100)
	assert_eq(loaded.adventurers.stats, Adventurers.STARTING_STATS)
	for adventurer: String in EVERYONE:
		assert_eq(loaded.adventurers.levels[adventurer], 1)
		assert_eq(loaded.adventurers.xp[adventurer], 0)
		assert_eq(loaded.adventurers.history[adventurer], [])
	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 300)
	assert_eq(loaded.status("bram", 1_100), "On quest: Goblin camp")
	loaded.checkpoint(1_600)
	# Goblin camp's 30 XP shared by two on a success, or a quarter of it on a failure.
	assert_true(loaded.outings.is_empty())
	assert_has([15, 3], loaded.adventurers.xp["bram"])
	assert_eq(loaded.adventurers.xp["ilse"], loaded.adventurers.xp["bram"])


func test_a_save_from_the_current_build_loads_with_starter_gear_an_empty_stash_and_nothing_else_lost() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gain_xp("ilse", 20)
	adventurers.level_up("ilse")
	var file := ConfigFile.new()
	adventurers.write(file)
	# The current build writes no gear.
	file.erase_section("gear")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Adventurers.load_or_start(SAVE_PATH)
	assert_eq(loaded.gear.worn, Gear.STARTER_GEAR)
	assert_eq(loaded.gear.stash, PackedStringArray())
	assert_eq(loaded.levels["ilse"], 2)
	assert_eq(loaded.xp["ilse"], 10)
	assert_eq(loaded.stats, adventurers.stats)
	assert_eq(loaded.history, adventurers.history)


func test_an_added_adventurer_joins_last_at_level_1_with_no_xp_and_nothing_worn() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	_add_wren(adventurers)
	assert_eq(adventurers.roster.keys(), ["bram", "ilse", "tobin", "maren", "wren"])
	assert_eq(adventurers.roster["wren"]["name"], "Wren")
	assert_eq(adventurers.levels["wren"], 1)
	assert_eq(adventurers.xp["wren"], 0)
	assert_eq(adventurers.history["wren"], [])
	assert_eq(adventurers.gear.worn["wren"], {})
	# Their stats are their own alone; the starters keep their gear.
	assert_eq(adventurers.stat_total("wren", "defence"), WREN_STATS["defence"])
	assert_eq(adventurers.gear.worn["bram"], Gear.STARTER_GEAR["bram"])


func test_an_added_adventurer_survives_save_and_load_and_levels_up_by_their_own_growth() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	_add_wren(adventurers)
	var file := ConfigFile.new()
	adventurers.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Adventurers.load_or_start(SAVE_PATH)
	assert_eq(loaded.roster, adventurers.roster)
	assert_eq(loaded.roster.keys(), ["bram", "ilse", "tobin", "maren", "wren"])
	assert_eq(loaded.stats["wren"], WREN_STATS)
	assert_eq(loaded.gear.worn["wren"], {})
	assert_eq(loaded.gear.worn["tobin"], Gear.STARTER_GEAR["tobin"])
	# Certain growth gives both points and none gives nothing, whatever the roll.
	loaded.gain_xp("wren", 40)
	assert_eq(loaded.level_up("wren"), {"strength": 2, "agility": 0, "perception": 0, "mind": 0, "spirit": 0, "defence": 2, "endurance": 0, "presence": 0, "luck": 0})
	assert_eq(loaded.stats["wren"], {"strength": 6, "agility": 2, "perception": 2, "mind": 1, "spirit": 2, "defence": 10, "endurance": 3, "presence": 2, "luck": 1})


func test_a_save_from_before_the_roster_was_saved_loads_the_four_starters_as_they_were() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gain_xp("tobin", 40)
	adventurers.level_up("tobin")
	var file := ConfigFile.new()
	adventurers.write(file)
	# The previous build wrote no roster and no growth.
	file.erase_section_key("adventurers", "roster")
	file.erase_section_key("adventurers", "growth")
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Adventurers.load_or_start(SAVE_PATH)
	assert_eq(loaded.roster.keys(), EVERYONE)
	assert_eq(loaded.roster["maren"], {"name": "Maren", "rank": "F"})
	assert_eq(loaded.roster["tobin"], {"name": "Tobin", "rank": "F"})
	assert_eq(loaded.levels["tobin"], 2)
	assert_eq(loaded.stats, adventurers.stats)
	assert_eq(loaded.gear.worn, Gear.STARTER_GEAR)
	# The starters still grow by their own growth.
	loaded.gain_xp("tobin", 80)
	adventurers.gain_xp("tobin", 80)
	assert_eq(loaded.level_up("tobin"), adventurers.level_up("tobin"))


func test_maximum_health_at_level_1_is_10_plus_2_per_defence_and_each_level_past_it_adds_some_even_without_defence() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	_add_wren(adventurers)
	# 10 plus 2 per Defence, gear included.
	assert_eq(adventurers.max_health("bram"), 28)
	assert_eq(adventurers.max_health("tobin"), 16)
	assert_eq(adventurers.max_health("wren"), 26)
	adventurers.growth["wren"]["defence"] = 0.0
	adventurers.gain_xp("wren", 1_000)
	var before := adventurers.max_health("wren")
	adventurers.level_up("wren")
	assert_eq(adventurers.stats["wren"]["defence"], 8)
	assert_gt(adventurers.max_health("wren"), before)
	var one_level := adventurers.max_health("wren") - before
	adventurers.level_up("wren")
	assert_eq(adventurers.max_health("wren") - before, 2 * one_level)


func test_the_health_of_anyone_by_defence_and_level_is_10_plus_2_per_defence_plus_3_per_level_past_the_first() -> void:
	assert_eq(Adventurers.max_health_of(5, 1), 20)
	assert_eq(Adventurers.max_health_of(5, 3), 26)
	assert_eq(Adventurers.max_health_of(0, 1), 10)
	# Bram, Defence 9 with his gear, at level 1.
	assert_eq(Adventurers.max_health_of(9, 1), Adventurers.new(EVERYONE).max_health("bram"))


func test_a_failed_quest_of_a_members_promotion_rank_injures_half_to_three_quarters_with_no_spirit_or_luck() -> void:
	for rank: String in ["E", "D"]:
		var rates := _injury_rates(rank)
		assert_between(rates["failed"], 0.5, 0.75, rank)
		# Spirit enough to halve the damage, so far fewer come home injured.
		assert_lt(rates["failed_with_spirit"], rates["failed"] / 2.0, rank)
		assert_lt(rates["succeeded"], 0.1, rank)


func test_a_wound_saved_under_the_old_maximum_loads_as_it_was_and_heals_up_to_the_new_one() -> void:
	var dispatch := _guild(5_000)
	dispatch.adventurers.gain_xp("bram", 1_000)
	dispatch.adventurers.level_up("bram")
	dispatch.adventurers.level_up("bram")
	var most := dispatch.adventurers.max_health("bram")
	# Saved when level 3 gave no extra health: a point short of that maximum.
	var old_most := most - 2 * Adventurers.HEALTH_PER_LEVEL
	dispatch.wounds["bram"] = {"health": old_most - 1, "at": 5_000}
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Dispatch.load_or_start(SAVE_PATH, 5_000)
	assert_eq(loaded.health("bram", 5_000), old_most - 1)
	# Seven points short, at three points every two seconds: full in five.
	assert_eq(most - (old_most - 1), 7)
	assert_eq(loaded.seconds_to_full("bram", 5_000), 5)
	assert_eq(loaded.health("bram", 5_004), most - 1)
	assert_eq(loaded.health("bram", 5_005), most)
	assert_eq(loaded.health("bram", 50_000), most)


# The share of members at `rank`'s promotion level, levelled by their own growth, who come home
# from a quest of that rank injured from full health: failed with no Spirit or Luck, failed with
# Spirit enough to halve the damage, and succeeded. Members are the starters and 100 candidates,
# each sent with 40 fixed seeds.
func _injury_rates(rank: String) -> Dictionary:
	var level: int = Adventurers.PROMOTIONS[rank]["level"]
	var adventurers := Adventurers.new(EVERYONE)
	for i: int in 100:
		var candidate := Recruits.candidate_for(i % 4, 1_000_000 + i * 37, PackedStringArray())
		adventurers.add("c%d" % i, candidate["who"], candidate["stats"], candidate["growth"])
	var members: Array = adventurers.roster.keys()
	for member: String in members:
		adventurers.gain_xp(member, 1_000_000)
		while adventurers.levels[member] < level:
			adventurers.level_up(member)
	var injured := {"failed": 0, "failed_with_spirit": 0, "succeeded": 0}
	var sent := {"failed": 0, "failed_with_spirit": 0, "succeeded": 0}
	for member: String in members:
		var most := adventurers.max_health(member)
		for roll: int in 40:
			for kind: String in injured:
				var spirit := 25 if kind == "failed_with_spirit" else 0
				var outcome := Outcome.roll(roll * 7_919 + member.hash(), 100 if kind == "succeeded" else 0, Outcome.MOST_DAMAGE[rank], [member], spirit)
				sent[kind] += 1
				if Dispatch.under_a_quarter(maxi(1, most - int(outcome.damage[member])), most):
					injured[kind] += 1
	var rates := {}
	for kind: String in injured:
		rates[kind] = float(injured[kind]) / sent[kind]
	return rates


# Someone leaning Strength and Defence, whose Strength and Defence always grow and nothing else.
static func _add_wren(adventurers: Adventurers) -> void:
	var grows := {}
	for stat: String in Adventurers.STATS:
		grows[stat] = 1.0 if stat in ["strength", "defence"] else 0.0
	adventurers.add("wren", {"name": "Wren", "rank": "F"}, WREN_STATS, grows)


func test_a_title_comes_from_the_two_highest_stats_gear_included() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.title("bram"), "Fighter")
	assert_eq(adventurers.title("ilse"), "Envoy")
	assert_eq(adventurers.title("tobin"), "Scout")
	assert_eq(adventurers.title("maren"), "Mystic")


func test_two_highest_stats_that_are_no_pair_take_the_highest_ones_own_title() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var stats := {}
	for stat: String in Adventurers.STATS:
		stats[stat] = 1
	stats["endurance"] = 9
	stats["luck"] = 7
	adventurers.add("wren", {"name": "Wren", "rank": "F"}, stats, stats)
	assert_eq(adventurers.title("wren"), "Wanderer")
	adventurers.stats["wren"]["luck"] = 10
	assert_eq(adventurers.title("wren"), "Gambler")


func test_a_tie_goes_to_the_stat_shown_first() -> void:
	var even := {}
	for stat: String in Adventurers.STATS:
		even[stat] = 3
	# Strength and Agility come first.
	assert_eq(Adventurers.title_of(even), "Duellist")
	even["presence"] = 5
	# Presence, then Strength: no pair.
	assert_eq(Adventurers.title_of(even), "Herald")
	even["mind"] = 5
	# Mind before Presence: an Envoy.
	assert_eq(Adventurers.title_of(even), "Envoy")


func test_a_pair_title_is_behind_both_stats_of_its_pair() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# Defence 8 and Strength 4: a Fighter.
	_add_wren(adventurers)
	assert_eq(adventurers.title_stats("wren"), PackedStringArray(["defence", "strength"]))


func test_a_title_from_one_stat_is_behind_that_stat_alone_gear_included() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# Chapel plate's Defence +4 lifts Ilse's Defence over her Presence: Mind and Defence are no
	# pair, so she is a Scholar by her Mind.
	adventurers.gear.stow("chapel_plate")
	adventurers.gear.wear("ilse", 0)
	assert_eq(adventurers.title_stats("ilse"), PackedStringArray(["mind"]))


func test_the_stats_behind_a_title_break_ties_toward_the_stat_shown_first() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var stats := {}
	for stat: String in Adventurers.STATS:
		stats[stat] = 3
	# Spirit, Defence and Presence tie: Spirit and Defence come first, a Paladin's pair.
	stats["spirit"] = 5
	stats["defence"] = 5
	stats["presence"] = 5
	adventurers.add("wren", {"name": "Wren", "rank": "F"}, stats, stats)
	assert_eq(adventurers.title_stats("wren"), PackedStringArray(["spirit", "defence"]))


func test_the_stats_behind_a_title_of_any_totals_are_its_pair_or_its_one_stat_ties_going_first() -> void:
	var even := {}
	for stat: String in Adventurers.STATS:
		even[stat] = 3
	even["endurance"] = 9
	even["luck"] = 7
	# Endurance and Luck are no pair: a Wanderer by Endurance alone.
	assert_eq(Adventurers.title_stats_of(even), PackedStringArray(["endurance"]))
	even["perception"] = 9
	# Perception before Endurance, tied: a Ranger's pair.
	assert_eq(Adventurers.title_stats_of(even), PackedStringArray(["perception", "endurance"]))


func test_changing_gear_can_change_a_title_and_back() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# Ilse's Mind 11 and Presence 6 make her an Envoy; Chapel plate's Defence +4 lifts her
	# Defence of 5 over her Presence: Mind and Defence are no pair.
	adventurers.gear.stow("chapel_plate")
	adventurers.gear.wear("ilse", 0)
	assert_eq(adventurers.title("ilse"), "Scholar")
	assert_true(adventurers.gear.take_off("ilse", "armour"))
	assert_eq(adventurers.title("ilse"), "Envoy")


func test_wearing_a_stash_item_instead_of_the_worn_one_shows_what_it_gains_and_loses_and_nothing_it_keeps() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# Tobin's Scout's hood, Perception +1, for a Goblin-bone helm, Defence +2, Strength +1.
	assert_eq(adventurers.wear_change("tobin", "goblin_bone_helm")["stats"], {"strength": 1, "perception": -1, "defence": 2})
	# Bram's Iron cap, Defence +1, for the helm: the Defence point both add is no change.
	assert_eq(adventurers.wear_change("bram", "goblin_bone_helm")["stats"], {"strength": 1, "defence": 1})
	# His Round shield, Defence +1, for a Chapel shield, Defence +2, Spirit +1.
	assert_eq(adventurers.wear_change("bram", "chapel_shield")["stats"], {"spirit": 1, "defence": 1})
	# Nothing is worn or moved by asking.
	assert_eq(adventurers.gear.worn["tobin"]["head"], "scouts_hood")


func test_wearing_a_stash_item_in_an_empty_slot_gains_all_it_adds() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# Maren wears nothing on her head.
	assert_eq(adventurers.wear_change("maren", "goblin_bone_helm")["stats"], {"strength": 1, "defence": 2})
	assert_eq(adventurers.wear_change("maren", "goblin_bone_helm")["health"], 4)


func test_the_maximum_health_a_swap_shows_follows_defence_as_wearing_it_does() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	for item: String in ["chapel_plate", "rangers_vest"]:
		adventurers.gear.stow(item)
	# Bram's Leather vest for Chapel plate: Defence +4.
	var change := adventurers.wear_change("bram", "chapel_plate")
	assert_eq(change["health"], 8)
	var before := adventurers.max_health("bram")
	adventurers.gear.wear("bram", 0)
	assert_eq(adventurers.max_health("bram") - before, change["health"])
	# Chapel plate for a Ranger's vest, Agility +1, Endurance +1: Defence -4.
	change = adventurers.wear_change("bram", "rangers_vest")
	assert_eq(change["health"], -8)
	before = adventurers.max_health("bram")
	adventurers.gear.wear("bram", adventurers.gear.stash.find("rangers_vest"))
	assert_eq(adventurers.max_health("bram") - before, change["health"])
	# Tobin wears no armour: a Ranger's vest moves his Agility and Endurance, not his health.
	assert_eq(adventurers.wear_change("tobin", "rangers_vest"), {"stats": {"agility": 1, "endurance": 1}, "health": 0})


func test_growth_leans_toward_what_worn_items_add_a_twentieth_a_point_up_to_nine_tenths() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	_add_wren(adventurers)
	adventurers.growth["wren"]["mind"] = 0.2
	adventurers.growth["wren"]["agility"] = 0.85
	adventurers.growth["wren"]["perception"] = 0.95
	assert_almost_eq(adventurers.growth_chance("wren", "mind"), 0.2, 0.0001)
	# Moonherb staff: Mind +3.
	adventurers.gear.stow("moonherb_staff")
	adventurers.gear.wear("wren", 0)
	assert_almost_eq(adventurers.growth_chance("wren", "mind"), 0.35, 0.0001)
	# Night cloak: Agility +3, but never past 0.9.
	adventurers.gear.stow("night_cloak")
	adventurers.gear.wear("wren", 0)
	assert_almost_eq(adventurers.growth_chance("wren", "agility"), 0.9, 0.0001)
	# Moss hood: Perception +2. A talent already past 0.9 stays as it is.
	adventurers.gear.stow("moss_hood")
	adventurers.gear.wear("wren", 0)
	assert_almost_eq(adventurers.growth_chance("wren", "perception"), 0.95, 0.0001)
	# What nothing worn adds grows by talent alone.
	assert_almost_eq(adventurers.growth_chance("wren", "spirit"), 0.0, 0.0001)


func test_a_stat_with_no_talent_grows_only_while_an_item_adds_to_it() -> void:
	var bare := Adventurers.new(EVERYONE)
	var armed := Adventurers.new(EVERYONE)
	for adventurers: Adventurers in [bare, armed]:
		_add_wren(adventurers)
		adventurers.gain_xp("wren", 1_000_000)
	# A staff: a scout can grow into a mage.
	armed.gear.stow("moonherb_staff")
	armed.gear.wear("wren", 0)
	for level: int in 20:
		bare.level_up("wren")
		armed.level_up("wren")
	assert_eq(bare.stats["wren"]["mind"], WREN_STATS["mind"])
	assert_gt(armed.stats["wren"]["mind"], WREN_STATS["mind"])
	# Other stats grow as they would anyway: Wren's Strength always grows.
	assert_eq(armed.stats["wren"]["strength"], bare.stats["wren"]["strength"])


func test_a_save_with_the_four_old_stats_loads_them_renamed_and_the_new_ones_filled_by_old_class() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var file := ConfigFile.new()
	adventurers.write(file)
	# The build before nine stats: four stats, growth and history gains in the old names, classes.
	file.set_value("adventurers", "order", PackedStringArray(["bram", "ilse", "tobin", "maren", "recruit_0_9"]))
	file.set_value("adventurers", "roster", {
		"bram": {"name": "Bram", "class": "Swordsman", "rank": "F"},
		"ilse": {"name": "Ilse", "class": "Mage", "rank": "F"},
		"tobin": {"name": "Tobin", "class": "Scout", "rank": "E"},
		"maren": {"name": "Maren", "class": "Healer", "rank": "F"},
		"recruit_0_9": {"name": "Linnea", "class": "Shield bearer", "rank": "F", "face_seed": 42},
	})
	file.set_value("adventurers", "stats", {
		"bram": {"might": 8, "agility": 3, "mind": 2, "grit": 9},
		"ilse": {"might": 2, "agility": 3, "mind": 8, "grit": 5},
		"tobin": {"might": 3, "agility": 9, "mind": 3, "grit": 4},
		"maren": {"might": 2, "agility": 3, "mind": 6, "grit": 5},
		"recruit_0_9": {"might": 4, "agility": 2, "mind": 2, "grit": 7},
	})
	file.set_value("adventurers", "growth", {
		"bram": {"might": 0.6, "agility": 0.3, "mind": 0.15, "grit": 0.55},
		"ilse": {"might": 0.15, "agility": 0.3, "mind": 0.7, "grit": 0.35},
		"tobin": {"might": 0.3, "agility": 0.9, "mind": 0.25, "grit": 0.3},
		"maren": {"might": 0.2, "agility": 0.3, "mind": 0.55, "grit": 0.5},
		"recruit_0_9": {"might": 0.45, "agility": 0.2, "mind": 0.15, "grit": 0.6},
	})
	file.set_value("adventurers", "levels", {"bram": 3, "ilse": 1, "tobin": 2, "maren": 1, "recruit_0_9": 1})
	file.set_value("adventurers", "xp", {"bram": 7, "ilse": 0, "tobin": 5, "maren": 0, "recruit_0_9": 0})
	file.set_value("adventurers", "history", {
		"bram": [{"level": 2, "gains": {"might": 1, "agility": 0, "mind": 0, "grit": 1}}, {"level": 3, "gains": {"might": 1, "agility": 0, "mind": 0, "grit": 1}}],
		"ilse": [], "tobin": [{"level": 2, "gains": {"might": 0, "agility": 2, "mind": 0, "grit": 1}}], "maren": [], "recruit_0_9": [],
	})
	var worn: Dictionary = file.get_value("gear", "worn")
	worn["recruit_0_9"] = {}
	file.set_value("gear", "worn", worn)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Adventurers.load_or_start(SAVE_PATH)
	# Might is Strength, Grit Defence; a starter's new stats are their own starting ones.
	assert_eq(loaded.stats["bram"], {"strength": 8, "agility": 3, "mind": 2, "defence": 9, "perception": 3, "spirit": 3, "endurance": 5, "presence": 3, "luck": 1})
	assert_eq(loaded.stats["tobin"]["strength"], 3)
	assert_eq(loaded.stats["tobin"]["defence"], 4)
	assert_eq(loaded.stats["tobin"]["perception"], 6)
	assert_eq(loaded.stats["maren"]["spirit"], 7)
	# Anyone else's come from their old class: a Shield bearer's high Endurance, a little Luck.
	assert_eq(loaded.stats["recruit_0_9"], {"strength": 4, "agility": 2, "mind": 2, "defence": 7, "perception": 3, "spirit": 3, "endurance": 6, "presence": 3, "luck": 1})
	assert_almost_eq(float(loaded.growth["recruit_0_9"]["strength"]), 0.45, 0.0001)
	assert_almost_eq(float(loaded.growth["recruit_0_9"]["defence"]), 0.6, 0.0001)
	assert_almost_eq(float(loaded.growth["recruit_0_9"]["endurance"]), 0.6, 0.0001)
	assert_almost_eq(float(loaded.growth["bram"]["strength"]), 0.6, 0.0001)
	for adventurer: String in loaded.roster:
		assert_eq(loaded.stats[adventurer].size(), 9, adventurer)
		assert_eq(loaded.growth[adventurer].size(), 9, adventurer)
		# Nothing reads a class any more: the stats say what they are.
		assert_false(loaded.roster[adventurer].has("class"), adventurer)
	assert_eq(loaded.title("recruit_0_9"), "Guard")
	# Nothing else lost.
	assert_eq(loaded.roster["tobin"], {"name": "Tobin", "rank": "E"})
	assert_eq(loaded.roster["recruit_0_9"]["face_seed"], 42)
	assert_eq(loaded.levels["bram"], 3)
	assert_eq(loaded.xp["tobin"], 5)
	# The history reads in the new names.
	assert_eq(loaded.history["bram"][1], {"level": 3, "gains": {"strength": 1, "agility": 0, "mind": 0, "defence": 1}})
	assert_eq(loaded.history["tobin"][0]["gains"]["defence"], 1)
	# And levels up in nine stats from here.
	loaded.gain_xp("tobin", 1_000)
	assert_eq(loaded.level_up("tobin").size(), 9)
