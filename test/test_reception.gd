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
	assert_eq(_needs(reception), [["Reputation", "9 / 15"], ["Rooms in use", "2 / 2", "✓"], ["150 gold", "✓"]])
	assert_eq(_texts(reception.get_node("Box/Scroll/Columns/Opens/List/Rows")), ["Ground-floor wing: 3 rooms", "Storeroom, Infirmary, Quest hall", "Mostly rank-E quests", "Rank-E recruits", "Walk-ins sooner"])
	var backs: Array[int] = [0]
	reception.back_pressed.connect(func() -> void: backs[0] += 1)
	(reception.get_node("Box/Back") as Button).pressed.emit()
	assert_eq(backs[0], 1)


func test_the_reception_rebuilds_when_reputation_or_gold_changes_while_it_is_open() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := Hall.new(1_000)
	var dispatch := _guild(9, 185)
	reception.show_guild(hall, dispatch, 1_000)
	assert_eq(_needs(reception), [["Reputation", "9 / 15"], ["Rooms in use", "0 / 2"], ["150 gold", "✓"]])
	dispatch.reputation = 15
	dispatch.gold.amount = 120
	reception.show_guild(hall, dispatch, 1_001)
	assert_has(_texts(reception), "15")
	assert_eq(_needs(reception), [["Reputation", "15 / 15", "✓"], ["Rooms in use", "0 / 2"], ["150 gold", "120 / 150"]])


func test_a_guild_at_its_last_rank_shows_only_its_rank_and_back() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := Hall.new(1_000)
	hall.rank = "E"
	reception.show_guild(hall, _guild(30, 500), 1_000)
	assert_has(_texts(reception), "Rank E guild")
	assert_false(reception.get_node("Box/Scroll/Columns/Needs").visible)
	assert_false(reception.get_node("Box/Scroll/Columns/Opens").visible)
	assert_true(reception.get_node("Box/Back").visible)
