extends GutTest

const SAVE_PATH: String = "user://test_gear_save.cfg"
const SLOTS: Array[String] = ["head", "clothes", "armour", "belt", "weapon", "off_hand", "back", "neck"]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


# The gear of a guild of all four starters, each in their starter gear.
func _starters_gear() -> Gear:
	return Adventurers.new(["bram", "ilse", "tobin", "maren"]).gear


func test_there_are_33_items_each_in_one_of_eight_slots_adding_stats_in_its_quality_band_with_an_icon() -> void:
	assert_eq(Gear.ITEMS.size(), 33)
	assert_eq(Gear.SLOTS.keys(), SLOTS)
	var slots_used := {}
	for item: String in Gear.ITEMS:
		var info: Dictionary = Gear.ITEMS[item]
		var bonus: Dictionary = info["bonus"]
		assert_has(SLOTS, info["slot"], item)
		slots_used[info["slot"]] = true
		assert_true(ResourceLoader.exists("res://assets/items/%s.png" % item), item)
		var total := 0
		for stat: String in bonus:
			assert_has(Adventurers.STATS, stat, item)
			assert_gt(int(bonus[stat]), 0, item)
			total += int(bonus[stat])
		# Every item adds something: Standard +1–2 in all, Fine +2–4, Legendary +4–7.
		match info["quality"]:
			"Standard":
				assert_between(total, 1, 2, item)
			"Fine":
				assert_between(total, 2, 4, item)
			"Legendary":
				assert_between(total, 4, 7, item)
			_:
				fail_test("%s has no known quality" % item)
	assert_eq(slots_used.size(), 8)


func test_goblin_chapel_moonweave_and_night_items_are_fine_or_legendary_and_plain_ones_standard() -> void:
	for item: String in ["goblin_bone_helm", "goblin_shield", "goblin_slayer_blade", "chapel_plate", "chapel_shield", "moonweave_robe", "night_cloak"]:
		assert_ne(Gear.ITEMS[item]["quality"], "Standard", item)
	for item: String in ["iron_cap", "red_tunic", "leather_vest", "short_sword", "belt", "sash"]:
		assert_eq(Gear.ITEMS[item]["quality"], "Standard", item)


func test_a_quarter_of_rank_f_returns_and_half_of_rank_e_ones_bring_an_item() -> void:
	var brought := {"F": 0, "E": 0}
	for roll_seed: int in 4_000:
		for rank: String in brought:
			if not Gear.loot(roll_seed, rank).is_empty():
				brought[rank] += 1
	assert_between(brought["F"], 900, 1_100)
	assert_between(brought["E"], 1_900, 2_100)


func test_rank_d_returns_bring_an_item_more_often_than_rank_e_ones_but_not_always() -> void:
	var brought := {"E": 0, "D": 0}
	for roll_seed: int in 4_000:
		for rank: String in brought:
			var item := Gear.loot(roll_seed, rank)
			if not item.is_empty():
				assert_has(Gear.ITEMS, item)
				brought[rank] += 1
	assert_gt(brought["D"], brought["E"])
	assert_lt(brought["D"], 4_000)


func test_loot_is_standard_80_fine_18_and_legendary_2_percent_of_the_time_drawn_from_that_quality() -> void:
	var by_quality := {"Standard": 0, "Fine": 0, "Legendary": 0}
	var items_seen := {}
	for roll_seed: int in 40_000:
		var item := Gear.loot(roll_seed, "E")
		if item.is_empty():
			continue
		by_quality[Gear.ITEMS[item]["quality"]] += 1
		items_seen[item] = true
	var total: int = by_quality["Standard"] + by_quality["Fine"] + by_quality["Legendary"]
	assert_between(by_quality["Standard"] * 100.0 / total, 78.0, 82.0)
	assert_between(by_quality["Fine"] * 100.0 / total, 16.0, 20.0)
	assert_between(by_quality["Legendary"] * 100.0 / total, 1.5, 2.5)
	# Every item can drop, Legendary ones included.
	assert_eq(items_seen.size(), 33)


# `luck`'s quality odds as [Standard, Fine, Legendary], in whole percent.
func _shares(luck: int) -> Array[int]:
	var shares := Gear.quality_percent(luck)
	return [shares["Standard"], shares["Fine"], shares["Legendary"]]


