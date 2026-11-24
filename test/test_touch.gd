extends GutTest

## How tall the screens are made, so each has more to show than fits and scrolls.
const SCREEN_SIZE: Vector2 = Vector2(1000, 700)

var _layer: CanvasLayer
var _fired: int = 0


func before_each() -> void:
	_fired = 0
	# A phone reports a touchscreen, which is what lets a ScrollContainer follow a finger; headless
	# reports one only while touch is emulated from the mouse.
	Input.emulate_touch_from_mouse = true
	# On a layer above GUT's own output window, which would otherwise take some of the presses.
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_layer.add_child(Touch.new())


func after_each() -> void:
	Input.emulate_touch_from_mouse = false


func _fire() -> void:
	_fired += 1


# `path` instanced on the layer at SCREEN_SIZE.
func _screen(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = SCREEN_SIZE
	return screen


# Through Input, as the platform sends it, so touch is also emulated as mouse events. The platform
# sends window pixels, so the viewport positions are turned into those first.
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()


# A finger pressed at `from`, moved to `to` over a few frames, and lifted there.
func _touch_drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = from
	_send(press)
	var steps := 4
	for i: int in steps:
		var drag := InputEventScreenDrag.new()
		drag.position = from + (to - from) * (i + 1) / steps
		drag.relative = (to - from) / steps
		_send(drag)
		await wait_process_frames(1)
	var release := InputEventScreenTouch.new()
	release.position = to
	_send(release)
	await wait_process_frames(1)


# The tap's slop in this viewport, in its pixels.
func _slop() -> float:
	return Touch.tap_slop_px(get_viewport().get_visible_rect().size)


func _middle(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


# Drags `button` up from its middle in `scroll`, past the slop but not off the button, so the finger
# lifts on it: the content scrolls and the button does not fire. Back at the top, a tap on it does.
func _assert_drag_scrolls_and_does_not_fire(scroll: ScrollContainer, button: BaseButton) -> void:
	assert_false(button.disabled)
	assert_eq(scroll.scroll_vertical, 0)
	var from := _middle(button)
	var to := from + Vector2(0, -(_slop() + 10))
	assert_true(button.get_global_rect().has_point(to))
	await _touch_drag(from, to)
	assert_gt(scroll.scroll_vertical, 0)
	assert_eq(_fired, 0)
	# Once the scroll's momentum has run out.
	await wait_process_frames(60)
	scroll.scroll_vertical = 0
	await wait_process_frames(1)
	await _touch_drag(_middle(button), _middle(button))
	assert_eq(_fired, 1)


# The roster of a full guild, every bed taken: compact rows, so it takes that many to scroll.
func _roster() -> Roster:
	var roster := _screen("res://screens/roster.tscn") as Roster
	var dispatch := Dispatch.new(1_000)
	for i: int in Hall.MAX_ROSTER - dispatch.adventurers.roster.size():
		dispatch.adventurers.add("recruit_%d" % i, {"name": "Recruit %d" % i, "rank": "F"}, Adventurers.STARTING_STATS["bram"], Adventurers.GROWTH["bram"])
	roster.show_dispatch(dispatch, 1_000)
	roster.adventurer_pressed.connect(func(_adventurer: String) -> void: _fire())
	return roster


func _roster_row(roster: Roster, index: int) -> Button:
	return roster.get_node("Scroll/Box/List").get_child(index) as Button


func test_a_drag_starting_on_an_adventurer_in_the_roster_scrolls_it_and_does_not_open_them() -> void:
	var roster := _roster()
	await wait_process_frames(1)
	await _assert_drag_scrolls_and_does_not_fire(roster.get_node("Scroll"), _roster_row(roster, 0))


func test_a_drag_starting_on_a_damaged_hall_room_scrolls_the_hall_and_does_not_ask_to_restore_it() -> void:
	var hall_view := _screen("res://screens/hall_view.tscn") as HallView
	var hall := Hall.new(1_000)
	assert_eq(hall.state("back_left", 1_000), Hall.State.DAMAGED)
	hall_view.show_state(hall, Dispatch.new(1_000), 3, 1_000)
	hall_view.restore_pressed.connect(func(slot: String) -> void:
		assert_eq(slot, "back_left")
		_fire())
	await wait_process_frames(1)
	# The whole room is one target: the button over all of it.
	var room := hall_view.room_center("back_left")
	var cover := hall_view.get_node("Scroll/Box/Columns/Left/Plan").find_children("*", "Button", true, false).filter(
			func(button: Button) -> bool: return button.is_visible_in_tree() and button.get_global_rect().has_point(room))[0] as Button
	await _assert_drag_scrolls_and_does_not_fire(hall_view.get_node("Scroll"), cover)


# The sheet on the layer at SCREEN_SIZE, offering an action that is refused while `refusal` says why.
func _sheet(refusal: String) -> ConfirmSheet:
	var sheet := _screen("res://screens/confirm_sheet.tscn") as ConfirmSheet
	sheet.confirmed.connect(_fire)
	sheet.offer("Restore Backroom", 60, 30, "Restore", refusal)
	return sheet


func _action(sheet: ConfirmSheet) -> Button:
	return sheet.get_node("Sheet/Box/Buttons/Action") as Button


func test_the_sheet_closes_on_a_tap_outside_it_on_cancel_or_on_back_and_not_on_a_drag() -> void:
	var sheet := _sheet("")
	await wait_process_frames(1)
	var outside := Vector2(SCREEN_SIZE.x / 2, 40)
	assert_false(sheet.get_node("Sheet").get_global_rect().has_point(outside))
	await _touch_drag(outside, outside + Vector2(0, _slop() + 20))
	assert_true(sheet.visible)
	await _touch_drag(outside, outside)
	assert_false(sheet.visible)
	sheet.offer("Restore Backroom", 60, 30, "Restore", "")
	await wait_process_frames(1)
	var cancel := _middle(sheet.get_node("Sheet/Box/Buttons/Cancel"))
	await _touch_drag(cancel, cancel)
	assert_false(sheet.visible)
	sheet.offer("Restore Backroom", 60, 30, "Restore", "")
	assert_false(get_tree().quit_on_go_back)
	sheet.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(sheet.visible)
	# Back closes only the sheet; once it is closed, Back leaves the app again.
	assert_false(get_tree().quit_on_go_back)
	await wait_process_frames(1)
	assert_true(get_tree().quit_on_go_back)
	assert_eq(_fired, 0)


func test_a_refused_action_reads_its_reason_and_cannot_be_confirmed() -> void:
	var sheet := _sheet("Need 20 more gold")
	await wait_process_frames(1)
	assert_eq(_action(sheet).text, "Need 20 more gold")
	await _touch_drag(_middle(_action(sheet)), _middle(_action(sheet)))
	assert_eq(_fired, 0)
	assert_true(sheet.visible)
	# With the gold, the same tap confirms it.
	sheet.offer("Restore Backroom", 60, 30, "Restore", "")
	assert_eq(_action(sheet).text, "Restore")
	await wait_process_frames(1)
	await _touch_drag(_middle(_action(sheet)), _middle(_action(sheet)))
	assert_eq(_fired, 1)


func test_the_swap_card_says_what_leaves_with_them_costs_nothing_and_swaps_only_on_a_tap_while_allowed() -> void:
	var sheet := _screen("res://screens/confirm_sheet.tscn") as ConfirmSheet
	sheet.confirmed.connect(_fire)
	sheet.ask("Swap Bram for Aldric", "2 items leave with them", "Swap", "Waiting on loot")
	await wait_process_frames(1)
	assert_true((sheet.get_node("Sheet/Box/Note") as Label).is_visible_in_tree())
	assert_false((sheet.get_node("Sheet/Box/Price") as Control).visible)
	assert_eq(_action(sheet).text, "Waiting on loot")
	await _touch_drag(_middle(_action(sheet)), _middle(_action(sheet)))
	assert_eq(_fired, 0)
	sheet.ask("Swap Bram for Aldric", "", "Swap", "")
	await wait_process_frames(1)
	assert_false((sheet.get_node("Sheet/Box/Note") as Label).visible)
	assert_eq(_action(sheet).text, "Swap")
	# A drag off the button swaps nobody; a tap does.
	await _touch_drag(_middle(_action(sheet)), _middle(_action(sheet)) + Vector2(0, _slop() + 20))
	assert_eq(_fired, 0)
	await _touch_drag(_middle(_action(sheet)), _middle(_action(sheet)))
	assert_eq(_fired, 1)
	# A spending action shows its price again.
	sheet.offer("Restore Backroom", 60, 30, "Restore", "")
	assert_true((sheet.get_node("Sheet/Box/Price") as Control).visible)
	assert_false((sheet.get_node("Sheet/Box/Note") as Label).visible)


func test_a_tap_anywhere_on_a_board_quest_opens_that_quest_and_a_drag_starting_on_it_scrolls_instead() -> void:
	var board_view := _screen("res://screens/quest_board.tscn") as QuestBoard
	# A short screen, so three quests are more than it shows without scrolling.
	board_view.size.y = 550
	var dispatch := Dispatch.new(1_000)
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, 1_000, PackedInt64Array())
	board_view.show_board(board, dispatch, 1_000)
	var asked: Array[String] = []
	board_view.send_pressed.connect(func(quest: String) -> void:
		asked.append(quest)
		_fire())
	await wait_process_frames(1)
	var rows := board_view.get_node("Scroll/Box/List").get_children().filter(
			func(row: Control) -> bool: return row.visible)
	assert_eq(rows.size(), 3)
	var second := (rows[1] as Node).find_children("*", "Button", true, false)[0] as Button
	await _assert_drag_scrolls_and_does_not_fire(board_view.get_node("Scroll"), second)
	assert_eq(asked, [board.slots[1]] as Array[String])
	# Its name at the left and the › at the right open it too.
	var labels := (rows[1] as Node).find_children("*", "Label", true, false)
	var title := labels[0] as Label
	var more := labels[labels.size() - 1] as Label
	assert_eq(title.text, Dispatch.QUESTS[board.slots[1]]["name"])
	assert_eq(more.text, "›")
	await _touch_drag(_middle(title), _middle(title))
	await _touch_drag(_middle(more), _middle(more))
	assert_eq(asked, [board.slots[1], board.slots[1], board.slots[1]] as Array[String])


func test_a_tap_fires_even_when_the_finger_moves_a_little() -> void:
	var roster := _roster()
	await wait_process_frames(1)
	var row := _middle(_roster_row(roster, 0))
	await _touch_drag(row, row)
	assert_eq(_fired, 1)
	await _touch_drag(row, row + Vector2(_slop() - 2, 0))
	await _touch_drag(row, row + Vector2(0, _slop() - 2))
	assert_eq(_fired, 3)
	assert_eq((roster.get_node("Scroll") as ScrollContainer).scroll_vertical, 0)


func test_moving_just_past_the_slop_fires_nothing_in_a_scroll_or_out_of_one() -> void:
	var roster := _roster()
	var start := _screen("res://screens/start.tscn") as StartScreen
	start.position.y = SCREEN_SIZE.y
	start.new_game_pressed.connect(_fire)
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	picker.position.y = SCREEN_SIZE.y * 2
	# Tall enough that its rows show below the quest card.
	picker.size.y = SCREEN_SIZE.y * 2
	picker.open("rats", Dispatch.new(1_000), 1_000)
	await wait_process_frames(1)
	var past := _slop() + 2
	var row := _middle(_roster_row(roster, 0))
	await _touch_drag(row, row + Vector2(past, 0))
	await _touch_drag(row, row + Vector2(0, past))
	# Outside any scroll: the start screen's New game.
	var new_game := _middle(start.get_node("Menu/Choices/NewGame"))
	await _touch_drag(new_game, new_game + Vector2(past, 0))
	assert_eq(_fired, 0)
	# A toggle is not toggled either.
	var toggle := picker.get_node("Root/Scroll/List").get_child(0) as Button
	await _touch_drag(_middle(toggle), _middle(toggle) + Vector2(past, 0))
	assert_false(toggle.button_pressed)
	# The same presses, lifted where they started, fire.
	await _touch_drag(new_game, new_game)
	await _touch_drag(_middle(_roster_row(roster, 0)), _middle(_roster_row(roster, 0)))
	assert_eq(_fired, 2)
	await _touch_drag(_middle(toggle), _middle(toggle))
	assert_true(toggle.button_pressed)


func test_a_tap_anywhere_on_a_picker_row_picks_that_adventurer_and_another_unpicks_them() -> void:
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	picker.size = Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y * 2)
	picker.open("rats", Dispatch.new(1_000), 1_000)
	await wait_process_frames(1)
	var row := picker.get_node("Root/Scroll/List").get_child(0) as Button
	var send := picker.get_node("Root/Buttons/Send") as Button
	# On the face, at the row's left.
	var face := _middle(row.find_children("*", "TextureRect", true, false)[0])
	await _touch_drag(face, face)
	assert_true(row.button_pressed)
	assert_string_starts_with(send.text, "Send 1 · ")
	# On the check circle, at its right.
	var check := _middle(row.find_child("Check", true, false))
	await _touch_drag(check, check)
	assert_false(row.button_pressed)
	assert_eq(send.text, "Send")


