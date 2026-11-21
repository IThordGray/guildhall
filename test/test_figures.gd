extends GutTest

const BRAM_START: Dictionary = {"head": "iron_cap", "clothes": "red_tunic", "armour": "leather_vest", "weapon": "short_sword", "off_hand": "round_shield"}


func test_the_same_seed_and_gear_give_the_same_32_by_44_figure_pixel_for_pixel() -> void:
	for face_seed: int in [0, 1, hash("bram"), 4_294_967_295]:
		var figure := Figures.image(face_seed, BRAM_START)
		assert_eq(figure.get_size(), Vector2i(32, 44))
		assert_eq(figure.get_data(), Figures.image(face_seed, BRAM_START.duplicate()).get_data(), str(face_seed))
	assert_ne(Figures.image(1, BRAM_START).get_data(), Figures.image(2, BRAM_START).get_data())


func test_wearing_a_different_item_in_any_of_the_8_slots_changes_the_figure() -> void:
	for slot: String in Gear.SLOTS:
		# Everything that fits the slot, and the slot left empty, over the rest of Bram's gear.
		var looks := {}
		var choices := [""]
		for item: String in Gear.ITEMS:
			if Gear.ITEMS[item]["slot"] == slot:
				choices.append(item)
		for item: String in choices:
			var worn := BRAM_START.duplicate()
			worn.erase(slot)
			if not item.is_empty():
				worn[slot] = item
			looks[Figures.image(hash("bram"), worn).get_data()] = true
		assert_gte(choices.size(), 2, slot)
		assert_eq(looks.size(), choices.size(), slot)


func test_every_item_draws_and_changes_the_figure_from_its_slot_left_empty() -> void:
	var bare := Figures.image(7, {}).get_data()
	assert_eq(Gear.ITEMS.size(), 33)
	for item: String in Gear.ITEMS:
		var figure := Figures.image(7, {Gear.ITEMS[item]["slot"]: item})
		assert_eq(figure.get_size(), Vector2i(32, 44), item)
		assert_ne(figure.get_data(), bare, item)


func test_a_hood_hides_the_hair() -> void:
	var hair_colours := []
	for hair: Array in Figures.HAIRS:
		hair_colours.append_array([hair[0].to_rgba32(), hair[1].to_rgba32()])
	var shown_bare := 0
	for face_seed: int in 20:
		shown_bare += _count_above_brows(Figures.image(face_seed, {}), hair_colours)
		assert_eq(_count_above_brows(Figures.image(face_seed, {"head": "scouts_hood"}), hair_colours), 0, str(face_seed))
	# Bare-headed, the same people show their hair.
	assert_gt(shown_bare, 100)


func test_making_a_figure_leaves_the_global_generator_untouched() -> void:
	seed(42)
	Figures.image(7, BRAM_START)
	var after := randi()
	seed(42)
	assert_eq(after, randi())


# How many pixels on the head above the brows are one of `colours` (as RGBA32).
func _count_above_brows(figure: Image, colours: Array) -> int:
	var count := 0
	for y: int in 14:
		for x: int in 32:
			if figure.get_pixel(x, y).to_rgba32() in colours:
				count += 1
	return count
