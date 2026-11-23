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


func test_a_debrief_naming_someone_who_has_left_shows_the_rest_of_its_party_and_its_reward() -> void:
	assert_true(_dispatch.send("rats", PackedStringArray(["bram", "ilse"]), 1, 1_000))
	_dispatch.checkpoint(1_100)
	_dispatch.adventurers.remove("ilse")
	var debrief := _screen("res://screens/debrief.tscn") as Debrief
	debrief.show_debrief(_dispatch.debriefs[0], _dispatch)
	var members := debrief.get_node("Scroll/Box/Who/Members")
	assert_eq(members.get_child_count(), 1)
	assert_has(_texts(members), "Bram")
	assert_does_not_have(_texts(members), "Ilse")
	assert_has(_texts(debrief), "+%d" % _dispatch.debriefs[0]["gold"])
	await wait_process_frames(1)
