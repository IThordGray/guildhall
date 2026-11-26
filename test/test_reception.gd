extends GutTest

## The screens are put on a layer above GUT's own output window, with Touch as main.tscn has it.
var _layer: CanvasLayer


func before_each() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_layer.add_child(Touch.new())


func _screen(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	_layer.add_child(screen)
	return screen


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


# The text of every visible label in `node`, in tree order.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for part: Node in node.find_children("*", "Label", true, false):
		if (part as Label).is_visible_in_tree():
			texts.append((part as Label).text)
	return texts


# Each checklist row as its texts, then "✓" when it shows the tick.
func _needs(reception: Reception) -> Array:
	var rows := []
	for row: Node in reception.get_node("Box/Scroll/Columns/Needs/List/Rows").get_children():
		var shown: Array = _texts(row)
		if row.find_child("Tick", true, false) != null:
			shown.append("✓")
		rows.append(shown)
	return rows


# A new guild with `reputation` and `gold` held, at 1_000.
func _guild(reputation: int, gold: int) -> Dispatch:
	var dispatch := Dispatch.new(1_000)
	dispatch.reputation = reputation
	dispatch.gold = Gold.new(gold)
	return dispatch


# `dispatch`, whose new guild has one party, Bram and Tobin's, with parties of one added until it has
# `parties`, and The sealed gate done when `sealed_gate`: with 2 and true, the rest of what rank E
# needs.
func _with(dispatch: Dispatch, parties: int, sealed_gate: bool) -> Dispatch:
	while dispatch.adventurers.parties.parties.size() < parties:
		assert_true(dispatch.adventurers.parties.move("adventurer_%d" % dispatch.adventurers.parties.next_id, Parties.NEW_PARTY, dispatch))
	if sealed_gate:
		dispatch.story_done.append("sealed_gate")
	return dispatch


func test_tapping_the_reception_on_the_hall_asks_to_open_it_and_tapping_a_damaged_room_does_not() -> void:
	var hall_view := _screen("res://screens/hall_view.tscn") as HallView
	hall_view.show_state(Hall.new(1_000), Dispatch.new(1_000), 2, 1_000)
	var opened: Array[int] = [0]
	var restored: Array[String] = []
	hall_view.reception_pressed.connect(func() -> void: opened[0] += 1)
	hall_view.restore_pressed.connect(func(slot: String) -> void: restored.append(slot))
	await wait_process_frames(1)
	_tap(hall_view.room_center("back_left"))
	assert_eq(restored, ["back_left"])
	assert_eq(opened[0], 0)
	_tap(hall_view.room_center("reception"))
	assert_eq(opened[0], 1)
	assert_eq(restored, ["back_left"])


func test_the_reception_shows_the_rank_reputation_checklist_and_what_rank_e_opens_and_back_asks_to_go_back() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := Hall.new(1_000)
	var gold := Gold.new(1_000)
	# Both rooms in use.
	assert_true(hall.restore("side_left", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_001))
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_005))
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_007))
	reception.show_guild(hall, _guild(9, 185), 1_009)
	var texts := _texts(reception)
	for shown: String in ["Reception", "F", "Rank F guild", "Reputation", "9", "TO RANK E", "RANK E OPENS"]:
		assert_has(texts, shown)
	assert_eq(_needs(reception), [["Reputation", "9 / 15"], ["Rooms in use", "2 / 2", "✓"], ["2 parties", "1 / 2"], ["The sealed gate", "not done"], ["150 gold", "✓"]])
	assert_eq(_texts(reception.get_node("Box/Scroll/Columns/Opens/List/Rows")), ["Ground-floor wing: 3 rooms", "Storeroom, Infirmary, Quest hall", "Mostly rank-E quests", "Rank-E recruits", "Walk-ins sooner"])
	var backs: Array[int] = [0]
	reception.back_pressed.connect(func() -> void: backs[0] += 1)
	(reception.get_node("Box/Buttons/Back") as Button).pressed.emit()
	assert_eq(backs[0], 1)