func test_luck_moves_a_point_of_quality_odds_from_standard_to_fine_a_point_and_one_to_legendary_every_5() -> void:
	assert_eq(_shares(0), [80, 18, 2])
	assert_eq(_shares(4), [76, 22, 2])
	assert_eq(_shares(5), [74, 23, 3])
	assert_eq(_shares(10), [68, 28, 4])
	# Until Standard has none left.
	assert_eq(_shares(90), [0, 80, 20])


func test_luck_adds_a_point_of_loot_chance_a_point_up_to_25_and_better_loot() -> void:
	var brought := {0: 0, 10: 0, 25: 0, 60: 0}
	var rarer := {0: 0, 20: 0}
	for roll_seed: int in 4_000:
		for luck: int in brought:
			if not Gear.loot(roll_seed, "F", luck).is_empty():
				brought[luck] += 1
		for luck: int in rarer:
			var item := Gear.loot(roll_seed, "E", luck)
			if not item.is_empty() and Gear.ITEMS[item]["quality"] != "Standard":
				rarer[luck] += 1
		# Luck never loses an item that would have come without it.
		if not Gear.loot(roll_seed, "F").is_empty():
			assert_false(Gear.loot(roll_seed, "F", 10).is_empty())
	# 25%, 35% and 50% of 4,000 within 2.5 points; past 25 Luck, no more.
	assert_between(brought[0], 900, 1_100)
	assert_between(brought[10], 1_300, 1_500)
	assert_between(brought[25], 1_900, 2_100)
	assert_eq(brought[60], brought[25])
	# Fine or Legendary: 20% of the loot without Luck, 44% with 20 (more of it, too).
	assert_gt(rarer[20], rarer[0] * 2)


func test_the_same_seed_always_brings_the_same_loot() -> void:
	var first: Array[String] = []
	var second: Array[String] = []
	for roll_seed: int in 200:
		first.append(Gear.loot(roll_seed, "E"))
		second.append(Gear.loot(roll_seed, "E"))
	assert_eq(first, second)
	assert_has(first, "")
	assert_gt(first.filter(func(item: String) -> bool: return not item.is_empty()).size(), 50)


func test_a_new_games_stash_holds_six_and_an_item_brought_to_a_full_stash_is_lost() -> void:
	var gear := Gear.new()
	for i: int in 5:
		assert_true(gear.stow("belt"))
	assert_true(gear.stow("night_cloak"))
	assert_eq(gear.stash.size(), 6)
	assert_false(gear.stow("chapel_plate"))
	assert_eq(gear.stash.size(), 6)
	assert_does_not_have(gear.stash, "chapel_plate")
	assert_has(gear.stash, "night_cloak")


func test_wearing_a_stash_item_swaps_it_in_and_puts_the_replaced_one_in_the_stash() -> void:
	var gear := _starters_gear()
	gear.stow("night_cloak")
	gear.stow("goblin_slayer_blade")
	gear.wear("bram", 1)
	assert_eq(gear.worn["bram"]["weapon"], "goblin_slayer_blade")
	assert_eq(gear.stash, PackedStringArray(["night_cloak", "short_sword"]))
	assert_eq(gear.bonus("bram", "strength"), 4)
	# And back again: the blade returns to the stash.
	gear.wear("bram", 1)
	assert_eq(gear.worn["bram"]["weapon"], "short_sword")
	assert_eq(gear.stash, PackedStringArray(["night_cloak", "goblin_slayer_blade"]))
	assert_eq(gear.bonus("bram", "strength"), 1)
	# Into an empty slot, nothing comes back. Anyone wears any item.
	assert_false(gear.worn["bram"].has("back"))
	gear.wear("bram", 0)
	assert_eq(gear.worn["bram"]["back"], "night_cloak")
	assert_eq(gear.stash, PackedStringArray(["goblin_slayer_blade"]))
	assert_eq(gear.worn["ilse"], Gear.STARTER_GEAR["ilse"])


func test_the_items_that_fit_a_slot_are_found_where_they_are_in_the_stash() -> void:
	var gear := _starters_gear()
	for item: String in ["night_cloak", "sash", "chapel_plate", "forest_cloak"]:
		gear.stow(item)
	assert_eq(gear.fitting("back"), PackedInt32Array([0, 3]))
	assert_eq(gear.fitting("belt"), PackedInt32Array([1]))
	# Nothing in the stash goes on the neck.
	assert_eq(gear.fitting("neck"), PackedInt32Array())
	# Bram wore nothing on his back, so wearing the first cloak brings nothing back.
	gear.wear("bram", 0)
	assert_eq(gear.fitting("back"), PackedInt32Array([2]))


