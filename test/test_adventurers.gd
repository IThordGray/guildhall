extends GutTest

const SAVE_PATH: String = "user://test_adventurers_save.cfg"
const EVERYONE: Array[String] = ["bram", "ilse", "tobin", "maren"]


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func _powers(adventurers: Adventurers) -> Array[int]:
	var powers: Array[int] = []
	for adventurer: String in EVERYONE:
		powers.append(adventurers.power(adventurer))
	return powers


func test_power_is_the_sum_of_the_stats_over_five_rounded_so_the_starters_keep_their_power() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# Bram 18 → 3.6, Ilse 18, Tobin 16 → 3.2, Maren 16.
	assert_eq(_powers(adventurers), [4, 4, 3, 3])
	adventurers.stats["tobin"]["agility"] = 9
	assert_eq(adventurers.power("tobin"), 4)


func test_everyone_starts_in_their_design_gear_which_leaves_their_power_and_health_as_before() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.gear.worn["bram"], {"head": "iron_cap", "clothes": "red_tunic", "armour": "leather_vest", "weapon": "short_sword", "off_hand": "round_shield"})
	assert_eq(adventurers.gear.worn["ilse"], {"head": "pointed_hat", "clothes": "apprentice_robe", "neck": "moonstone_amulet", "weapon": "oak_staff"})
	assert_eq(adventurers.gear.worn["tobin"], {"head": "scouts_hood", "clothes": "leather_jerkin", "weapon": "hunting_bow", "back": "quiver"})
	assert_eq(adventurers.gear.worn["maren"], {"clothes": "healers_robe", "belt": "green_sash", "weapon": "bell_mace"})
	assert_eq(adventurers.gear.stash, PackedStringArray())
	assert_eq(_powers(adventurers), [4, 4, 3, 3])
	assert_eq(adventurers.max_health("bram"), 24)
	assert_eq(adventurers.max_health("tobin"), 16)


func test_a_stat_is_own_plus_gear_and_power_and_health_count_the_total() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gear.stow("chapel_plate")
	adventurers.gear.wear("tobin", 0)
	# Tobin's own 3 / 7 / 3 / 3 with Chapel plate's Might +3, Grit +4: 6 / 7 / 3 / 7 = 23 → 4.6.
	assert_eq(adventurers.stat_total("tobin", "might"), 6)
	assert_eq(adventurers.stat_total("tobin", "grit"), 7)
	assert_eq(adventurers.stat_total("tobin", "agility"), 7)
	assert_eq(adventurers.stats["tobin"], {"might": 3, "agility": 7, "mind": 3, "grit": 3})
	assert_eq(adventurers.power("tobin"), 5)
	assert_eq(adventurers.max_health("tobin"), 24)
	assert_eq(adventurers.power("bram"), 4)
	# Swapping it for a plain vest gives back what their own stats give.
	adventurers.gear.stow("leather_vest")
	adventurers.gear.wear("tobin", 0)
	assert_eq(adventurers.gear.worn["tobin"]["armour"], "leather_vest")
	assert_eq(adventurers.power("tobin"), 3)
	assert_eq(adventurers.max_health("tobin"), 16)


func test_everyone_starts_at_level_one_with_no_xp_and_their_starting_stats() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.stats["bram"], {"might": 6, "agility": 3, "mind": 2, "grit": 7})
	assert_eq(adventurers.stats["ilse"], {"might": 2, "agility": 3, "mind": 8, "grit": 5})
	assert_eq(adventurers.stats["tobin"], {"might": 3, "agility": 7, "mind": 3, "grit": 3})
	assert_eq(adventurers.stats["maren"], {"might": 2, "agility": 3, "mind": 6, "grit": 5})
	for adventurer: String in EVERYONE:
		assert_eq(adventurers.levels[adventurer], 1)
		assert_eq(adventurers.xp[adventurer], 0)
		assert_false(adventurers.level_up_ready(adventurer))


func test_maximum_health_is_ten_plus_two_per_grit_and_a_level_up_that_raises_grit_raises_it() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.max_health("bram"), 24)
	assert_eq(adventurers.max_health("ilse"), 20)
	assert_eq(adventurers.max_health("tobin"), 16)
	assert_eq(adventurers.max_health("maren"), 20)
	adventurers.gain_xp("bram", 1_000_000)
	var grit_gain := 0
	while grit_gain == 0:
		grit_gain = adventurers.level_up("bram")["grit"]
	assert_eq(adventurers.max_health("bram"), 10 + 2 * int(adventurers.stats["bram"]["grit"]) + 3 * (adventurers.levels["bram"] - 1))
	assert_gt(adventurers.max_health("bram"), 24)