func test_the_reception_rebuilds_when_reputation_or_gold_changes_while_it_is_open() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := Hall.new(1_000)
	var dispatch := _guild(9, 185)
	reception.show_guild(hall, dispatch, 1_000)
	assert_eq(_needs(reception), [["Reputation", "9 / 15"], ["Rooms in use", "0 / 2"], ["2 parties", "1 / 2"], ["The sealed gate", "not done"], ["150 gold", "✓"]])
	dispatch.reputation = 15
	dispatch.gold.amount = 120
	reception.show_guild(hall, dispatch, 1_001)
	assert_has(_texts(reception), "15")
	assert_eq(_needs(reception), [["Reputation", "15 / 15", "✓"], ["Rooms in use", "0 / 2"], ["2 parties", "1 / 2"], ["The sealed gate", "not done"], ["150 gold", "120 / 150"]])


func test_a_guild_at_its_last_rank_shows_only_its_rank_and_back() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := Hall.new(1_000)
	hall.rank = "C"
	reception.show_guild(hall, _guild(30, 500), 1_000)
	assert_has(_texts(reception), "Rank C guild")
	assert_false(reception.get_node("Box/Scroll/Columns/Needs").visible)
	assert_false(reception.get_node("Box/Scroll/Columns/Opens").visible)
	assert_true(reception.get_node("Box/Buttons/Back").visible)


# A new game's hall with its side room a Bunk room and its backroom a Common room, both in use at
# 1_010, so only reputation and gold stand between it and rank E.
func _hall_in_use() -> Hall:
	var hall := Hall.new(1_000)
	var gold := Gold.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	assert_true(hall.restore("back_left", gold, 1_001))
	assert_true(hall.convert_room("side_left", "bunk_room", gold, 1_005))
	assert_true(hall.convert_room("back_left", "common_room", gold, 1_007))
	hall.checkpoint(1_010)
	return hall


# Whether an icon shows over the middle of the room `slot` on `hall_view`.
func _icon_on(hall_view: HallView, slot: String) -> bool:
	for icon: Node in hall_view.find_children("*", "TextureRect", true, false):
		if (icon as TextureRect).is_visible_in_tree() and (icon as TextureRect).get_global_rect().has_point(hall_view.room_center(slot)):
			return true
	return false


func test_a_rank_e_hall_draws_the_front_split_with_the_three_new_rooms_and_a_rank_f_hall_as_before() -> void:
	var hall_view := _screen("res://screens/hall_view.tscn") as HallView
	var summary := hall_view.get_node("Scroll/Box/Top/Header/Summary") as Label
	var hall := _hall_in_use()
	hall_view.show_state(hall, Dispatch.new(1_010), 0, 1_010)
	await wait_process_frames(1)
	assert_eq(summary.text, "Rank F guild · 3 of 3 rooms in use")
	var texts := _texts(hall_view)
	assert_has(texts, "Reception")
	for absent: String in ["North-east room", "East room", "Entrance hall", "Front room"]:
		assert_does_not_have(texts, absent)

	assert_true(hall.rank_up(_with(_guild(15, 150), 2, true), 1_020))
	hall_view.show_state(hall, Dispatch.new(1_020), 0, 1_020)
	await wait_process_frames(1)
	assert_eq(summary.text, "Rank E guild · 3 of 6 rooms in use")
	texts = _texts(hall_view)
	for shown: String in ["North-east room", "East room", "Entrance hall", "Front room"]:
		assert_has(texts, shown)
	# The front strip splits 60:40, the entrance hall on the left under the Reception's left part.
	var entrance := hall_view.room_center("entrance")
	var reception := hall_view.room_center("reception")
	var front := hall_view.room_center("front_right")
	assert_almost_eq(entrance.y, front.y, 1.0)
	assert_almost_eq((front.x - reception.x) / (reception.x - entrance.x), 1.5, 0.02)

	# A rank-F hall from before guild ranks keeps its whole-width entrance hall and its floors.
	var old := Hall.new(1_000)
	old.layout = Hall.OLD_LAYOUT
	hall_view.show_state(old, Dispatch.new(1_000), 0, 1_000)
	await wait_process_frames(1)
	assert_eq(summary.text, "Ground floor · 2 of 6 rooms in use")
	assert_almost_eq(hall_view.room_center("entrance").x, hall_view.room_center("reception").x, 1.0)
	assert_has(_texts(hall_view), "Entrance hall")
	assert_does_not_have(_texts(hall_view), "Front room")


