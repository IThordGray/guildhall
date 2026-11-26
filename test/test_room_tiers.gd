extends GutTest

const SAVE_PATH: String = "user://test_room_tiers_save.cfg"
## What upgrading each type to tier 2 and to tier 3 costs, in gold.
const UPGRADE_GOLD: Dictionary[String, Array] = {
	"bunk_room": [60, 120],
	"common_room": [90, 220],
	"storeroom": [90, 220],
	"quest_hall": [120, 300],
	"infirmary": [120, 300],
	"tavern": [180, 450],
	"training_room": [180, 450],
	"map_room": [180, 450],
}


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A new game's rank-F hall at 1_000 with its side room a finished `type` from 1_005 and its
## backroom restored and empty, the builder free, paid from `gold`.
func _hall_with_room(type: String, gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_001)
	assert_true(hall.restore("back_left", gold, 1_001))
	hall.checkpoint(1_003)
	assert_true(hall.convert_room("side_left", type, gold, 1_003), type)
	hall.checkpoint(1_005)
	return hall


func test_at_rank_f_every_type_can_be_converted_into_a_free_restored_room() -> void:
	assert_eq(Hall.ROOM_TYPES.size(), 8)
	for type: String in Hall.ROOM_TYPES:
		var gold := Gold.new(1_000)
		var hall := Hall.new(1_000)
		assert_true(hall.restore("side_left", gold, 1_000))
		hall.checkpoint(1_001)
		assert_eq(hall.rank, "F")
		assert_eq(hall.convert_refusal("side_left", type, gold, 1_001), "", type)
		assert_true(hall.convert_room("side_left", type, gold, 1_001), type)
		assert_eq(hall.state("side_left", 1_010), Hall.State.CONVERTED, type)
		assert_eq(hall.room_type("side_left"), type)


func test_a_second_bunk_room_is_refused_below_rank_d_with_nothing_changed_and_allowed_at_d() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("bunk_room", gold)
	assert_eq(gold.amount, 850)
	for rank: String in ["F", "E"]:
		hall.rank = rank
		assert_eq(hall.convert_refusal("back_left", "bunk_room", gold, 1_005), "Guild rank D", rank)
		assert_false(hall.convert_room("back_left", "bunk_room", gold, 1_005), rank)
		assert_eq(gold.amount, 850)
		assert_eq(hall.state("back_left", 1_005), Hall.State.RESTORED)
		assert_eq(hall.building, "")
	hall.rank = "D"
	assert_eq(hall.convert_refusal("back_left", "bunk_room", gold, 1_005), "")
	assert_true(hall.convert_room("back_left", "bunk_room", gold, 1_005))
	hall.checkpoint(1_007)
	assert_eq(hall.rooms_done("bunk_room", 1_007), 2)
	# The Reception's 2 beds and each Bunk room's 2.
	assert_eq(hall.beds(1_007), 6)


func test_any_other_type_a_second_time_is_refused_at_any_rank() -> void:
	for type: String in Hall.ROOM_TYPES:
		if type == "bunk_room":
			continue
		var gold := Gold.new(1_000)
		var hall := _hall_with_room(type, gold)
		hall.rank = "D"
		assert_eq(hall.convert_refusal("back_left", type, gold, 1_005), "Already built", type)
		assert_false(hall.convert_room("back_left", type, gold, 1_005), type)
		assert_eq(hall.state("back_left", 1_005), Hall.State.RESTORED, type)
		# Another type still goes in.
		var other := "bunk_room"
		assert_eq(hall.convert_refusal("back_left", other, gold, 1_005), "", type)


func test_every_type_upgrades_to_tier_2_in_4_seconds_and_tier_3_in_10_at_its_own_price_and_is_at_its_highest_tier_at_3() -> void:
	for type: String in UPGRADE_GOLD:
		var gold := Gold.new(1_000)
		var hall := _hall_with_room(type, gold)
		hall.rank = "D"
		gold.amount = 1_000
		assert_eq(hall.upgrade_refusal("side_left", gold, 1_005), "", type)
		assert_true(hall.upgrade("side_left", gold, 1_005), type)
		assert_eq(gold.amount, 1_000 - UPGRADE_GOLD[type][0], type)
		assert_eq(hall.seconds_left(1_005), 4, type)
		assert_eq(hall.tier("side_left", 1_008), 1, type)
		assert_eq(hall.tier("side_left", 1_009), 2, type)
		hall.checkpoint(1_009)
		assert_true(hall.upgrade("side_left", gold, 1_009), type)
		assert_eq(gold.amount, 1_000 - UPGRADE_GOLD[type][0] - UPGRADE_GOLD[type][1], type)
		assert_eq(hall.seconds_left(1_009), 10, type)
		hall.checkpoint(1_019)
		assert_eq(hall.tier("side_left", 1_019), 3, type)
		assert_eq(hall.upgrade_refusal("side_left", gold, 1_019), "Highest tier", type)
		assert_false(hall.upgrade("side_left", gold, 1_019), type)