func test_a_quest_gives_its_party_one_xp_per_fifteen_seconds_on_success_and_a_quarter_rounded_down_on_failure() -> void:
	assert_eq(Adventurers.quest_xp(600, true), 40)
	assert_eq(Adventurers.quest_xp(600, false), 10)
	assert_eq(Adventurers.quest_xp(180, true), 12)
	assert_eq(Adventurers.quest_xp(180, false), 3)
	assert_eq(Adventurers.quest_xp(90, true), 6)
	assert_eq(Adventurers.quest_xp(90, false), 1)
	assert_eq(Adventurers.quest_xp(60, true), 4)
	assert_eq(Adventurers.quest_xp(60, false), 1)


func test_a_level_up_needs_forty_xp_times_the_level_and_spends_it_keeping_the_rest() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gain_xp("ilse", 39)
	assert_false(adventurers.level_up_ready("ilse"))
	assert_eq(adventurers.level_up("ilse"), {})
	assert_eq(adventurers.levels["ilse"], 1)
	assert_eq(adventurers.xp["ilse"], 39)
	adventurers.gain_xp("ilse", 91)
	assert_true(adventurers.level_up_ready("ilse"))
	assert_false(adventurers.level_up("ilse").is_empty())
	assert_eq(adventurers.levels["ilse"], 2)
	assert_eq(adventurers.xp["ilse"], 90)
	assert_eq(adventurers.xp_needed("ilse"), 80)
	assert_true(adventurers.level_up_ready("ilse"))
	adventurers.level_up("ilse")
	assert_eq(adventurers.levels["ilse"], 3)
	assert_eq(adventurers.xp["ilse"], 10)
	assert_eq(adventurers.xp_needed("ilse"), 120)
	assert_false(adventurers.level_up_ready("ilse"))
	assert_eq(adventurers.levels["bram"], 1)


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
			assert_eq(gains.keys(), ["might", "agility", "mind", "grit"])
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
	for stat: String in ["might", "mind", "grit"]:
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
	adventurers.gain_xp("tobin", 130)
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
	assert_eq(_powers(loaded), _powers(adventurers))
	# The next level-up after loading grows as it would have without the reload.
	loaded.gain_xp("tobin", 120)
	adventurers.gain_xp("tobin", 120)
	assert_eq(loaded.level_up("tobin"), adventurers.level_up("tobin"))


func test_a_save_from_the_previous_build_loads_with_starter_stats_and_nothing_else_lost() -> void:
	var gold := Gold.new(300)
	var dispatch := _guild(1_000)
	assert_true(dispatch.send("goblins", ["bram", "ilse"], 1, 1_000))
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
	assert_eq(_powers(loaded.adventurers), [4, 4, 3, 3])
	for adventurer: String in EVERYONE:
		assert_eq(loaded.adventurers.levels[adventurer], 1)
		assert_eq(loaded.adventurers.xp[adventurer], 0)
		assert_eq(loaded.adventurers.history[adventurer], [])
	assert_eq(Gold.load_or_start(SAVE_PATH).amount, 300)
	assert_eq(loaded.status("bram", 1_100), "On quest: Goblin camp")
	loaded.checkpoint(1_600)
	assert_eq(loaded.debriefs.size(), 1)
	var xp: int = loaded.debriefs[0]["xp"]
	loaded.read_debrief(0, gold)
	assert_eq(loaded.adventurers.xp["bram"], xp)


