extends GutTest

const SAVE_PATH: String = "user://test_adventurers_save.cfg"
const EVERYONE: Array[String] = ["bram", "ilse", "tobin", "maren"]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func _powers(adventurers: Adventurers) -> Array[int]:
	var powers: Array[int] = []
	for adventurer: String in EVERYONE:
		powers.append(adventurers.power(adventurer))
	return powers


func test_power_is_the_sum_of_the_stats_over_five_rounded_so_the_starters_keep_their_power() -> void:
	var adventurers := Adventurers.new()
	# Bram 18 → 3.6, Ilse 18, Tobin 16 → 3.2, Maren 16.
	assert_eq(_powers(adventurers), [4, 4, 3, 3])
	adventurers.stats["tobin"]["agility"] = 9
	assert_eq(adventurers.power("tobin"), 4)


func test_everyone_starts_in_their_design_gear_which_leaves_their_power_and_health_as_before() -> void:
	var adventurers := Adventurers.new()
	assert_eq(adventurers.gear.worn["bram"], {"head": "iron_cap", "clothes": "red_tunic", "armour": "leather_vest", "weapon": "short_sword", "off_hand": "round_shield"})
	assert_eq(adventurers.gear.worn["ilse"], {"head": "pointed_hat", "clothes": "apprentice_robe", "neck": "moonstone_amulet", "weapon": "oak_staff"})
	assert_eq(adventurers.gear.worn["tobin"], {"head": "scouts_hood", "clothes": "leather_jerkin", "weapon": "hunting_bow", "back": "quiver"})
	assert_eq(adventurers.gear.worn["maren"], {"clothes": "healers_robe", "belt": "green_sash", "weapon": "bell_mace"})
	assert_eq(adventurers.gear.stash, PackedStringArray())
	assert_eq(_powers(adventurers), [4, 4, 3, 3])
	assert_eq(adventurers.max_health("bram"), 24)
	assert_eq(adventurers.max_health("tobin"), 16)


func test_a_stat_is_own_plus_gear_and_power_and_health_count_the_total() -> void:
	var adventurers := Adventurers.new()
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
	var adventurers := Adventurers.new()
	assert_eq(adventurers.stats["bram"], {"might": 6, "agility": 3, "mind": 2, "grit": 7})
	assert_eq(adventurers.stats["ilse"], {"might": 2, "agility": 3, "mind": 8, "grit": 5})
	assert_eq(adventurers.stats["tobin"], {"might": 3, "agility": 7, "mind": 3, "grit": 3})
	assert_eq(adventurers.stats["maren"], {"might": 2, "agility": 3, "mind": 6, "grit": 5})
	for adventurer: String in EVERYONE:
		assert_eq(adventurers.levels[adventurer], 1)
		assert_eq(adventurers.xp[adventurer], 0)
		assert_false(adventurers.level_up_ready(adventurer))


func test_maximum_health_is_ten_plus_two_per_grit_and_a_level_up_that_raises_grit_raises_it() -> void:
	var adventurers := Adventurers.new()
	assert_eq(adventurers.max_health("bram"), 24)
	assert_eq(adventurers.max_health("ilse"), 20)
	assert_eq(adventurers.max_health("tobin"), 16)
	assert_eq(adventurers.max_health("maren"), 20)
	adventurers.gain_xp("bram", 1_000_000)
	var grit_gain := 0
	while grit_gain == 0:
		grit_gain = adventurers.level_up("bram")["grit"]
	assert_eq(adventurers.max_health("bram"), 10 + 2 * int(adventurers.stats["bram"]["grit"]))
	assert_gt(adventurers.max_health("bram"), 24)


func test_a_quest_gives_one_xp_per_fifteen_seconds_on_success_and_half_that_on_failure() -> void:
	assert_eq(Adventurers.quest_xp(600, true), 40)
	assert_eq(Adventurers.quest_xp(600, false), 20)
	assert_eq(Adventurers.quest_xp(180, true), 12)
	assert_eq(Adventurers.quest_xp(180, false), 6)
	assert_eq(Adventurers.quest_xp(60, true), 4)
	assert_eq(Adventurers.quest_xp(60, false), 2)


func test_a_level_up_needs_forty_xp_times_the_level_and_spends_it_keeping_the_rest() -> void:
	var adventurers := Adventurers.new()
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
	var first := Adventurers.new()
	var second := Adventurers.new()
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
	var adventurers := Adventurers.new()
	adventurers.gain_xp("tobin", 1_000_000)
	var start: Dictionary = adventurers.stats["tobin"].duplicate()
	for level: int in 20:
		adventurers.level_up("tobin")
	var agility_gained: int = adventurers.stats["tobin"]["agility"] - start["agility"]
	for stat: String in ["might", "mind", "grit"]:
		assert_gt(agility_gained, adventurers.stats["tobin"][stat] - start[stat], stat)


func test_the_history_records_each_level_up_with_what_it_gave() -> void:
	var adventurers := Adventurers.new()
	assert_eq(adventurers.history["maren"], [])
	adventurers.gain_xp("maren", 120)
	var to_two := adventurers.level_up("maren")
	var to_three := adventurers.level_up("maren")
	assert_eq(adventurers.history["maren"], [{"level": 2, "gains": to_two}, {"level": 3, "gains": to_three}])
	assert_eq(adventurers.history["bram"], [])


func test_stats_levels_xp_and_history_survive_save_and_load() -> void:
	var adventurers := Adventurers.new()
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
	var dispatch := Dispatch.new(1_000)
	assert_true(dispatch.send("goblins", ["bram", "ilse"], 1, gold, 1_000))
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
	loaded.checkpoint(1_600, gold)
	assert_eq(loaded.debriefs.size(), 1)
	assert_eq(loaded.adventurers.xp["bram"], loaded.debriefs[0]["xp"])


func test_a_save_from_the_current_build_loads_with_starter_gear_an_empty_stash_and_nothing_else_lost() -> void:
	var adventurers := Adventurers.new()
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
	var adventurers := Adventurers.new()
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
	var adventurers := Adventurers.new()
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
	var adventurers := Adventurers.new()
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
	assert_eq(loaded.roster["maren"], {"name": "Maren", "class": "Healer", "rank": "F", "face": "maren"})
	assert_eq(loaded.roster["tobin"], {"name": "Tobin", "class": "Scout", "rank": "F", "face": "tobin"})
	assert_eq(loaded.levels["tobin"], 2)
	assert_eq(loaded.stats, adventurers.stats)
	assert_eq(loaded.gear.worn, Gear.STARTER_GEAR)
	# The starters still grow by their own growth.
	loaded.gain_xp("tobin", 80)
	adventurers.gain_xp("tobin", 80)
	assert_eq(loaded.level_up("tobin"), adventurers.level_up("tobin"))


# A Shield bearer with no art for their face, whose Might and Grit always grow and nothing else.
static func _add_wren(adventurers: Adventurers) -> void:
	adventurers.add("wren", {"name": "Wren", "class": "Shield bearer", "rank": "F", "face": "wren"}, {"might": 4, "agility": 2, "mind": 1, "grit": 8}, {"might": 1.0, "agility": 0.0, "mind": 0.0, "grit": 1.0})
