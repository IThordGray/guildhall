extends GutTest


func test_the_same_seed_always_gives_the_same_face_pixel_for_pixel() -> void:
	for face_seed: int in [0, 1, hash("bram"), 4_294_967_295]:
		assert_eq(Faces.image(face_seed).get_data(), Faces.image(face_seed).get_data(), str(face_seed))
	assert_ne(Faces.image(1).get_data(), Faces.image(2).get_data())


func test_200_different_seeds_give_at_least_190_different_faces() -> void:
	var seen := {}
	for i: int in 200:
		seen[Faces.image(hash([i % 4, 1_000_000 + i * 1_800])).get_data()] = true
	assert_gte(seen.size(), 190)


func test_200_different_seeds_in_the_same_gear_give_at_least_190_different_faces() -> void:
	# Tobin's start: a hood hides the hair, the hardest case.
	var worn := {"head": "scouts_hood", "clothes": "leather_jerkin", "weapon": "hunting_bow", "back": "quiver"}
	var seen := {}
	for i: int in 200:
		seen[Faces.image(hash([i % 4, 1_000_000 + i * 1_800]), worn).get_data()] = true
	assert_gte(seen.size(), 190)


func test_a_face_is_the_head_of_that_persons_figure_so_skin_and_hair_match() -> void:
	for face_seed: int in [3, hash("bram"), hash("ilse")]:
		for worn: Dictionary in [{}, {"head": "iron_cap", "clothes": "red_tunic"}]:
			var face := Faces.image(face_seed, worn)
			var figure := Figures.image(face_seed, worn)
			var matched := 0
			for y: int in 18:
				for x: int in 20:
					if face.get_pixel(x, y) == figure.get_pixel(x + 5, y + 5):
						matched += 1
			assert_eq(matched, 20 * 18, str(face_seed))
	# A face shows their gear on the head.
	assert_ne(Faces.image(3).get_data(), Faces.image(3, {"head": "iron_cap"}).get_data())


func test_a_face_is_20_by_18_pixels_outlined_on_a_clear_background() -> void:
	var face := Faces.image(7)
	assert_eq(face.get_size(), Vector2i(20, 18))
	assert_eq(face.get_pixel(0, 0).a, 0.0)
	var outline := 0
	for y: int in 18:
		for x: int in 20:
			if face.get_pixel(x, y).to_rgba32() == Color("#1a1423").to_rgba32():
				outline += 1
	assert_gt(outline, 20)


func test_making_a_face_leaves_the_global_generator_untouched() -> void:
	seed(42)
	Faces.image(7)
	var after := randi()
	seed(42)
	assert_eq(after, randi())


func test_a_starter_or_anyone_without_a_face_seed_has_their_ids_face_and_a_recruit_their_own() -> void:
	assert_eq(Faces.seed_of("bram", Adventurers.new().roster["bram"]), hash("bram"))
	assert_eq(Faces.seed_of("recruit_0_5", {"name": "Wren", "rank": "F", "face_seed": 99}), 99)
	assert_ne(Faces.seed_of("bram", {}), Faces.seed_of("ilse", {}))