func test_taking_off_puts_the_item_in_the_stash_and_empties_the_slot_and_wearing_it_puts_it_back() -> void:
	var gear := _starters_gear()
	gear.stow("sash")
	assert_true(gear.take_off("bram", "weapon"))
	assert_false(gear.worn["bram"].has("weapon"))
	assert_eq(gear.stash, PackedStringArray(["sash", "short_sword"]))
	assert_eq(gear.worn["bram"]["head"], "iron_cap")
	gear.wear("bram", 1)
	assert_eq(gear.worn["bram"]["weapon"], "short_sword")
	assert_eq(gear.stash, PackedStringArray(["sash"]))


func test_taking_off_is_refused_with_nothing_changed_when_the_stash_is_full_or_the_slot_empty() -> void:
	var gear := _starters_gear()
	assert_false(gear.take_off("bram", "back"))
	assert_eq(gear.stash, PackedStringArray())
	for i: int in gear.stash_cap:
		gear.stow("belt")
	assert_false(gear.take_off("bram", "weapon"))
	assert_eq(gear.worn["bram"]["weapon"], "short_sword")
	assert_eq(gear.stash.size(), 6)
	assert_does_not_have(gear.stash, "short_sword")


func test_worn_gear_and_the_stash_survive_save_and_load() -> void:
	var gear := _starters_gear()
	gear.stow("chapel_plate")
	gear.stow("sash")
	gear.wear("maren", 0)
	var file := ConfigFile.new()
	gear.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Gear.load_or_start(SAVE_PATH)
	assert_eq(loaded.worn, gear.worn)
	assert_eq(loaded.worn["maren"]["armour"], "chapel_plate")
	assert_eq(loaded.stash, PackedStringArray(["sash"]))
	assert_eq(loaded.bonus("maren", "defence"), 4)


func test_the_same_seed_and_luck_always_bring_the_same_loot() -> void:
	var differs := false
	for roll_seed: int in 400:
		assert_eq(Gear.loot(roll_seed, "E", 20), Gear.loot(roll_seed, "E", 20))
		differs = differs or Gear.loot(roll_seed, "E", 20) != Gear.loot(roll_seed, "E")
	# Luck does change what comes.
	assert_true(differs)


func test_a_stash_item_sells_for_3_15_or_60_gold_by_quality_and_leaves_the_stash_for_good() -> void:
	assert_eq(Gear.SELL_GOLD, {"Standard": 3, "Fine": 15, "Legendary": 60})
	var gear := Gear.new()
	for item: String in ["belt", "night_cloak", "moonweave_robe", "belt"]:
		gear.stow(item)
	var gold := Gold.new(10)
	assert_eq(gear.sell_refusal("night_cloak"), "")
	assert_true(gear.sell("night_cloak", gold))
	assert_eq(gold.amount, 25)
	assert_eq(gear.stash, PackedStringArray(["belt", "moonweave_robe", "belt"]))
	assert_true(gear.sell("moonweave_robe", gold))
	assert_eq(gold.amount, 85)
	# One of two the same sells one.
	assert_true(gear.sell("belt", gold))
	assert_eq(gold.amount, 88)
	assert_eq(gear.stash, PackedStringArray(["belt"]))
	assert_true(gear.sell("belt", gold))
	assert_eq(gold.amount, 91)
	assert_eq(gear.stash, PackedStringArray())


func test_a_worn_item_cannot_be_sold_until_taken_off() -> void:
	var gear := _starters_gear()
	var gold := Gold.new(10)
	assert_eq(gear.sell_refusal("short_sword"), "Not in the stash")
	assert_false(gear.sell("short_sword", gold))
	assert_eq(gold.amount, 10)
	assert_eq(gear.worn["bram"]["weapon"], "short_sword")
	assert_true(gear.take_off("bram", "weapon"))
	assert_true(gear.sell("short_sword", gold))
	assert_eq(gold.amount, 13)
	assert_eq(gear.stash, PackedStringArray())