func test_a_save_from_the_current_build_loads_with_starter_gear_an_empty_stash_and_nothing_else_lost() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.gain_xp("ilse", 50)
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
	# 15 → 3, from their own stats alone; the starters keep their gear.
	assert_eq(adventurers.power("wren"), 3)
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
	assert_eq(loaded.stats["wren"], {"might": 4, "agility": 2, "mind": 1, "grit": 8})
	assert_eq(loaded.gear.worn["wren"], {})
	assert_eq(loaded.gear.worn["tobin"], Gear.STARTER_GEAR["tobin"])
	# Certain growth gives both points and none gives nothing, whatever the roll.
	loaded.gain_xp("wren", 40)
	assert_eq(loaded.level_up("wren"), {"might": 2, "agility": 0, "mind": 0, "grit": 2})
	assert_eq(loaded.stats["wren"], {"might": 6, "agility": 2, "mind": 1, "grit": 10})


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
	assert_eq(loaded.roster["maren"], {"name": "Maren", "class": "Healer", "rank": "F"})
	assert_eq(loaded.roster["tobin"], {"name": "Tobin", "class": "Scout", "rank": "F"})
	assert_eq(loaded.levels["tobin"], 2)
	assert_eq(loaded.stats, adventurers.stats)
	assert_eq(loaded.gear.worn, Gear.STARTER_GEAR)
	# The starters still grow by their own growth.
	loaded.gain_xp("tobin", 80)
	adventurers.gain_xp("tobin", 80)
	assert_eq(loaded.level_up("tobin"), adventurers.level_up("tobin"))


func test_maximum_health_at_level_1_is_as_before_and_each_level_past_it_adds_some_even_without_grit() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	_add_wren(adventurers)
	# Level 1 is unchanged: 10 plus 2 per Grit, gear included.
	assert_eq(adventurers.max_health("bram"), 24)
	assert_eq(adventurers.max_health("tobin"), 16)
	assert_eq(adventurers.max_health("wren"), 26)
	adventurers.growth["wren"]["grit"] = 0.0
	adventurers.gain_xp("wren", 1_000)
	var before := adventurers.max_health("wren")
	adventurers.level_up("wren")
	assert_eq(adventurers.stats["wren"]["grit"], 8)
	assert_gt(adventurers.max_health("wren"), before)
	var one_level := adventurers.max_health("wren") - before
	adventurers.level_up("wren")
	assert_eq(adventurers.max_health("wren") - before, 2 * one_level)


func test_a_failed_quest_of_a_members_promotion_rank_injures_half_to_three_quarters_without_a_healer() -> void:
	for rank: String in ["E", "D"]:
		var rates := _injury_rates(rank)
		assert_between(rates["failed"], 0.5, 0.75, rank)
		# A Healer halves the damage, so far fewer come home injured.
		assert_lt(rates["failed_with_healer"], rates["failed"] / 2.0, rank)
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
	var short := most - (old_most - 1)
	assert_eq(loaded.seconds_to_full("bram", 5_000), short * Dispatch.HEAL_SECONDS)
	assert_eq(loaded.health("bram", 5_000 + short * Dispatch.HEAL_SECONDS - 1), most - 1)
	assert_eq(loaded.health("bram", 5_000 + short * Dispatch.HEAL_SECONDS), most)
	assert_eq(loaded.health("bram", 50_000), most)


# The share of members at `rank`'s promotion level, levelled by their own growth, who come home
# from a quest of that rank injured from full health: failed without a Healer, failed with one,
# and succeeded. Members are the starters and 100 candidates, each sent with 40 fixed seeds.
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
	adventurers.roster["healer"] = {"name": "Hal", "class": "Healer", "rank": rank, "face": ""}
	var injured := {"failed": 0, "failed_with_healer": 0, "succeeded": 0}
	var sent := {"failed": 0, "failed_with_healer": 0, "succeeded": 0}
	for member: String in members:
		var most := adventurers.max_health(member)
		var healer := Dispatch.is_healer(adventurers.roster[member])
		for roll: int in 40:
			for kind: String in injured:
				# A Healer is never without one.
				if kind == "failed" and healer:
					continue
				var party := PackedStringArray([member])
				if kind == "failed_with_healer" and not healer:
					party.append("healer")
				var outcome := Outcome.roll(roll * 7_919 + member.hash(), 100 if kind == "succeeded" else 0, Outcome.MOST_DAMAGE[rank], party, adventurers.roster)
				sent[kind] += 1
				if Dispatch.under_a_quarter(maxi(1, most - int(outcome.damage[member])), most):
					injured[kind] += 1
	var rates := {}
	for kind: String in injured:
		rates[kind] = float(injured[kind]) / sent[kind]
	return rates


# A Shield bearer with no art for their face, whose Might and Grit always grow and nothing else.
static func _add_wren(adventurers: Adventurers) -> void:
	adventurers.add("wren", {"name": "Wren", "class": "Shield bearer", "rank": "F", "face": "wren"}, {"might": 4, "agility": 2, "mind": 1, "grit": 8}, {"might": 1.0, "agility": 0.0, "mind": 0.0, "grit": 1.0})