func test_tier_2_is_refused_below_rank_e_and_tier_3_below_d_with_nothing_changed_but_a_bunk_room_upgrades_at_any_rank() -> void:
	for type: String in Hall.ROOM_TYPES:
		var gold := Gold.new(1_000)
		var hall := _hall_with_room(type, gold)
		var spent := gold.amount
		if type == "bunk_room":
			assert_true(hall.upgrade("side_left", gold, 1_005))
			hall.checkpoint(1_009)
			assert_true(hall.upgrade("side_left", gold, 1_009))
			hall.checkpoint(1_019)
			assert_eq(hall.rank, "F")
			assert_eq(hall.tier("side_left", 1_019), 3)
			continue
		assert_eq(hall.upgrade_refusal("side_left", gold, 1_005), "Guild rank E", type)
		assert_false(hall.upgrade("side_left", gold, 1_005), type)
		assert_eq([gold.amount, hall.building, hall.tier("side_left", 1_100)], [spent, "", 1], type)
		hall.rank = "E"
		assert_true(hall.upgrade("side_left", gold, 1_005), type)
		hall.checkpoint(1_009)
		spent = gold.amount
		assert_eq(hall.upgrade_refusal("side_left", gold, 1_009), "Guild rank D", type)
		assert_false(hall.upgrade("side_left", gold, 1_009), type)
		assert_eq([gold.amount, hall.building, hall.tier("side_left", 1_100)], [spent, "", 2], type)
		hall.rank = "D"
		assert_true(hall.upgrade("side_left", gold, 1_009), type)


func test_the_time_each_tier_was_reached_survives_save_and_load_and_a_rooms_tier_can_be_asked_at_a_past_moment() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("common_room", gold)
	hall.rank = "D"
	assert_true(hall.upgrade("side_left", gold, 1_005))
	hall.checkpoint(1_009)
	assert_true(hall.upgrade("side_left", gold, 1_009))
	hall.checkpoint(1_012)
	var file := ConfigFile.new()
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	# Tier 2 reached at 1_009, tier 3 under way until 1_019.
	var loaded := Hall.load_or_start(SAVE_PATH, 99_999)
	for at: int in [1_005, 1_008]:
		assert_eq(loaded.tier_at("side_left", at), 1, str(at))
	for at: int in [1_009, 1_018]:
		assert_eq(loaded.tier_at("side_left", at), 2, str(at))
	assert_eq(loaded.tier_at("side_left", 1_019), 3)
	loaded.checkpoint(1_030)
	file = ConfigFile.new()
	loaded.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var reloaded := Hall.load_or_start(SAVE_PATH, 99_999)
	assert_eq(reloaded.building, "")
	assert_eq(reloaded.tier("side_left", 1_030), 3)
	for at: Array in [[1_008, 1], [1_009, 2], [1_018, 2], [1_019, 3], [5_000, 3]]:
		assert_eq(reloaded.tier_at("side_left", at[0]), at[1], str(at[0]))


func test_a_save_from_before_tier_times_has_its_rooms_at_their_saved_tier_from_their_conversion_time() -> void:
	var file := ConfigFile.new()
	file.set_value("hall", "layout", Hall.NEW_LAYOUT)
	file.set_value("hall", "restored", PackedStringArray(["side_left", "back_left"]))
	file.set_value("hall", "converted", {
		"side_left": {"type": "bunk_room", "done_at": 1_100, "tier": 3},
		"back_left": {"type": "common_room", "done_at": 1_200},
	})
	file.set_value("hall", "checked_at", 1_300)
	assert_eq(file.save(SAVE_PATH), OK)

	var hall := Hall.load_or_start(SAVE_PATH, 1_400)
	assert_eq(hall.tier("side_left", 1_400), 3)
	# Every tier it had counts from its conversion, at 1_100, and not before.
	assert_eq(hall.tier_at("side_left", 1_099), 1)
	assert_eq(hall.tier_at("side_left", 1_100), 3)
	assert_eq(hall.tier_at("back_left", 1_200), 1)
	# The Reception's 2 beds and a tier-3 Bunk room's 4.
	assert_eq(hall.beds(1_400), 6)
	assert_eq(hall.upgrade_refusal("side_left", Gold.new(1_000), 1_400), "Highest tier")
	file = ConfigFile.new()
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var reloaded := Hall.load_or_start(SAVE_PATH, 1_400)
	assert_eq(reloaded.tier_at("side_left", 1_100), 3)


