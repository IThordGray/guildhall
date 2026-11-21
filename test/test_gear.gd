extends GutTest

const SAVE_PATH: String = "user://test_gear_save.cfg"
const SLOTS: Array[String] = ["head", "clothes", "armour", "belt", "weapon", "off_hand", "back", "neck"]


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


# The gear of a guild of all four starters, each in their starter gear.
func _starters_gear() -> Gear:
	return Adventurers.new(["bram", "ilse", "tobin", "maren"]).gear


func test_there_are_33_items_each_in_one_of_eight_slots_with_a_quality_its_bonuses_fit_and_an_icon() -> void:
	assert_eq(Gear.ITEMS.size(), 33)
	assert_eq(Gear.SLOTS.keys(), SLOTS)
	var slots_used := {}
	for item: String in Gear.ITEMS:
		var info: Dictionary = Gear.ITEMS[item]
		var bonus: Dictionary = info["bonus"]
		assert_has(SLOTS, info["slot"], item)
		slots_used[info["slot"]] = true
		assert_true(ResourceLoader.exists("res://assets/items/%s.png" % item), item)
		for stat: String in bonus:
			assert_has(Adventurers.STATS, stat, item)
		match info["quality"]:
			"Standard":
				assert_lt(bonus.size(), 2, item)
				for points: int in bonus.values():
					assert_eq(points, 1, item)
			"Fine":
				assert_between(bonus.size(), 1, 2, item)
				for points: int in bonus.values():
					assert_between(points, 1, 2, item)
			"Legendary":
				assert_eq(bonus.size(), 2, item)
				for points: int in bonus.values():
					assert_between(points, 3, 4, item)
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
	assert_eq(gear.bonus("bram", "might"), 4)
	# And back again: the blade returns to the stash.
	gear.wear("bram", 1)
	assert_eq(gear.worn["bram"]["weapon"], "short_sword")
	assert_eq(gear.stash, PackedStringArray(["night_cloak", "goblin_slayer_blade"]))
	assert_eq(gear.bonus("bram", "might"), 0)
	# Into an empty slot, nothing comes back. Any class wears any item.
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
	assert_eq(loaded.bonus("maren", "grit"), 4)
