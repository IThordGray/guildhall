extends GutTest

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]

var _screen: Adventurer
var _dispatch: Dispatch
var _shown: String = "bram"
var _backs: int = 0
## The gear slots tapped open, as "adventurer:slot".
var _slots_opened: Array[String] = []


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


func before_each() -> void:
	_dispatch = _guild(1_000)
	_shown = "bram"
	_backs = 0
	_slots_opened = []
	_screen = (load("res://screens/adventurer.tscn") as PackedScene).instantiate()
	# On a layer above GUT's own output window, which would otherwise take some of the presses.
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child_autofree(layer)
	# As in main.tscn, which keeps a press that turns into a drag from firing a button.
	layer.add_child(Touch.new())
	layer.add_child(_screen)
	_screen.show_adventurer(_shown, _dispatch, Gold.new(0), 0, 1_000)
	# The same as main.gd does with the signals.
	_screen.swiped.connect(func(step: int) -> void:
		_shown = Roster.adventurer_after(_shown, step, _dispatch.adventurers.roster)
		_screen.show_adventurer(_shown, _dispatch, Gold.new(0), 0, 1_000))
	_screen.back_pressed.connect(func() -> void: _backs += 1)
	_screen.slot_pressed.connect(func(adventurer: String, slot: String) -> void: _slots_opened.append(adventurer + ":" + slot))
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


func _touch_drag(from: Vector2, to: Vector2, canceled: bool = false) -> void:
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
	release.canceled = canceled
	_send(release)


func _middle() -> Vector2:
	return _screen.get_global_rect().get_center()


func _back_middle() -> Vector2:
	return (_screen.get_node("Box/Back") as Button).get_global_rect().get_center()


func test_the_roster_order_steps_forward_and_back_and_wraps_at_both_ends() -> void:
	var roster := _dispatch.adventurers.roster
	assert_eq(Roster.adventurer_after("bram", 1, roster), "ilse")
	assert_eq(Roster.adventurer_after("tobin", 1, roster), "maren")
	assert_eq(Roster.adventurer_after("maren", 1, roster), "bram")
	assert_eq(Roster.adventurer_after("ilse", -1, roster), "bram")
	assert_eq(Roster.adventurer_after("bram", -1, roster), "maren")


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


func test_a_sideways_drag_that_starts_and_ends_on_back_pages_and_does_not_press_back() -> void:
	_mouse_drag(_back_middle(), _back_middle() + Vector2(-200, 0))
	assert_eq(_shown_name(), "Ilse")
	_touch_drag(_back_middle(), _back_middle() + Vector2(-200, 0))
	assert_eq(_shown_name(), "Tobin")
	assert_eq(_backs, 0)


func test_a_swipe_from_the_content_that_ends_on_back_pages_and_does_not_press_back() -> void:
	_mouse_drag(_back_middle() + Vector2(300, -150), _back_middle())
	assert_eq(_shown_name(), "Ilse")
	_touch_drag(_back_middle() + Vector2(300, -150), _back_middle())
	assert_eq(_shown_name(), "Tobin")
	assert_eq(_backs, 0)


func test_a_drag_that_starts_on_back_and_ends_off_it_pages_and_does_not_press_back() -> void:
	_mouse_drag(_back_middle(), _back_middle() + Vector2(-300, -150))
	assert_eq(_shown_name(), "Ilse")
	_touch_drag(_back_middle(), _back_middle() + Vector2(-300, -150))
	assert_eq(_shown_name(), "Tobin")
	assert_eq(_backs, 0)


func test_a_swipe_that_ends_on_a_gear_slot_pages_in_landscape_and_does_not_open_it() -> void:
	_screen.set_landscape(true)
	await wait_process_frames(1)
	var slots := _screen.get_node("Box/Scroll/Content/GearColumn/Gear").find_children("*", "Button", true, false)
	assert_eq(slots.size(), 8)
	# The second slot is Clothes.
	var on_slot := (slots[1] as Button).get_global_rect().get_center()
	# A tap on a slot opens it, so the swipe below lands on a live button.
	_mouse_drag(on_slot, on_slot)
	assert_eq(_slots_opened, ["bram:clothes"] as Array[String])
	_mouse_drag(on_slot + Vector2(-300, 0), on_slot)
	assert_eq(_shown_name(), "Maren")
	assert_eq(_slots_opened.size(), 1)


func test_a_tap_on_a_gear_slots_box_or_its_name_under_it_opens_that_slot() -> void:
	# In landscape the gear is one row, in view in this tall viewport without scrolling.
	_screen.set_landscape(true)
	await wait_process_frames(1)
	# The second slot is Clothes: its box, then its slot name under it.
	var cell := _screen.get_node("Box/Scroll/Content/GearColumn/Gear").get_child(1).get_child(0)
	var slot_name := cell.get_child(1) as Label
	assert_eq(slot_name.text, "CLOTHES")
	for part: Control in [cell.get_child(0), slot_name]:
		var at := part.get_global_rect().get_center()
		_mouse_drag(at, at)
	assert_eq(_slots_opened, ["bram:clothes", "bram:clothes"] as Array[String])


func test_a_cancelled_touch_is_not_a_swipe() -> void:
	_touch_drag(_middle(), _middle() + Vector2(-200, 0), true)
	assert_eq(_shown_name(), "Bram")
	_touch_drag(_middle(), _middle() + Vector2(-200, 0))
	assert_eq(_shown_name(), "Ilse")


func test_a_drag_that_starts_outside_the_screen_does_not_page() -> void:
	# As the top bar or the landscape rail would be: left of the screen.
	_screen.offset_left = 400
	_mouse_drag(Vector2(300, 600), Vector2(700, 600))
	_touch_drag(Vector2(300, 600), Vector2(700, 600))
	assert_eq(_shown_name(), "Bram")
	_mouse_drag(Vector2(500, 600), Vector2(900, 600))
	assert_eq(_shown_name(), "Maren")


func test_a_hidden_screen_ignores_swipes() -> void:
	_screen.hide()
	_mouse_drag(_middle(), _middle() + Vector2(-200, 0))
	_screen.show()
	assert_eq(_shown_name(), "Bram")
	_mouse_drag(_middle(), _middle() + Vector2(-200, 0))
	assert_eq(_shown_name(), "Ilse")