func test_the_mouse_wheel_still_scrolls_the_roster() -> void:
	var roster := _roster()
	await wait_process_frames(1)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = _middle(_roster_row(roster, 0))
	_send(wheel)
	await wait_process_frames(1)
	assert_gt((roster.get_node("Scroll") as ScrollContainer).scroll_vertical, 0)
	assert_eq(_fired, 0)


func test_the_slop_is_about_10_dp_on_a_phone_in_either_orientation() -> void:
	# A 1080 × 2400 phone at a device pixel ratio of 2.6 shows the 1080-wide portrait viewport, or
	# in landscape the 1080-high one, at one viewport pixel to the device pixel.
	for visible: Vector2 in [Vector2(1080, 2400), Vector2(2400, 1080)]:
		var slop_dp := Touch.tap_slop_px(visible) / 2.6
		assert_between(slop_dp, 8.0, 11.0)
	# Twice the viewport is twice the pixels: the same finger travel.
	assert_eq(Touch.tap_slop_px(Vector2(2160, 4800)), 2.0 * Touch.tap_slop_px(Vector2(1080, 2400)))


func _press(at: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = at
	_send(press)


# Moves a finger held at `from` through each of `moves` in turn, a physics frame apart.
func _move(from: Vector2, moves: Array[Vector2]) -> void:
	for to: Vector2 in moves:
		var drag := InputEventScreenDrag.new()
		drag.position = to
		drag.relative = to - from
		_send(drag)
		from = to
		await wait_physics_frames(1)


func _lift(at: Vector2) -> void:
	var release := InputEventScreenTouch.new()
	release.position = at
	_send(release)


func test_past_the_slop_the_content_follows_the_finger_one_to_one_without_jumping_by_the_slop() -> void:
	var roster := _roster()
	var scroll := roster.get_node("Scroll") as ScrollContainer
	await wait_process_frames(1)
	var row := _middle(_roster_row(roster, 0))
	var at_slop := row - Vector2(0, _slop() - 1)
	_press(row)
	await _move(row, [at_slop])
	assert_eq(scroll.scroll_vertical, 0)
	# 4 pixels past it, the content has moved those 4, not the slop as well.
	await _move(at_slop, [at_slop - Vector2(0, 5)])
	assert_almost_eq(scroll.scroll_vertical, 4, 1)
	await _move(at_slop - Vector2(0, 5), [at_slop - Vector2(0, 55), at_slop - Vector2(0, 105)])
	assert_almost_eq(scroll.scroll_vertical, 104, 1)
	_lift(at_slop - Vector2(0, 105))
	assert_eq(_fired, 0)


# Flings the roster up from `row` at 10 pixels a physics frame and lifts the finger while it moves.
func _fling(row: Vector2) -> void:
	var moves: Array[Vector2] = []
	for i: int in range(1, 9):
		moves.append(row - Vector2(0, 10 * i))
	_press(row)
	await _move(row, moves)
	_lift(moves[-1])


func test_a_fling_glides_to_a_stop_and_a_touch_during_it_stops_it_without_pressing_what_is_under_it() -> void:
	var roster := _roster()
	var scroll := roster.get_node("Scroll") as ScrollContainer
	await wait_process_frames(1)
	var row := _middle(_roster_row(roster, 0))
	await _fling(row)
	var lifted_at := scroll.scroll_vertical
	await wait_physics_frames(3)
	assert_gt(scroll.scroll_vertical, lifted_at)
	# A tap mid-glide on someone stops it and opens nobody.
	var tap := _middle(_roster_row(roster, 1))
	_press(tap)
	_lift(tap)
	var stopped_at := scroll.scroll_vertical
	await wait_physics_frames(10)
	assert_eq(scroll.scroll_vertical, stopped_at)
	assert_eq(_fired, 0)
	assert_lt(stopped_at, (scroll.get_v_scroll_bar().max_value - scroll.size.y) as int)
	# Still, the same tap opens them.
	_press(tap)
	_lift(tap)
	assert_eq(_fired, 1)
	# Left alone, a fling slows to a stop.
	scroll.scroll_vertical = 0
	await wait_process_frames(1)
	await _fling(row)
	var glided := scroll.scroll_vertical
	await wait_physics_frames(300)
	var settled := scroll.scroll_vertical
	assert_gt(settled, glided)
	await wait_physics_frames(10)
	assert_eq(scroll.scroll_vertical, settled)


func test_a_tap_on_a_candidate_away_from_hire_opens_them_and_hires_nothing_whether_or_not_the_hire_is_refused() -> void:
	var roster := _screen("res://screens/roster.tscn") as Roster
	var adventurers := Adventurers.new()
	var recruits := Recruits.new()
	recruits.refill(adventurers, 1_000)
	roster.show_recruits(recruits, adventurers, Gold.new(0), Hall.MAX_ROSTER, Hall.new(1_000), 1_000)
	var hired: Array[int] = []
	roster.hire_pressed.connect(func(slot: int) -> void: hired.append(slot))
	roster.visitor_pressed.connect(func(_slot: int) -> void: _fire())
	var scroll := roster.get_node("Scroll") as ScrollContainer
	await wait_process_frames(1)
	scroll.scroll_vertical = 10_000
	await wait_process_frames(1)
	# The candidate's card, over the button that opens them; its name, away from the Hire button.
	var card := roster.get_node("Scroll/Box/Candidates").get_child(0).get_child(1) as Control
	var hire := card.find_children("*", "Button", true, false)[0] as Button
	var name_label := card.find_children("*", "Label", true, false)[0] as Label
	assert_true(scroll.get_global_rect().has_point(_middle(name_label)))
	assert_false(hire.get_global_rect().has_point(_middle(name_label)))
	assert_true(hire.disabled)
	await _touch_drag(_middle(name_label), _middle(name_label))
	assert_eq(_fired, 1)
	assert_eq(hired, [] as Array[int])
	roster.show_recruits(recruits, adventurers, Gold.new(1_000), Hall.MAX_ROSTER, Hall.new(1_000), 1_000)
	# Without the refusal's line, the card is laid out shorter on the next frame.
	await wait_process_frames(1)
	await _touch_drag(_middle(name_label), _middle(name_label))
	assert_eq(_fired, 2)
	assert_eq(hired, [] as Array[int])
	await _touch_drag(_middle(hire), _middle(hire))
	assert_eq(hired, [0] as Array[int])
	assert_eq(_fired, 2)


func test_a_tap_anywhere_on_a_stash_item_in_the_armory_asks_to_sell_that_item_and_a_drag_does_not() -> void:
	var armory := _screen("res://screens/armory.tscn") as Armory
	var adventurers := Adventurers.new()
	adventurers.gear.stash_cap = 20
	for item: String in ["night_cloak", "belt", "sash", "quiver", "iron_cap", "oak_staff", "red_cloak", "chapel_plate"]:
		assert_true(adventurers.gear.stow(item))
	armory.show_gear(adventurers)
	var asked: Array[String] = []
	armory.sell_pressed.connect(func(item: String) -> void:
		asked.append(item)
		_fire())
	await wait_process_frames(1)
	var rows := armory.get_node("Box/Scroll/Lists/Stash/Items")
	var sell := rows.get_child(0).find_children("*", "Button", true, false)[0] as Button
	assert_eq(sell.text, "Sell 15g")
	await _assert_drag_scrolls_and_does_not_fire(armory.get_node("Box/Scroll") as ScrollContainer, sell)
	assert_eq(asked, ["night_cloak"] as Array[String])
	# The item's name, away from its Sell button.
	var name_label := rows.get_child(1).find_children("*", "Label", true, false)[0] as Label
	assert_eq(name_label.text, "Belt")
	await _touch_drag(_middle(name_label), _middle(name_label))
	assert_eq(asked, ["night_cloak", "belt"] as Array[String])