func test_the_reception_shows_its_crest_only_when_the_guild_can_rank_up_and_a_tap_opens_it_either_way() -> void:
	var hall_view := _screen("res://screens/hall_view.tscn") as HallView
	var hall := _hall_in_use()
	var dispatch := _with(_guild(14, 150), 2, true)
	var opened: Array[int] = [0]
	hall_view.reception_pressed.connect(func() -> void: opened[0] += 1)
	hall_view.show_state(hall, dispatch, 0, 1_010)
	await wait_process_frames(1)
	# One reputation short: no crest yet.
	assert_false(_icon_on(hall_view, "reception"))
	_tap(hall_view.room_center("reception"))
	assert_eq(opened[0], 1)
	dispatch.reputation = 15
	hall_view.show_state(hall, dispatch, 0, 1_011)
	await wait_process_frames(1)
	assert_true(_icon_on(hall_view, "reception"))
	_tap(hall_view.room_center("reception"))
	assert_eq(opened[0], 2)
	dispatch.gold.amount = 149
	hall_view.show_state(hall, dispatch, 0, 1_012)
	await wait_process_frames(1)
	assert_false(_icon_on(hall_view, "reception"))


func test_an_upgradable_bunk_room_shows_its_upgrade_icon_and_one_at_tier_3_shows_none() -> void:
	var hall_view := _screen("res://screens/hall_view.tscn") as HallView
	var hall := _hall_in_use()
	var gold := Gold.new(1_000)
	hall_view.show_state(hall, Dispatch.new(1_010), 0, 1_010)
	await wait_process_frames(1)
	assert_true(_icon_on(hall_view, "side_left"))
	# Tier 2 from 1_010 to 1_014, tier 3 from 1_020 to 1_030.
	assert_true(hall.upgrade("side_left", gold, 1_010))
	hall.checkpoint(1_020)
	assert_true(hall.upgrade("side_left", gold, 1_020))
	hall.checkpoint(1_040)
	assert_eq(hall.tier("side_left", 1_040), 3)
	hall_view.show_state(hall, Dispatch.new(1_040), 0, 1_040)
	await wait_process_frames(1)
	assert_false(_icon_on(hall_view, "side_left"))
	assert_has(_texts(hall_view), "Bunk room")


func test_rank_up_shows_on_the_reception_only_once_every_line_is_met() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var rank_up := reception.get_node("Box/Buttons/RankUp") as Button
	var dispatch := _with(_guild(15, 149), 2, true)
	reception.show_guild(_hall_in_use(), dispatch, 1_010)
	assert_false(rank_up.visible)
	assert_true(reception.get_node("Box/Buttons/Back").visible)
	dispatch.gold.amount = 150
	reception.show_guild(_hall_in_use(), dispatch, 1_010)
	assert_true(rank_up.visible)
	assert_eq(rank_up.text, "Rank up · 150g")
	dispatch.reputation = 14
	reception.show_guild(_hall_in_use(), dispatch, 1_010)
	assert_false(rank_up.visible)
	# Rooms not yet in use.
	reception.show_guild(Hall.new(1_000), _guild(15, 150), 1_010)
	assert_false(rank_up.visible)