func test_a_tavern_being_upgraded_keeps_filling_from_its_conversion_and_collecting_it_never_takes_gold_away() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("tavern", gold)
	hall.rank = "E"
	# Finished at 1_005; a minute later it holds 20, and the upgrade runs from 1_066 to 1_070.
	assert_eq(hall.tavern_gold("side_left", 1_066), 20)
	assert_true(hall.upgrade("side_left", gold, 1_066))
	var before := gold.amount
	for at: Array in [[1_066, 20], [1_067, 20], [1_069, 21]]:
		assert_eq(hall.tavern_gold("side_left", at[0]), at[1], str(at[0]))
	assert_eq(hall.collect("side_left", gold, 1_067), 20)
	assert_eq(gold.amount, before + 20)
	assert_eq(hall.tavern_gold("side_left", 1_069), 0)


func test_the_first_infirmary_and_map_room_keep_their_conversion_time_while_and_after_they_are_upgraded() -> void:
	for type: String in ["infirmary", "map_room"]:
		var gold := Gold.new(1_000)
		var hall := _hall_with_room(type, gold)
		hall.rank = "E"
		assert_eq(hall.first_done_at(type), 1_005, type)
		assert_true(hall.upgrade("side_left", gold, 1_005), type)
		assert_eq(hall.first_done_at(type), 1_005, type)
		hall.checkpoint(1_009)
		assert_eq(hall.tier("side_left", 1_009), 2, type)
		assert_eq(hall.first_done_at(type), 1_005, type)


# --- On the Hall ---


## A hall view on a layer above GUT's own output window, with Touch as main.tscn has it, and a
## confirm card wired to upgrade `hall` paying from `gold` at `now[0]` as main.gd does.
func _hall_screen(hall: Hall, gold: Gold, now: Array) -> Array:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child_autofree(layer)
	layer.add_child(Touch.new())
	var hall_view := (load("res://screens/hall_view.tscn") as PackedScene).instantiate() as HallView
	layer.add_child(hall_view)
	hall_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hall_view.size = Vector2(1000, 700)
	var sheet := (load("res://screens/confirm_sheet.tscn") as PackedScene).instantiate() as ConfirmSheet
	layer.add_child(sheet)
	var upgrading := [""]
	hall_view.upgrade_pressed.connect(func(slot: String) -> void:
		upgrading[0] = slot
		var next := hall.next_upgrade(slot, now[0])
		var info: Dictionary = Hall.ROOM_TYPES[hall.room_type(slot)]
		sheet.offer("Upgrade " + info["name"], next["gold"], next["seconds"], "Upgrade", hall.upgrade_refusal(slot, gold, now[0]), info.get("upgrade_blurb", "")))
	sheet.confirmed.connect(func() -> void:
		hall.upgrade(upgrading[0], gold, now[0])
		sheet.close())
	return [hall_view, sheet]


func test_on_the_hall_a_common_room_shows_no_upgrade_icon_at_rank_f_and_at_rank_e_its_icon_opens_the_confirm_card_that_starts_it() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("common_room", gold)
	var now := [1_005]
	var parts := _hall_screen(hall, gold, now)
	var hall_view: HallView = parts[0]
	var sheet: ConfirmSheet = parts[1]
	var action := sheet.get_node("Sheet/Box/Buttons/Action") as Button
	hall_view.show_state(hall, Dispatch.new(1_005), 0, 1_005)
	await wait_process_frames(1)
	var room: Control = hall_view._rooms["side_left"]
	assert_eq(room.title.text, "Common room")
	assert_false(room.icon.visible)
	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_false(sheet.visible)

	# Short of gold, the icon still shows and the card says why.
	hall.rank = "E"
	gold.amount = 50
	hall_view.show_state(hall, Dispatch.new(1_005), 0, 1_005)
	assert_true(room.icon.visible)
	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_true(sheet.visible)
	assert_eq((sheet.get_node("Sheet/Box/Title") as Label).text, "Upgrade Common room")
	assert_eq((sheet.get_node("Sheet/Box/Price/Cost") as Label).text, "90g")
	assert_false((sheet.get_node("Sheet/Box/Note") as Label).is_visible_in_tree())
	assert_true(action.disabled)
	assert_eq(action.text, "Need 40 more gold")
	sheet.close()

	gold.amount = 820
	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_false(action.disabled)
	assert_eq(action.text, "Upgrade")
	assert_eq(hall.building, "")
	_tap(action.get_global_rect().get_center())
	await wait_process_frames(1)
	assert_false(sheet.visible)
	assert_eq(hall.building, "side_left")
	assert_eq(gold.amount, 820 - 90)


