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


func _middle(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


# Drags `button` up from its middle in `scroll`, past the slop but not off the button, so the finger
# lifts on it: the content scrolls and the button does not fire. Back at the top, a tap on it does.
func _assert_drag_scrolls_and_does_not_fire(scroll: ScrollContainer, button: BaseButton) -> void:
	assert_false(button.disabled)
	assert_eq(scroll.scroll_vertical, 0)
	var from := _middle(button)
	var to := from + Vector2(0, -(Touch.TAP_SLOP_PX + 10))
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


func _roster() -> Roster:
	var roster := _screen("res://screens/roster.tscn") as Roster
	roster.show_dispatch(Dispatch.new(1_000), 1_000)
	roster.adventurer_pressed.connect(func(_adventurer: String) -> void: _fire())
	return roster


func _roster_row(roster: Roster, index: int) -> Button:
	return roster.get_node("Scroll/Box/List").get_child(index) as Button


func test_a_drag_starting_on_an_adventurer_in_the_roster_scrolls_it_and_does_not_open_them() -> void:
	var roster := _roster()
	await wait_process_frames(1)
	await _assert_drag_scrolls_and_does_not_fire(roster.get_node("Scroll"), _roster_row(roster, 1))


func test_a_drag_starting_on_a_hall_room_scrolls_the_hall_and_does_not_restore_it() -> void:
	var hall_view := _screen("res://screens/hall_view.tscn") as HallView
	var hall := Hall.new(1_000)
	hall_view.show_state(hall, Dispatch.new(1_000), Gold.new(10_000), 3, 1_000)
	hall_view.restore_pressed.connect(func(_slot: String) -> void: _fire())
	await wait_process_frames(1)
	var restore := hall_view.get_node("Scroll/Box/Columns/Left/Plan").find_children("*", "Button", true, false).filter(
			func(button: Button) -> bool: return button.text == "Restore" and button.is_visible_in_tree())[0] as Button
	await _assert_drag_scrolls_and_does_not_fire(hall_view.get_node("Scroll"), restore)


func test_a_drag_starting_on_a_board_quest_scrolls_the_board_and_does_not_send_it() -> void:
	var board_view := _screen("res://screens/quest_board.tscn") as QuestBoard
	var dispatch := Dispatch.new(1_000)
	var board := Board.new()
	board.refill(dispatch, 1_000, PackedInt64Array())
	board_view.show_board(board, dispatch, 1_000)
	board_view.send_pressed.connect(func(_quest: String) -> void: _fire())
	await wait_process_frames(1)
	var sends := board_view.get_node("Scroll/Box/List").find_children("*", "Button", true, false).filter(
			func(button: Button) -> bool: return button.is_visible_in_tree())
	await _assert_drag_scrolls_and_does_not_fire(board_view.get_node("Scroll"), sends[1])


func test_a_tap_fires_even_when_the_finger_moves_a_little() -> void:
	var roster := _roster()
	await wait_process_frames(1)
	var row := _middle(_roster_row(roster, 1))
	await _touch_drag(row, row)
	assert_eq(_fired, 1)
	await _touch_drag(row, row + Vector2(Touch.TAP_SLOP_PX - 2, 0))
	await _touch_drag(row, row + Vector2(0, Touch.TAP_SLOP_PX - 2))
	assert_eq(_fired, 3)
	assert_eq((roster.get_node("Scroll") as ScrollContainer).scroll_vertical, 0)


func test_moving_just_past_the_slop_fires_nothing_in_a_scroll_or_out_of_one() -> void:
	var roster := _roster()
	var start := _screen("res://screens/start.tscn") as StartScreen
	start.position.y = SCREEN_SIZE.y
	start.new_game_pressed.connect(_fire)
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	picker.position.y = SCREEN_SIZE.y * 2
	picker.open("rats", Dispatch.new(1_000), 1_000)
	await wait_process_frames(1)
	var past := Touch.TAP_SLOP_PX + 2
	var row := _middle(_roster_row(roster, 1))
	await _touch_drag(row, row + Vector2(past, 0))
	await _touch_drag(row, row + Vector2(0, past))
	# Outside any scroll: the start screen's New game.
	var new_game := _middle(start.get_node("Menu/Choices/NewGame"))
	await _touch_drag(new_game, new_game + Vector2(past, 0))
	assert_eq(_fired, 0)
	# A toggle is not toggled either.
	var toggle := picker.get_node("Root/Scroll/Box/List").get_child(0) as Button
	await _touch_drag(_middle(toggle), _middle(toggle) + Vector2(past, 0))
	assert_false(toggle.button_pressed)
	# The same presses, lifted where they started, fire.
	await _touch_drag(new_game, new_game)
	await _touch_drag(_middle(_roster_row(roster, 1)), _middle(_roster_row(roster, 1)))
	assert_eq(_fired, 2)
	await _touch_drag(_middle(toggle), _middle(toggle))
	assert_true(toggle.button_pressed)


func test_the_mouse_wheel_still_scrolls_the_roster() -> void:
	var roster := _roster()
	await wait_process_frames(1)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = _middle(_roster_row(roster, 1))
	_send(wheel)
	await wait_process_frames(1)
	assert_gt((roster.get_node("Scroll") as ScrollContainer).scroll_vertical, 0)
	assert_eq(_fired, 0)