func test_pressing_rank_up_opens_the_confirm_card_and_confirming_ranks_up_and_rebuilds_the_reception() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var sheet := _screen("res://screens/confirm_sheet.tscn") as ConfirmSheet
	var hall := _hall_in_use()
	var dispatch := _with(_guild(15, 200), 2, true)
	# The same as main.gd does with the signals.
	reception.rank_up_pressed.connect(func() -> void:
		sheet.ask("Rank up to E", "150 gold", "Rank up", hall.rank_up_refusal(dispatch, 1_020)))
	sheet.confirmed.connect(func() -> void:
		hall.rank_up(dispatch, 1_020)
		sheet.close()
		reception.show_guild(hall, dispatch, 1_020))
	reception.show_guild(hall, dispatch, 1_010)
	await wait_process_frames(1)
	_tap((reception.get_node("Box/Buttons/RankUp") as Button).get_global_rect().get_center())
	await wait_process_frames(1)
	assert_true(sheet.visible)
	assert_eq((sheet.get_node("Sheet/Box/Title") as Label).text, "Rank up to E")
	assert_eq((sheet.get_node("Sheet/Box/Note") as Label).text, "150 gold")
	assert_false((sheet.get_node("Sheet/Box/Price") as Control).visible)
	var action := sheet.get_node("Sheet/Box/Buttons/Action") as Button
	assert_eq(action.text, "Rank up")
	assert_eq(hall.rank, "F")
	_tap(action.get_global_rect().get_center())
	await wait_process_frames(1)
	assert_false(sheet.visible)
	assert_eq(hall.rank, "E")
	assert_eq(dispatch.gold.amount, 50)
	assert_has(_texts(reception), "Rank E guild")
	assert_eq((reception.get_node("Box/Scroll/Columns/Needs/Section") as Label).text, "TO RANK D")
	assert_false(reception.get_node("Box/Buttons/RankUp").visible)
	assert_true(reception.get_node("Box/Buttons/Back").visible)


func test_the_reception_shows_2_parties_and_the_sealed_gate_after_rooms_in_use_with_progress_while_short_and_a_tick_once_met() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := _hall_in_use()
	var dispatch := _with(_guild(15, 150), 1, false)
	reception.show_guild(hall, dispatch, 1_010)
	assert_eq(_needs(reception), [["Reputation", "15 / 15", "✓"], ["Rooms in use", "2 / 2", "✓"], ["2 parties", "1 / 2"], ["The sealed gate", "not done"], ["150 gold", "✓"]])
	var rows := reception.get_node("Box/Scroll/Columns/Needs/List/Rows")
	var bars := rows.get_child(2).find_children("*", "ProgressBar", true, false)
	assert_eq(bars.size(), 1)
	assert_eq([(bars[0] as ProgressBar).value, (bars[0] as ProgressBar).max_value], [1.0, 2.0])
	_with(dispatch, 2, true)
	reception.show_guild(hall, dispatch, 1_011)
	assert_eq(_needs(reception), [["Reputation", "15 / 15", "✓"], ["Rooms in use", "2 / 2", "✓"], ["2 parties", "✓"], ["The sealed gate", "✓"], ["150 gold", "✓"]])
	assert_eq(rows.get_child(2).find_children("*", "ProgressBar", true, false).size(), 0)


func test_rank_up_and_the_crest_appear_only_when_2_parties_and_the_sealed_gate_are_met_too() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var rank_up := reception.get_node("Box/Buttons/RankUp") as Button
	var hall_view := _screen("res://screens/hall_view.tscn") as HallView
	var hall := _hall_in_use()
	# Every old line met, one party, The sealed gate done.
	var dispatch := _with(_guild(15, 150), 1, true)
	reception.show_guild(hall, dispatch, 1_010)
	hall_view.show_state(hall, dispatch, 0, 1_010)
	await wait_process_frames(1)
	assert_false(rank_up.visible)
	assert_false(_icon_on(hall_view, "reception"))
	# Two parties, The sealed gate not done.
	dispatch = _with(_guild(15, 150), 2, false)
	reception.show_guild(hall, dispatch, 1_011)
	hall_view.show_state(hall, dispatch, 0, 1_011)
	await wait_process_frames(1)
	assert_false(rank_up.visible)
	assert_false(_icon_on(hall_view, "reception"))
	dispatch.story_done.append("sealed_gate")
	reception.show_guild(hall, dispatch, 1_012)
	hall_view.show_state(hall, dispatch, 0, 1_012)
	await wait_process_frames(1)
	assert_true(rank_up.visible)
	assert_true(_icon_on(hall_view, "reception"))
