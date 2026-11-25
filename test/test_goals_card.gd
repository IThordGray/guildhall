extends GutTest

const NONE_DONE: PackedStringArray = []
const FIRST_QUEST_LINE: String = "Pick a quest from the board and see your party home."
const RESTORE_LINE: String = "This old hall needs work. Have the builder restore a room."
const HAND_QUESTS_LINE: String = "Send ten quests out yourself, then your parties may go alone."

## The screens are put on a layer above GUT's own output window, with Touch as main.tscn has it.
var _layer: CanvasLayer
var _goals: Goals
var _dispatch: Dispatch
var _hall: Hall


func before_each() -> void:
	# A drag past the slop is followed only while touch is emulated from the mouse, as on a phone.
	Input.emulate_touch_from_mouse = true
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_layer.add_child(Touch.new())
	# A new game's guild.
	_goals = Goals.new()
	_dispatch = Dispatch.new(1_000)
	_dispatch.gold = Gold.new(100)
	_hall = Hall.new(1_000)


func after_each() -> void:
	Input.emulate_touch_from_mouse = false


# The Hall at `size`, in portrait or `landscape`, showing the guild and its goals at 1_000.
func _hall_view(size: Vector2, landscape: bool = false) -> HallView:
	var hall_view := (load("res://screens/hall_view.tscn") as PackedScene).instantiate() as HallView
	_layer.add_child(hall_view)
	hall_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hall_view.size = size
	hall_view.set_landscape(landscape)
	_show(hall_view)
	return hall_view


# What main.gd shows at each checkpoint.
func _show(hall_view: HallView) -> void:
	hall_view.show_state(_hall, _dispatch, 2, 1_000)
	hall_view.goals_card.show_goals(_goals, _dispatch, _hall, NONE_DONE, 1_000)


# Each goal row as the texts it shows, in order, then "bar" when it shows a bar.
func _rows(hall_view: HallView) -> Array:
	var rows := []
	for row: Node in hall_view.goals_card.get_node("List/Rows").get_children():
		var shown := []
		for part: Node in row.find_children("*", "", true, false):
			if not (part as Control).is_visible_in_tree():
				continue
			if part is Label:
				shown.append((part as Label).text)
			elif part is Button:
				shown.append((part as Button).text)
			elif part is ProgressBar:
				shown.append("bar")
		rows.append(shown)
	return rows


func _claim_button(hall_view: HallView) -> Button:
	return hall_view.goals_card.find_children("*", "Button", true, false)[0] as Button


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


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()


func test_a_new_games_hall_shows_a_goals_card_with_the_first_story_goal_and_ten_hand_quests_each_with_odiles_line() -> void:
	var hall_view := _hall_view(Vector2(1080, 1580))
	await wait_process_frames(1)
	assert_true(hall_view.goals_card.is_visible_in_tree())
	assert_eq((hall_view.goals_card.get_node("Header/Section") as Label).text, "GOALS")
	assert_eq((hall_view.goals_card.get_node("Header/From") as Label).text, "from Odile, town clerk")
	assert_eq(_rows(hall_view), [
		["Story", "Send a party on a quest", "10g", "0 / 1", FIRST_QUEST_LINE],
		["Send 10 quests by hand", "Unlocks Auto", "0 / 10", "bar", HAND_QUESTS_LINE],
	])


func test_a_done_goal_shows_claim_and_a_tap_on_it_pays_records_and_rebuilds_with_the_next_story_goal() -> void:
	# A party home from the rats.
	_dispatch.tries["rats"] = 1
	var hall_view := _hall_view(Vector2(1080, 1580))
	assert_eq(_rows(hall_view), [
		["Story", "Send a party on a quest", "Claim +10g", FIRST_QUEST_LINE],
		["Send 10 quests by hand", "Unlocks Auto", "0 / 10", "bar", HAND_QUESTS_LINE],
	])
	# The same as main.gd does with the signal, the "+10" rising from where the button is.
	var flown_from: Array[Vector2] = []
	hall_view.goals_card.claim_pressed.connect(func(goal: String, from: Vector2) -> void:
		if _goals.claim(goal, _dispatch, _hall, NONE_DONE, 1_000):
			flown_from.append(from)
		_show(hall_view))
	await wait_process_frames(1)
	var claim := _claim_button(hall_view)
	var middle := claim.get_global_rect().get_center()
	# A press that turns into a drag claims nothing.
	await _touch_drag(middle, middle + Vector2(Touch.tap_slop_px(get_viewport().get_visible_rect().size) + 2, 0))
	assert_eq(_dispatch.gold.amount, 100)
	assert_eq(_goals.claimed, PackedStringArray())
	await _touch_drag(middle, middle)
	assert_eq(_dispatch.gold.amount, 110)
	assert_eq(_goals.claimed, PackedStringArray(["first_quest"]))
	assert_eq(flown_from, [middle])
	assert_eq(_rows(hall_view), [
		["Story", "Restore a room", "15g", "0 / 1", RESTORE_LINE],
		["Send 10 quests by hand", "Unlocks Auto", "0 / 10", "bar", HAND_QUESTS_LINE],
	])


