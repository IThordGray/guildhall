extends GutTest

var _screen: Adventurer
var _dispatch: Dispatch
var _shown: String = "bram"
var _backs: int = 0


func before_each() -> void:
	_dispatch = Dispatch.new(1_000)
	_shown = "bram"
	_backs = 0
	_screen = (load("res://screens/adventurer.tscn") as PackedScene).instantiate()
	add_child_autofree(_screen)
	_screen.show_adventurer(_shown, _dispatch, 1_000)
	# The same as main.gd does with the signals.
	_screen.swiped.connect(func(step: int) -> void:
		_shown = Roster.adventurer_after(_shown, step)
		_screen.show_adventurer(_shown, _dispatch, 1_000))
	_screen.back_pressed.connect(func() -> void: _backs += 1)
	# Containers lay out their children on the next frame.
	await wait_process_frames(1)


func _shown_name() -> String:
	return (_screen.get_node("Box/Scroll/Content/Card/Header/Row/Words/NameLine/Name") as Label).text


# Through Input, as the platform sends it, so touch is also emulated as mouse events. The platform
# sends window pixels, so the viewport positions are turned into those first.
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()


func _mouse_drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	_send(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	_send(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = to
	release.global_position = to
	_send(release)


func _touch_drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = from
	_send(press)
	var drag := InputEventScreenDrag.new()
	drag.position = to
	drag.relative = to - from
	_send(drag)
	var release := InputEventScreenTouch.new()
	release.position = to
	_send(release)


func _middle() -> Vector2:
	return _screen.get_global_rect().get_center()


func _back_middle() -> Vector2:
	return (_screen.get_node("Box/Back") as Button).get_global_rect().get_center()


func test_the_roster_order_steps_forward_and_back_and_wraps_at_both_ends() -> void:
	assert_eq(Roster.adventurer_after("bram", 1), "ilse")
	assert_eq(Roster.adventurer_after("tobin", 1), "maren")
	assert_eq(Roster.adventurer_after("maren", 1), "bram")
	assert_eq(Roster.adventurer_after("ilse", -1), "bram")
	assert_eq(Roster.adventurer_after("bram", -1), "maren")


func test_a_mouse_drag_left_shows_the_next_adventurer_and_right_the_previous() -> void:
	assert_eq(_shown_name(), "Bram")
	_mouse_drag(_middle(), _middle() + Vector2(-200, 30))
	assert_eq(_shown_name(), "Ilse")
	_mouse_drag(_middle(), _middle() + Vector2(200, -30))
	assert_eq(_shown_name(), "Bram")
	_mouse_drag(_middle(), _middle() + Vector2(200, 0))
	assert_eq(_shown_name(), "Maren")


func test_a_touch_drag_pages_once_though_touch_also_arrives_as_mouse_events() -> void:
	_touch_drag(_middle(), _middle() + Vector2(-200, 0))
	assert_eq(_shown_name(), "Ilse")
	_touch_drag(_middle(), _middle() + Vector2(200, 0))
	assert_eq(_shown_name(), "Bram")


func test_a_vertical_or_short_drag_is_not_a_swipe() -> void:
	_mouse_drag(_middle(), _middle() + Vector2(0, -200))
	_touch_drag(_middle(), _middle() + Vector2(0, 200))
	_mouse_drag(_middle(), _middle() + Vector2(150, -200))
	_mouse_drag(_middle(), _middle() + Vector2(-60, 0))
	assert_eq(_shown_name(), "Bram")
	_mouse_drag(_middle(), _middle() + Vector2(-200, 0))
	assert_eq(_shown_name(), "Ilse")


func test_a_tap_on_back_goes_back_and_does_not_page() -> void:
	_mouse_drag(_back_middle(), _back_middle())
	_touch_drag(_back_middle(), _back_middle())
	assert_eq(_backs, 2)
	assert_eq(_shown_name(), "Bram")


func test_a_sideways_drag_along_back_presses_back_as_before_and_does_not_page() -> void:
	_mouse_drag(_back_middle(), _back_middle() + Vector2(-200, 0))
	_touch_drag(_back_middle(), _back_middle() + Vector2(200, 0))
	assert_eq(_backs, 2)
	assert_eq(_shown_name(), "Bram")


func test_a_hidden_screen_ignores_swipes() -> void:
	_screen.hide()
	_mouse_drag(_middle(), _middle() + Vector2(-200, 0))
	_screen.show()
	assert_eq(_shown_name(), "Bram")
	_mouse_drag(_middle(), _middle() + Vector2(-200, 0))
	assert_eq(_shown_name(), "Ilse")
