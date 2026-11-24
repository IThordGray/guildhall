extends GutTest

const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]

var _dispatch: Dispatch
## The screens are put on a layer above GUT's own output window, with Touch as main.tscn has it.
var _layer: CanvasLayer


func before_each() -> void:
	_dispatch = Dispatch.new(1_000)
	_dispatch.adventurers = Adventurers.new(EVERYONE)
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_layer.add_child(Touch.new())


func _screen(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	_layer.add_child(screen)
	return screen


# The text of every label and button in `node`, visible or not, in tree order.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for part: Node in node.find_children("*", "", true, false):
		if part is Label:
			texts.append((part as Label).text)
		elif part is Button and not (part as Button).text.is_empty():
			texts.append((part as Button).text)
	return texts


# The names on each card of `roster`: its party's name, then its members', as rows show them.
func _cards(roster: Roster) -> Array:
	var cards := []
	for card: Node in roster.get_node("Scroll/Box/Parties").get_children():
		cards.append(_texts(card).filter(func(text: String) -> bool: return text.begins_with("The ") or text in ["Bram", "Ilse", "Tobin", "Maren"]))
	return cards


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


func test_the_roster_shows_a_card_per_party_named_and_ranked_over_its_members_then_the_reserves_shown_only_while_there_are_any() -> void:
	var parties := _dispatch.adventurers.parties
	var roster := _screen("res://screens/roster.tscn") as Roster
	var reserves := roster.get_node("Scroll/Box/Reserves") as Control
	var reserves_label := roster.get_node("Scroll/Box/ReservesHeader") as Control
	roster.show_dispatch(_dispatch, 1_000)
	var first: String = parties.parties[0]["name"]
	assert_eq(_cards(roster), [[first, "Bram", "Ilse", "Tobin", "Maren"]])
	assert_has(_texts(roster.get_node("Scroll/Box/Parties").get_child(0)), "F")
	assert_false(reserves.visible)
	assert_false(reserves_label.visible)
	assert_true(parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	assert_true(parties.move("tobin", Parties.RESERVES, _dispatch))
	_dispatch.adventurers.roster["ilse"]["rank"] = "E"
	roster.show_dispatch(_dispatch, 1_001)
	var second: String = parties.parties[1]["name"]
	assert_eq(_cards(roster), [[first, "Bram", "Maren"], [second, "Ilse"]])
	assert_has(_texts(roster.get_node("Scroll/Box/Parties").get_child(1)), "E")
	assert_true(reserves.visible)
	assert_true(reserves_label.visible)
	assert_eq(reserves.get_child_count(), 1)
	assert_has(_texts(reserves.get_child(0)), "Tobin")
	# Back in a party, the reserves hide again.
	assert_true(parties.move("tobin", parties.party_of("ilse"), _dispatch))
	roster.show_dispatch(_dispatch, 1_002)
	assert_eq(_cards(roster), [[first, "Bram", "Maren"], [second, "Ilse", "Tobin"]])
	assert_false(reserves.visible)
	await wait_process_frames(1)


func test_the_roster_rebuilds_its_cards_only_when_someone_moves_and_shows_a_new_name_or_rank_in_the_same_card() -> void:
	var parties := _dispatch.adventurers.parties
	var roster := _screen("res://screens/roster.tscn") as Roster
	var cards := roster.get_node("Scroll/Box/Parties")
	roster.show_dispatch(_dispatch, 1_000)
	var card := cards.get_child(0)
	roster.show_dispatch(_dispatch, 1_001)
	assert_same(cards.get_child(0), card)
	# A new name and a promotion change the card's words, not the card.
	var id: String = parties.parties[0]["id"]
	parties.rename(id, "Bram's Lot")
	for adventurer: String in EVERYONE:
		_dispatch.adventurers.roster[adventurer]["rank"] = "D"
	roster.show_dispatch(_dispatch, 1_002)
	assert_same(cards.get_child(0), card)
	assert_has(_texts(card), "Bram's Lot")
	assert_has(_texts(card), "D")
	# Someone moving builds the cards again.
	assert_true(parties.move("maren", Parties.RESERVES, _dispatch))
	roster.show_dispatch(_dispatch, 1_003)
	assert_ne(cards.get_child(0), card)
	await wait_process_frames(1)


func test_a_tap_on_a_partys_dice_asks_for_a_new_name_for_that_party() -> void:
	var parties := _dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	var roster := _screen("res://screens/roster.tscn") as Roster
	roster.show_dispatch(_dispatch, 1_000)
	var rolled: Array[String] = []
	roster.reroll_pressed.connect(func(party: String) -> void: rolled.append(party))
	await wait_process_frames(1)
	var second := roster.get_node("Scroll/Box/Parties").get_child(1)
	# The header's buttons: the name, then the dice.
	var dice := second.get_child(0).find_children("*", "Button", true, false)[1] as Button
	_tap(_middle_of(dice))
	assert_eq(rolled, [parties.party_of("ilse")] as Array[String])


func test_a_tap_on_a_partys_name_swaps_it_for_a_field_whose_enter_asks_to_keep_what_was_typed() -> void:
	var roster := _screen("res://screens/roster.tscn") as Roster
	roster.show_dispatch(_dispatch, 1_000)
	var typed: Array = []
	roster.name_typed.connect(func(party: String, text: String) -> void: typed.append([party, text]))
	await wait_process_frames(1)
	var header := roster.get_node("Scroll/Box/Parties").get_child(0).get_child(0)
	var name_button := header.find_children("*", "Button", true, false)[0] as Button
	var field := header.find_children("*", "LineEdit", true, false)[0] as LineEdit
	assert_false(field.visible)
	_tap(_middle_of(name_button))
	assert_true(field.visible)
	assert_false(name_button.visible)
	assert_true(field.has_focus())
	assert_eq(field.text, _dispatch.adventurers.parties.parties[0]["name"])
	assert_eq(field.max_length, Parties.NAME_MOST_CHARS)
	field.text = "Bram's Lot"
	field.text_submitted.emit(field.text)
	assert_eq(typed, [[_dispatch.adventurers.parties.parties[0]["id"], "Bram's Lot"]])
	assert_false(field.visible)
	assert_true(name_button.visible)


# The Adventurer screen showing `adventurer`, in landscape when `landscape`, where the tray takes
# the left column at the top, in view.
func _sheet(adventurer: String, landscape: bool = false) -> Adventurer:
	var sheet := _screen("res://screens/adventurer.tscn") as Adventurer
	sheet.set_landscape(landscape)
	sheet.show_adventurer(adventurer, _dispatch, Gold.new(0), 0, 1_000)
	return sheet


func _change(sheet: Adventurer) -> Button:
	return sheet.get_node("Box/Scroll/Content/Card/Header/Row/Words/PartyLine/Change") as Button


func _tray(sheet: Adventurer) -> Control:
	return sheet.find_child("Tray", true, false) as Control


# The open tray's title, or "" while none is open.
func _tray_title(sheet: Adventurer) -> String:
	return (_tray(sheet).get_node("Rows/Line/Title") as Label).text if _tray(sheet).is_visible_in_tree() else ""


# The tray's rows as shown now, without the refusal over them.
func _tray_rows(sheet: Adventurer) -> Array[Control]:
	var rows: Array[Control] = []
	for row: Node in _tray(sheet).get_node("Rows/List").get_children():
		if not row.is_queued_for_deletion() and not row is Label:
			rows.append(row)
	return rows


# The tray's refusal, or "" while there is none.
func _tray_refusal(sheet: Adventurer) -> String:
	for row: Node in _tray(sheet).get_node("Rows/List").get_children():
		if not row.is_queued_for_deletion() and row is Label:
			return (row as Label).text
	return ""


# The first line of each of the tray's rows, and where the one marked as theirs is.
func _row_titles(sheet: Adventurer) -> Array[String]:
	var titles: Array[String] = []
	for row: Control in _tray_rows(sheet):
		titles.append(_texts(row)[0])
	return titles


func _marked_row(sheet: Adventurer) -> int:
	var rows := _tray_rows(sheet)
	for at: int in rows.size():
		if rows[at] is PanelContainer and (rows[at] as PanelContainer).theme_type_variation == &"TrayRowPicked":
			return at
	return -1


func test_the_sheet_names_their_party_and_change_opens_a_tray_of_every_party_then_reserve_and_new_party_theirs_marked() -> void:
	var parties := _dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	var sheet := _sheet("ilse")
	var line := sheet.get_node("Box/Scroll/Content/Card/Header/Row/Words/PartyLine") as Control
	await wait_process_frames(1)
	assert_true(line.visible)
	assert_eq((line.get_node("Name") as Label).text, parties.parties[1]["name"])
	assert_eq(_tray_title(sheet), "")
	_tap(_middle_of(_change(sheet)))
	assert_eq(_tray_title(sheet), "PARTY · ILSE")
	assert_eq(_row_titles(sheet), [parties.parties[0]["name"], parties.parties[1]["name"], "Reserve", "+ New party"] as Array[String])
	assert_eq(_marked_row(sheet), 1)
	# Each party's row shows its rank and its members' faces.
	assert_has(_texts(_tray_rows(sheet)[0]), "F")
	assert_eq(_tray_rows(sheet)[0].find_children("*", "TextureRect", true, false).size(), 3)
	# Change again closes it.
	_tap(_middle_of(_change(sheet)))
	assert_eq(_tray_title(sheet), "")
	# In reserve, the line says so and Reserve is marked.
	assert_true(parties.move("ilse", Parties.RESERVES, _dispatch))
	sheet.show_adventurer("ilse", _dispatch, Gold.new(0), 0, 1_000)
	assert_eq((line.get_node("Name") as Label).text, "Reserve")
	_tap(_middle_of(_change(sheet)))
	assert_eq(_row_titles(sheet), [parties.parties[0]["name"], "Reserve", "+ New party"] as Array[String])
	assert_eq(_marked_row(sheet), 1)
	# A candidate has no party.
	sheet.show_visitor(Recruits.candidate_for(0, 1_000_000, PackedStringArray()), false, "", true)
	assert_false(line.visible)
	assert_eq(_tray_title(sheet), "")
	sheet.show_adventurer("bram", _dispatch, Gold.new(0), 0, 1_000)
	assert_true(line.visible)
	await wait_process_frames(1)


func test_a_tap_on_a_party_row_asks_to_move_them_there_or_shows_why_not_in_the_tray_which_stays_open() -> void:
	var parties := _dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	var sheet := _sheet("ilse", true)
	var moves: Array = []
	sheet.party_pressed.connect(func(adventurer: String, to: String) -> void: moves.append([adventurer, to]))
	await wait_process_frames(1)
	_tap(_middle_of(_change(sheet)))
	await wait_process_frames(1)
	# Into Bram's party, everyone home.
	_tap(_middle_of(_tray_rows(sheet)[0]))
	assert_eq(moves, [["ilse", parties.parties[0]["id"]]])
	assert_eq(_tray_refusal(sheet), "")
	# With Bram's party out, the same tap is refused, saying why, and the tray stays open.
	assert_true(_dispatch.send("rats", PackedStringArray(["bram", "tobin", "maren"]), 1, 1_000))
	_tap(_middle_of(_tray_rows(sheet)[0]))
	assert_eq(moves.size(), 1)
	assert_eq(_tray_refusal(sheet), "Bram is out on a quest")
	assert_eq(_tray_title(sheet), "PARTY · ILSE")
	await wait_process_frames(1)
	# Reserve, not touching Bram's party, still asks; the reason goes.
	_tap(_middle_of(_tray_rows(sheet)[2]))
	assert_eq(moves, [["ilse", parties.parties[0]["id"]], ["ilse", Parties.RESERVES]])
	assert_eq(_tray_refusal(sheet), "")
	assert_eq(_tray_title(sheet), "PARTY · ILSE")
	# The row they are in asks nothing.
	await wait_process_frames(1)
	_tap(_middle_of(_tray_rows(sheet)[1]))
	assert_eq(moves.size(), 2)


func test_opening_the_party_tray_closes_a_gear_tray_and_a_gear_slot_closes_the_party_tray() -> void:
	var sheet := _sheet("ilse", true)
	await wait_process_frames(1)
	# The second slot is Clothes.
	var clothes := sheet.get_node("Box/Scroll/Content/GearColumn/Gear").get_child(1) as Control
	_tap(_middle_of(clothes))
	assert_eq(_tray_title(sheet), "CLOTHES · ILSE")
	await wait_process_frames(1)
	_tap(_middle_of(_change(sheet)))
	assert_eq(_tray_title(sheet), "PARTY · ILSE")
	await wait_process_frames(1)
	clothes = sheet.get_node("Box/Scroll/Content/GearColumn/Gear").get_child(1) as Control
	_tap(_middle_of(clothes))
	assert_eq(_tray_title(sheet), "CLOTHES · ILSE")
	await wait_process_frames(1)
	_tap(_middle_of(_change(sheet)))
	_tap(_middle_of(_tray(sheet).get_node("Rows/Line/Done") as Control))
	assert_eq(_tray_title(sheet), "")