func test_claiming_ten_hand_quests_unlocks_auto_and_the_quests_screens_party_cards_then_show_the_auto_switch() -> void:
	_goals.hand_quests = 10
	var hall_view := _hall_view(Vector2(1080, 1580))
	var board := (load("res://screens/quest_board.tscn") as PackedScene).instantiate() as QuestBoard
	_layer.add_child(board)
	# Below the hall, out of the way of the taps on it.
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.position.y = 3_000
	board.show_board(Board.new(), _dispatch, 1_000, _goals.is_unlocked(Goals.AUTO))
	var row := board.get_node("Scroll/Box/PartyList").get_child(0) as Control
	var switch := row.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.toggle_mode)[0] as Button
	assert_true(row.is_visible_in_tree())
	assert_false(switch.is_visible_in_tree())
	assert_eq(_rows(hall_view)[1], ["Send 10 quests by hand", "Unlocks Auto", "Claim +20g", HAND_QUESTS_LINE])
	# The same as main.gd does with the signal: the checkpoint after the claim refreshes both screens.
	hall_view.goals_card.claim_pressed.connect(func(goal: String, _from: Vector2) -> void:
		_goals.claim(goal, _dispatch, _hall, NONE_DONE, 1_000)
		_show(hall_view)
		board.show_board(Board.new(), _dispatch, 1_000, _goals.is_unlocked(Goals.AUTO)))
	await wait_process_frames(1)
	var middle := _claim_button(hall_view).get_global_rect().get_center()
	await _touch_drag(middle, middle)
	assert_true(_goals.is_unlocked(Goals.AUTO))
	assert_eq(_dispatch.gold.amount, 120)
	assert_true(switch.is_visible_in_tree())
	assert_eq(_rows(hall_view), [["Story", "Send a party on a quest", "10g", "0 / 1", FIRST_QUEST_LINE]])


func test_the_card_is_hidden_when_no_goal_is_open_or_done_and_sits_under_the_header_in_portrait_and_above_in_progress_in_landscape() -> void:
	var hall_view := _hall_view(Vector2(1080, 1580))
	await wait_process_frames(1)
	var card := hall_view.goals_card
	var title := hall_view.get_node("Scroll/Box/Top/Header/Title") as Control
	var plan := hall_view.get_node("Scroll/Box/Columns/Left/Plan") as Control
	assert_true(card.is_visible_in_tree())
	assert_lt(title.get_global_rect().end.y, card.get_global_rect().position.y)
	assert_lt(card.get_global_rect().end.y, plan.get_global_rect().position.y)

	hall_view.set_landscape(true)
	hall_view.size = Vector2(1700, 1000)
	await wait_process_frames(2)
	var in_progress := hall_view.get_node("Scroll/Box/Columns/Right/Section") as Control
	# Bram and Tobin ready, with quests on the board.
	assert_true(in_progress.is_visible_in_tree())
	assert_true(card.is_visible_in_tree())
	# At the top of the column beside the plan, over In progress.
	assert_almost_eq(card.get_global_rect().position.y, plan.get_global_rect().position.y, 1.0)
	assert_almost_eq(card.get_global_rect().position.x, in_progress.get_global_rect().position.x, 1.0)
	assert_gt(card.get_global_rect().position.x, plan.get_global_rect().end.x)
	assert_lt(card.get_global_rect().end.y, in_progress.get_global_rect().position.y)

	# Every goal claimed: the card goes and the hall stays.
	_goals.claimed = PackedStringArray(Goals.GOALS.keys())
	_show(hall_view)
	assert_false(card.is_visible_in_tree())
	assert_true(plan.is_visible_in_tree())
	assert_true(in_progress.is_visible_in_tree())
	# And back once one is open again.
	_goals.claimed.remove_at(_goals.claimed.find("hand_quests"))
	_show(hall_view)
	assert_true(card.is_visible_in_tree())
	assert_eq(_rows(hall_view), [["Send 10 quests by hand", "Unlocks Auto", "0 / 10", "bar", HAND_QUESTS_LINE]])
	# Progress alone changing rebuilds it too.
	_goals.hand_quests = 3
	_show(hall_view)
	assert_eq(_rows(hall_view), [["Send 10 quests by hand", "Unlocks Auto", "3 / 10", "bar", HAND_QUESTS_LINE]])
	await wait_process_frames(1)