func test_on_the_hall_a_room_being_upgraded_has_no_icon_and_rebuilds_to_offer_the_next_tier_once_the_rank_allows_until_the_highest() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("common_room", gold)
	hall.rank = "E"
	assert_true(hall.upgrade("side_left", gold, 1_005))
	var now := [1_006]
	var parts := _hall_screen(hall, gold, now)
	var hall_view: HallView = parts[0]
	var sheet: ConfirmSheet = parts[1]
	hall_view.show_state(hall, Dispatch.new(1_006), 0, 1_006)
	await wait_process_frames(1)
	var room: Control = hall_view._rooms["side_left"]
	assert_false(room.icon.visible)
	assert_true(room.bar.visible)
	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_false(sheet.visible)

	# Tier 2 at rank E: tier 3 needs D, so no icon.
	now[0] = 1_009
	hall_view.show_state(hall, Dispatch.new(1_009), 0, 1_009)
	assert_false(room.icon.visible)
	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_false(sheet.visible)

	hall.rank = "D"
	hall_view.show_state(hall, Dispatch.new(1_009), 0, 1_009)
	assert_true(room.icon.visible)
	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_eq((sheet.get_node("Sheet/Box/Price/Cost") as Label).text, "220g")
	assert_eq((sheet.get_node("Sheet/Box/Buttons/Action") as Button).text, "Upgrade")
	sheet.close()

	assert_true(hall.upgrade("side_left", gold, 1_009))
	now[0] = 1_019
	hall_view.show_state(hall, Dispatch.new(1_019), 0, 1_019)
	assert_false(room.icon.visible)
	_tap(hall_view.room_center("side_left"))
	await wait_process_frames(1)
	assert_false(sheet.visible)


func test_on_the_hall_at_rank_f_only_the_bunk_room_shows_an_upgrade_icon() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("bunk_room", gold)
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_005))
	hall.checkpoint(1_007)
	var parts := _hall_screen(hall, gold, [1_007])
	var hall_view: HallView = parts[0]
	hall_view.show_state(hall, Dispatch.new(1_007), 0, 1_007)
	assert_eq(hall_view._rooms["side_left"].title.text, "Bunk room")
	assert_true(hall_view._rooms["side_left"].icon.visible)
	assert_eq(hall_view._rooms["back_left"].title.text, "Common room")
	assert_false(hall_view._rooms["back_left"].icon.visible)


func test_on_the_hall_a_tavern_with_gold_offers_collecting_and_once_empty_its_upgrade() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("tavern", gold)
	hall.rank = "E"
	var parts := _hall_screen(hall, gold, [1_065])
	var hall_view: HallView = parts[0]
	hall_view.show_state(hall, Dispatch.new(1_065), 0, 1_065)
	assert_eq(hall_view._rooms["side_left"].kind, "collect")
	assert_eq(hall.collect("side_left", gold, 1_065), 20)
	hall_view.show_state(hall, Dispatch.new(1_065), 0, 1_065)
	assert_eq(hall_view._rooms["side_left"].kind, "upgrade")
	assert_true(hall_view._rooms["side_left"].icon.visible)


func test_the_convert_panel_lists_every_type_at_rank_f_and_offers_a_second_bunk_room_once_rank_d() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_room("bunk_room", gold)
	var panel := (load("res://screens/convert_panel.tscn") as PackedScene).instantiate() as ConvertPanel
	add_child_autofree(panel)
	panel.show_hall(hall, "back_left", gold, 1_005)
	for type: String in Hall.ROOM_TYPES:
		assert_true(panel._choices[type].visible, type)
	assert_false(panel._choices["common_room"].disabled)
	assert_false(panel._reasons["common_room"].visible)
	assert_true(panel._choices["bunk_room"].disabled)
	assert_eq(panel._reasons["bunk_room"].text, "Guild rank D")
	assert_true(panel._reasons["bunk_room"].visible)
	hall.rank = "D"
	panel.show_hall(hall, "back_left", gold, 1_005)
	assert_false(panel._choices["bunk_room"].disabled)
	assert_false(panel._reasons["bunk_room"].visible)


func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click.xformed_by(get_viewport().get_final_transform()))
		Input.flush_buffered_events()
