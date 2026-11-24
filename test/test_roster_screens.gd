extends GutTest

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]

var _dispatch: Dispatch


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


func before_each() -> void:
	_dispatch = _guild(1_000)


# Wren joins after the starters.
func _add_wren() -> void:
	_dispatch.adventurers.add("wren", {"name": "Wren", "rank": "F"}, Adventurers.STARTING_STATS["bram"], Adventurers.GROWTH["bram"])


func _screen(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	return screen


# The text of every label in `node`, visible or not.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func test_after_an_adventurer_joins_the_roster_shows_five_rows_the_newcomer_last_with_their_face() -> void:
	var roster := _screen("res://screens/roster.tscn") as Roster
	var list := roster.get_node("Scroll/Box/List")
	roster.show_dispatch(_dispatch, 1_000)
	assert_eq(list.get_child_count(), 4)
	var first_row := list.get_child(0)
	roster.show_dispatch(_dispatch, 1_001)
	# Nobody joined, so the rows are the ones already built.
	assert_same(list.get_child(0), first_row)
	_add_wren()
	roster.show_dispatch(_dispatch, 1_002)
	assert_eq(list.get_child_count(), 5)
	assert_has(_texts(list.get_child(4)), "Wren")
	assert_eq(list.get_child(4).find_children("*", "TextureRect", true, false).size(), 1)
	assert_has(_texts(list.get_child(0)), "Bram")
	assert_does_not_have(_texts(list.get_child(0)), "B")
	await wait_process_frames(1)


# Where in `list` the rows marked as the one shown beside the roster are.
func _marked_rows(list: Node) -> Array[int]:
	var marked: Array[int] = []
	for row: Node in list.get_children():
		if (row as Button).theme_type_variation == &"ListRowChosen":
			marked.append(row.get_index())
	return marked


func test_the_marked_row_stays_marked_when_someone_joins_and_the_mark_moves_to_the_row_marked_next() -> void:
	var roster := _screen("res://screens/roster.tscn") as Roster
	var list := roster.get_node("Scroll/Box/List")
	roster.show_dispatch(_dispatch, 1_000)
	roster.mark("ilse")
	assert_eq(_marked_rows(list), [1] as Array[int])
	var ilse_row := list.get_child(1)
	_add_wren()
	roster.show_dispatch(_dispatch, 1_001)
	# The rows were built again, and Ilse's new row is the one marked.
	assert_ne(list.get_child(1), ilse_row)
	assert_eq(_marked_rows(list), [1] as Array[int])
	roster.mark("wren")
	assert_eq(_marked_rows(list), [4] as Array[int])
	roster.mark("")
	assert_eq(list.get_child_count(), 5)
	assert_eq(_marked_rows(list), [] as Array[int])
	await wait_process_frames(1)


func test_after_an_adventurer_joins_the_party_picker_shows_five_the_newcomer_last_and_sendable() -> void:
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	var list := picker.get_node("Root/Scroll/Box/List")
	picker.open("letters", _dispatch, 1_000)
	assert_eq(list.get_child_count(), 4)
	(list.get_child(1) as Button).button_pressed = true
	_add_wren()
	picker.show_dispatch(_dispatch, 1_001)
	assert_eq(list.get_child_count(), 5)
	var wren := list.get_child(4) as Button
	assert_string_starts_with(wren.text, "Wren")
	# Who was picked stays picked.
	assert_true((list.get_child(1) as Button).button_pressed)
	var sent: Array[PackedStringArray] = []
	picker.send_pressed.connect(func(_quest: String, party: PackedStringArray) -> void: sent.append(party))
	wren.button_pressed = true
	var send := picker.get_node("Root/Buttons/Send") as Button
	assert_false(send.disabled)
	send.pressed.emit()
	assert_eq(sent, [PackedStringArray(["ilse", "wren"])])


func test_the_party_picker_keeps_its_toggles_while_nobody_joins_or_leaves() -> void:
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	var list := picker.get_node("Root/Scroll/Box/List")
	picker.open("letters", _dispatch, 1_000)
	var first := list.get_child(0)
	picker.show_dispatch(_dispatch, 1_001)
	picker.show_dispatch(_dispatch, 1_002)
	assert_same(list.get_child(0), first)
	assert_eq(list.get_child_count(), 4)
	_add_wren()
	picker.show_dispatch(_dispatch, 1_003)
	assert_eq(list.get_child_count(), 5)
	await wait_process_frames(1)


func test_a_newcomer_shows_their_face_not_their_initial_in_a_token_and_on_the_landscape_picker_card() -> void:
	_add_wren()
	var roster := _dispatch.adventurers.roster
	var token := autofree(QuestBoard.token("wren", roster)) as Label
	assert_eq(token.text, "")
	assert_true(token.get_child(0) is TextureRect)
	var starter := autofree(QuestBoard.token("bram", roster)) as Label
	assert_eq(starter.text, "")
	assert_true(starter.get_child(0) is TextureRect)

	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	picker.set_landscape(true)
	picker.open("rats", _dispatch, 1_000)
	var cards := picker.get_node("Root/Scroll/Box/List")
	var card := cards.get_child(4) as Button
	assert_eq(card.icon.get_size(), Vector2(160, 220))
	assert_eq(_texts(card), [] as Array[String])
	# A starter's card shows their face, with no initial over it.
	assert_eq(_texts(cards.get_child(0)), [] as Array[String])
	await wait_process_frames(1)
	picker.set_landscape(false)
	assert_eq(card.icon.get_size(), Vector2(224, 308))


# The Quests screen showing `_dispatch` at 1_000, with an empty board.
func _quests() -> QuestBoard:
	var board := _screen("res://screens/quest_board.tscn") as QuestBoard
	board.show_board(Board.new(), _dispatch, 1_000)
	return board


# The button in `node` reading `text`, or null.
func _button(node: Node, text: String) -> Button:
	for button: Node in node.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button
	return null


# The text of every button in `node` that has any, in tree order.
func _button_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for button: Node in node.find_children("*", "Button", true, false):
		if not (button as Button).text.is_empty():
			texts.append((button as Button).text)
	return texts


# Goblin camp's Goblin-bone helm waits for a full stash whose items sell for 60, 3, 15, 3, 3 and 15.
func _helm_waiting() -> void:
	_dispatch.adventurers.gear.stash = PackedStringArray(["moonweave_robe", "belt", "night_cloak", "sash", "quiver", "chapel_shield"])
	_dispatch.waiting_loot.append({"quest": "goblins", "party": PackedStringArray(["bram", "ilse"]), "item": "goblin_bone_helm"})


func test_needs_you_shows_a_row_per_loot_waiting_and_one_for_every_level_up_ready_and_hides_once_nothing_waits() -> void:
	var board := _quests()
	var header := board.get_node("Scroll/Box/NeedsYouHeader") as Control
	var rows := board.get_node("Scroll/Box/NeedsYou")
	assert_false(header.visible)
	_helm_waiting()
	_dispatch.adventurers.gain_xp("tobin", 10)
	_dispatch.adventurers.gain_xp("maren", 10)
	board.show_board(Board.new(), _dispatch, 1_000)
	assert_true(header.visible)
	assert_eq((header.get_node("Count") as Label).text, "2")
	assert_eq(rows.get_child_count(), 2)
	assert_eq(_texts(rows.get_child(0)), ["Stash full", "Goblin camp brought Goblin-bone helm"] as Array[String])
	assert_has(_texts(rows.get_child(1)), "Level up ready")
	assert_has(_texts(rows.get_child(1)), "Tobin, Maren")
	# Nothing changed: the rows are the same ones.
	var first := rows.get_child(0)
	board.show_board(Board.new(), _dispatch, 1_001)
	assert_same(rows.get_child(0), first)
	# Decided, and a level-up taken: one row left.
	_dispatch.let_loot_go(0)
	_dispatch.adventurers.level_up("tobin")
	board.show_board(Board.new(), _dispatch, 1_002)
	assert_eq((header.get_node("Count") as Label).text, "1")
	assert_eq(rows.get_child_count(), 1)
	assert_has(_texts(rows.get_child(0)), "Maren")
	assert_does_not_have(_texts(rows.get_child(0)), "Tobin, Maren")
	_dispatch.adventurers.level_up("maren")
	board.show_board(Board.new(), _dispatch, 1_003)
	assert_false(header.visible)
	assert_eq(rows.get_child_count(), 0)


func test_decide_opens_the_loot_then_the_stash_cheapest_first_in_place_and_done_closes_it() -> void:
	_helm_waiting()
	var board := _quests()
	var rows := board.get_node("Scroll/Box/NeedsYou")
	var done := board.get_node("Scroll/Box/NeedsYouHeader/Done") as Button
	assert_false(done.visible)
	_button(rows, "Decide ›").pressed.emit()
	assert_true(done.visible)
	assert_null(_button(rows, "Decide ›"))
	var texts := _texts(rows)
	assert_eq(texts.slice(0, 5), ["Stash full · 6 / 6", "Goblin camp · Bram, Ilse", "Goblin-bone helm", "Fine ·", "Strength +1 · Defence +2"] as Array[String])
	# Cheapest first, items of one price in the order they came into the stash.
	var names: Array[String] = []
	for item: String in ["belt", "sash", "quiver", "night_cloak", "chapel_shield", "moonweave_robe"]:
		names.append(Gear.ITEMS[item]["name"])
	var shown: Array[String] = []
	for text: String in texts:
		if text in names:
			shown.append(text)
	assert_eq(shown, names)
	assert_eq(_button_texts(rows), ["Swap · +3g", "Swap · +3g", "Swap · +3g", "Swap · +15g", "Swap · +15g", "Swap · +60g", "Let the Goblin-bone helm go"] as Array[String])
	watch_signals(board)
	_button(rows, "Swap · +15g").pressed.emit()
	assert_signal_emitted_with_parameters(board, "swap_pressed", [0, "night_cloak"])
	_button(rows, "Let the Goblin-bone helm go").pressed.emit()
	assert_signal_emitted_with_parameters(board, "let_go_pressed", [0])
	done.pressed.emit()
	assert_false(done.visible)
	assert_not_null(_button(rows, "Decide ›"))
	assert_null(_button(rows, "Let the Goblin-bone helm go"))


func test_an_open_decision_stays_on_its_loot_when_other_loot_comes_and_closes_once_it_is_decided() -> void:
	_helm_waiting()
	var board := _quests()
	var rows := board.get_node("Scroll/Box/NeedsYou")
	_button(rows, "Decide ›").pressed.emit()
	# Other loot comes in after it: the helm's stays open.
	_dispatch.waiting_loot.append({"quest": "rats", "party": PackedStringArray(["tobin"]), "item": "sash"})
	board.show_board(Board.new(), _dispatch, 1_001)
	assert_not_null(_button(rows, "Let the Goblin-bone helm go"))
	assert_null(_button(rows, "Let the Sash go"))
	# The helm swapped in, the rats' loot waits closed.
	assert_true(_dispatch.swap_loot(0, "belt"))
	board.show_board(Board.new(), _dispatch, 1_002)
	assert_eq(rows.get_child_count(), 1)
	assert_not_null(_button(rows, "Decide ›"))
	assert_false((board.get_node("Scroll/Box/NeedsYouHeader/Done") as Button).visible)


func test_open_on_the_level_up_row_asks_to_level_up_the_first_with_one_ready() -> void:
	_dispatch.adventurers.gain_xp("maren", 10)
	_dispatch.adventurers.gain_xp("ilse", 10)
	var board := _quests()
	watch_signals(board)
	_button(board.get_node("Scroll/Box/NeedsYou"), "Open ›").pressed.emit()
	assert_signal_emitted_with_parameters(board, "level_up_pressed", ["ilse"])


# A candidate's or the walk-in's card in `section` of `roster`, Candidates or WalkIn, at `index`:
# the card itself, over the button that opens them.
func _visitor_card(roster: Roster, section: String, index: int) -> PanelContainer:
	return roster.get_node("Scroll/Box/" + section).get_child(index).get_child(1) as PanelContainer


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


func _middle_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func test_a_tap_on_a_candidate_or_the_walk_in_opens_them_and_a_tap_on_their_buttons_acts_without_opening() -> void:
	# On a layer above GUT's own output window, with Touch as main.tscn has it.
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child_autofree(layer)
	layer.add_child(Touch.new())
	var roster := (load("res://screens/roster.tscn") as PackedScene).instantiate() as Roster
	layer.add_child(roster)
	var recruits := Recruits.new()
	recruits.refill(_dispatch.adventurers, 1_000)
	roster.show_recruits(recruits, _dispatch.adventurers, Gold.new(1_000), Hall.MAX_ROSTER, Hall.new(1_000), 1_000)
	roster.show_walk_in(WalkIns.walk_in_for(5_000, PackedStringArray()), true)
	var opened: Array[int] = []
	var hired: Array[int] = []
	var acted: Array[String] = []
	roster.visitor_pressed.connect(func(slot: int) -> void: opened.append(slot))
	roster.hire_pressed.connect(func(slot: int) -> void: hired.append(slot))
	roster.accept_pressed.connect(func() -> void: acted.append("accept"))
	roster.turn_away_pressed.connect(func() -> void: acted.append("turn away"))
	await wait_process_frames(1)
	var candidate := _visitor_card(roster, "Candidates", 0)
	var hire := candidate.find_children("*", "Button", true, false)[0] as Button
	assert_eq(hire.text, "Hire · 100g")
	_tap(_middle_of(candidate.find_children("*", "Label", true, false)[0]))
	assert_eq(opened, [0] as Array[int])
	assert_eq(hired, [] as Array[int])
	_tap(_middle_of(hire))
	assert_eq(hired, [0] as Array[int])
	assert_eq(opened, [0] as Array[int])
	var walk_in := _visitor_card(roster, "WalkIn", 1)
	var buttons := walk_in.find_children("*", "Button", true, false)
	_tap(_middle_of(walk_in.find_children("*", "Label", true, false)[0]))
	assert_eq(opened, [0, Roster.WALK_IN] as Array[int])
	# Turn away, then Accept, a bed being free.
	_tap(_middle_of(buttons[0]))
	_tap(_middle_of(buttons[1]))
	assert_eq(acted, ["turn away", "accept"] as Array[String])
	assert_eq(opened, [0, Roster.WALK_IN] as Array[int])
	await wait_process_frames(1)


func test_a_marked_candidate_stays_marked_when_the_candidates_are_rebuilt_and_the_mark_moves_to_the_walk_in_or_a_row() -> void:
	var roster := _screen("res://screens/roster.tscn") as Roster
	var recruits := Recruits.new()
	recruits.refill(_dispatch.adventurers, 1_000)
	roster.show_dispatch(_dispatch, 1_000)
	roster.show_recruits(recruits, _dispatch.adventurers, Gold.new(0), Hall.MAX_ROSTER, Hall.new(1_000), 1_000)
	roster.show_walk_in(WalkIns.walk_in_for(5_000, PackedStringArray()), true)
	roster.mark("", 0)
	var first := _visitor_card(roster, "Candidates", 0)
	assert_eq(first.theme_type_variation, &"RowCardChosen")
	assert_eq(_visitor_card(roster, "WalkIn", 1).theme_type_variation, &"")
	# A Common room brings a second candidate: the cards are built again, the first still marked.
	recruits.refill(_dispatch.adventurers, 1_001, PackedInt64Array([1_000]))
	roster.show_recruits(recruits, _dispatch.adventurers, Gold.new(0), Hall.MAX_ROSTER, Hall.new(1_000), 1_001)
	assert_ne(_visitor_card(roster, "Candidates", 0), first)
	assert_eq(_visitor_card(roster, "Candidates", 0).theme_type_variation, &"RowCardChosen")
	assert_eq(_visitor_card(roster, "Candidates", 1).theme_type_variation, &"")
	roster.mark("", Roster.WALK_IN)
	assert_eq(_visitor_card(roster, "WalkIn", 1).theme_type_variation, &"RowCardChosen")
	assert_eq(_visitor_card(roster, "Candidates", 0).theme_type_variation, &"")
	roster.mark("ilse")
	assert_eq(_marked_rows(roster.get_node("Scroll/Box/List")), [1] as Array[int])
	assert_eq(_visitor_card(roster, "WalkIn", 1).theme_type_variation, &"")
	await wait_process_frames(1)


# The visible rows of the Quests screen's board, in order.
func _visible_rows(board: QuestBoard) -> Array[Node]:
	var rows: Array[Node] = []
	for row: Node in board.get_node("Scroll/Box/List").get_children():
		if row is Container and (row as Control).visible:
			rows.append(row)
	return rows


func test_each_board_row_shows_its_time_left_which_a_tick_updates_without_rebuilding_the_rows() -> void:
	var board := _quests()
	# Filled at 1_000_000: moonherbs (F) leaves at 1_000_060, the wolves and the crypt (E) at
	# 1_000_120.
	var quests := Board.new()
	quests.reception_slots = 3
	quests.refill(_dispatch, 1_000_000, PackedInt64Array())
	assert_eq(quests.slots, PackedStringArray(["moonherbs", "wolves", "crypt"]))
	board.show_board(quests, _dispatch, 1_000_018)
	var rows := _visible_rows(board)
	assert_eq(rows.size(), 3)
	var meta := rows[0].find_child("Meta", true, false) as Label
	assert_eq(meta.text, "F · 0:06 · 10g · leaves 0:42")
	assert_eq((rows[1].find_child("Meta", true, false) as Label).text, "E · 0:10 · 22g · leaves 1:42")
	# A tick: the same rows, in the same order, the time left one second less.
	quests.refill(_dispatch, 1_000_019, PackedInt64Array())
	board.show_board(quests, _dispatch, 1_000_019)
	assert_eq(_visible_rows(board), rows)
	assert_same(rows[0].find_child("Meta", true, false), meta)
	assert_eq(meta.text, "F · 0:06 · 10g · leaves 0:41")
	# Moonherbs leaves: its row goes.
	quests.refill(_dispatch, 1_000_060, PackedInt64Array())
	board.show_board(quests, _dispatch, 1_000_060)
	assert_eq(_visible_rows(board), rows.slice(1))


func test_each_party_out_shows_its_quest_and_time_left_which_a_tick_updates_without_rebuilding_the_row() -> void:
	var board := _quests()
	assert_true(_dispatch.send("wolves", PackedStringArray(["bram", "ilse"]), 1, 1_000))
	board.show_board(Board.new(), _dispatch, 1_003)
	var rows := board.get_node("Scroll/Box/Out")
	assert_eq(rows.get_child_count(), 1)
	var row := rows.get_child(0)
	assert_has(_texts(row), "Wolves at the mill")
	assert_has(_texts(row), "0:07")
	assert_does_not_have(_texts(row), "22 gold")
	var bar := row.find_children("*", "ProgressBar", true, false)[0] as ProgressBar
	assert_eq(bar.value, 3.0)
	# A tick: the same row, its time and bar a second on.
	board.show_board(Board.new(), _dispatch, 1_004)
	assert_same(rows.get_child(0), row)
	assert_has(_texts(row), "0:06")
	assert_eq(bar.value, 4.0)


func test_the_picker_drops_a_quest_that_left_the_board_and_keeps_one_still_on_it() -> void:
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	var left: Array[bool] = []
	picker.quest_left.connect(func() -> void: left.append(true))
	var quests := Board.new()
	quests.reception_slots = 3
	quests.refill(_dispatch, 1_000_000, PackedInt64Array())
	picker.open("moonherbs", _dispatch, 1_000_000)
	quests.refill(_dispatch, 1_000_059, PackedInt64Array())
	picker.show_board(quests)
	assert_true(picker.has_quest())
	assert_true((picker.get_node("Root") as Control).visible)
	assert_eq(left, [] as Array[bool])
	# Moonherbs (F) leaves the board at 1_000_060: no Send, and the prompt for a quest.
	quests.refill(_dispatch, 1_000_060, PackedInt64Array())
	picker.show_board(quests)
	assert_false(picker.has_quest())
	assert_false((picker.get_node("Root") as Control).visible)
	assert_true((picker.get_node("Prompt") as Control).visible)
	assert_eq(left, [true] as Array[bool])
	picker.show_board(quests)
	assert_eq(left, [true] as Array[bool])
