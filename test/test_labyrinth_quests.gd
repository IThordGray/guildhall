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


# A board of `quests` in that order, each put there at `at`.
func _board(quests: Array[String], at: int) -> Board:
	var board := Board.new()
	board.reception_slots = quests.size()
	board.slots = PackedStringArray(quests)
	board.refill_at.resize(quests.size())
	board.filled_at.resize(quests.size())
	board.filled_at.fill(at)
	board.checked_at = at
	return board


# The text of every label in `node` shown on screen, in tree order.
func _shown_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			texts.append((label as Label).text)
	return texts


# The shown texts of each visible board row, in order.
func _rows(board: QuestBoard) -> Array:
	var rows := []
	for row: Node in board.get_node("Scroll/Box/List").get_children():
		if (row as Control).visible:
			rows.append(_shown_texts(row))
	return rows


func test_exactly_pilgrims_maze_and_minotaur_are_labyrinth_quests_and_the_board_draws_them_like_any_quest_of_their_rank() -> void:
	var labyrinth: Array[String] = []
	for quest: String in Dispatch.QUESTS:
		if Dispatch.is_labyrinth(quest):
			labyrinth.append(quest)
	assert_eq(labyrinth, ["pilgrims", "maze", "minotaur"] as Array[String])
	# A rank E guild of rank E adventurers draws each as often as any other quest of its rank.
	var ranked := Adventurers.new(EVERYONE)
	for adventurer: String in EVERYONE:
		ranked.roster[adventurer]["rank"] = "E"
	for pair: Array in [["pilgrims", "wolves"], ["maze", "chapel"], ["minotaur", "chapel"]]:
		var chance := Board.draw_chance(pair[0], ranked, "E")
		assert_gt(chance, 0.0, pair[0])
		assert_almost_eq(chance, Board.draw_chance(pair[1], ranked, "E"), 1e-9, pair[0])
	# Auto takes one: the four starters' one party, on Bold, prefers it to the poorer rats.
	var parties := _dispatch.adventurers.parties
	var id := parties.party_of("bram")
	assert_eq(parties.party(id)["members"], EVERYONE)
	parties.set_auto(id, true)
	parties.set_mode(id, Parties.BOLD)
	assert_eq(Auto.pick(_dispatch, _board(["rats", "pilgrims"], 1_000), id, 1_000), "pilgrims")


func test_a_labyrinth_quests_board_row_and_picker_show_the_labyrinth_tag_and_other_quests_do_not() -> void:
	var board := _screen("res://screens/quest_board.tscn") as QuestBoard
	board.show_board(_board(["maze", "wolves"], 1_000), _dispatch, 1_000)
	var rows := _rows(board)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0].slice(0, 2), ["Map the shifting maze", "Labyrinth"])
	assert_eq(rows[1][0], "Wolves at the mill")
	assert_does_not_have(rows[1], "Labyrinth")
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	var card := picker.get_node("Root/Quest")
	picker.open("pilgrims", _dispatch, 1_000)
	assert_eq(_shown_texts(card).slice(0, 3), ["Guard pilgrims through the low halls", "Labyrinth", "E · 0:18 · 38g · fail 0g"] as Array[String])
	for quest: String in ["wolves", "sealed_gate", "floor_1"]:
		picker.open(quest, _dispatch, 1_000)
		assert_eq(_shown_texts(card)[0], Dispatch.QUESTS[quest]["name"])
		assert_does_not_have(_shown_texts(card), "Labyrinth", quest)


func test_a_row_whose_quest_changes_from_a_labyrinth_quest_to_another_and_back_shows_the_tag_only_while_it_is_one() -> void:
	var board := _screen("res://screens/quest_board.tscn") as QuestBoard
	board.show_board(_board(["minotaur"], 1_000), _dispatch, 1_000)
	assert_eq(_rows(board), [["Slay the minotaur of the third ring", "Labyrinth", "D · 0:40 · 113g · leaves 4:00", "Brute force", "?", "›"]])
	board.show_board(_board(["wolves"], 1_000), _dispatch, 1_000)
	assert_eq(_rows(board), [["Wolves at the mill", "E · 0:10 · 22g · leaves 2:00", "Brute force", "?", "›"]])
	board.show_board(_board(["pilgrims"], 1_000), _dispatch, 1_000)
	assert_eq(_rows(board), [["Guard pilgrims through the low halls", "Labyrinth", "E · 0:18 · 38g · leaves 2:00", "Protect", "?", "›"]])
	var picker := _screen("res://screens/party_picker.tscn") as PartyPicker
	var card := picker.get_node("Root/Quest")
	picker.open("maze", _dispatch, 1_000)
	assert_has(_shown_texts(card), "Labyrinth")
	picker.open("wolves", _dispatch, 1_000)
	assert_does_not_have(_shown_texts(card), "Labyrinth")
	assert_has(_shown_texts(card), "Wolves at the mill")
	picker.open("maze", _dispatch, 1_000)
	assert_has(_shown_texts(card), "Labyrinth")
