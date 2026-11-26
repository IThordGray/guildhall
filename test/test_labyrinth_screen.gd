extends GutTest

const MainScript: GDScript = preload("res://main.gd")
const SAVE_PATH: String = "user://test_labyrinth_screen_save.cfg"
const UNLOCKED: PackedStringArray = ["auto", "sealed_gate", "labyrinth"]
const PAIR: PackedStringArray = ["bram", "tobin"]

var _dispatch: Dispatch
## The screens are put on a layer above GUT's own output window.
var _layer: CanvasLayer
## The game, while a test runs it.
var _main: Control = null


func before_each() -> void:
	# A new game's Bram and Tobin in one party and Ilse, hired, in a party of her own.
	_dispatch = Dispatch.new(1_000)
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	assert_true(_dispatch.adventurers.parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	_dispatch.adventurers.gear.stash_cap = 1_000
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)


func after_each() -> void:
	# Gone before the save path is the player's again, so no tick of it can save there.
	if _main != null:
		_main.free()
		_main = null
	MainScript.set("save_path", "user://save.cfg")
	DirAccess.remove_absolute(SAVE_PATH)


# The Labyrinth screen, with Touch as main.tscn has it.
func _screen() -> LabyrinthScreen:
	_layer.add_child(Touch.new())
	var screen := (load("res://screens/labyrinth.tscn") as PackedScene).instantiate() as LabyrinthScreen
	_layer.add_child(screen)
	return screen


func _floor_rows(screen: LabyrinthScreen) -> Array[Node]:
	return screen.get_node("Scroll/Box/Floors").get_children()


# The words of every label and button in `node` shown on screen, in tree order; a face's empty
# label left out.
func _shown_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for part: Node in node.find_children("*", "", true, false):
		if not (part is Label or part is Button) or not (part as Control).is_visible_in_tree():
			continue
		var text: String = (part as Label).text if part is Label else (part as Button).text
		if not text.is_empty():
			texts.append(text)
	return texts


# Each floor row as the words it shows.
func _rows(screen: LabyrinthScreen) -> Array:
	var rows := []
	for row: Node in _floor_rows(screen):
		rows.append(_shown_texts(row))
	return rows


# The values of the bars `node` shows, in tree order.
func _bars(node: Node) -> Array:
	var values := []
	for bar: Node in node.find_children("*", "ProgressBar", true, false):
		if (bar as Control).is_visible_in_tree():
			values.append(int((bar as ProgressBar).value))
	return values


# Whether `row`'s depth, name and meta line show dimmed.
func _dimmed(row: Node) -> bool:
	var top := row.get_child(0).get_child(0).get_child(0) as Control
	return top.modulate.a < 1.0


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


func test_the_screen_shows_each_material_and_each_floor_open_with_a_party_out_open_with_send_or_not_open_dimmed_with_what_opens_it() -> void:
	_dispatch.labyrinth.explored = {"floor_1": 60, "floor_2": 5}
	_dispatch.labyrinth.materials = {"Glowmoss": 7, "Riverglass": 1}
	assert_true(_dispatch.send("floor_1", ["ilse"], 1, 1_000))
	var screen := _screen()
	screen.show_labyrinth(_dispatch, UNLOCKED, 1_033)
	var ilses_party: String = _dispatch.adventurers.parties.parties[1]["name"]
	assert_eq(_rows(screen), [
		["1", "The Galleries", "E · 1:00 · 45g · Glowmoss", "60%", ilses_party, "0:27"],
		["2", "The Drowned Stair", "E · 1:30 · 60g · Riverglass", "5%", "Curse", "Navigation", "?", "Send ›"],
		["3", "The Third Ring", "D · 2:00 · 130g · Bone silver", "Opens when The Drowned Stair is 50% explored"],
	])
	var rows := _floor_rows(screen)
	# Explored, then the party's time out of 60 seconds.
	assert_eq(_bars(rows[0]), [60, 33])
	assert_eq(_bars(rows[1]), [5])
	assert_eq(_bars(rows[2]), [])
	assert_eq(rows[0].find_children("*", "TextureRect", true, false).size(), 1)
	assert_eq([_dimmed(rows[0]), _dimmed(rows[1]), _dimmed(rows[2])], [false, false, true])
	var materials := screen.get_node("Scroll/Box/Materials/Row")
	assert_eq(_shown_texts(materials), ["7", "Glowmoss", "1", "Riverglass", "0", "Bone silver"] as Array[String])
	var dimmed := []
	for material: Node in materials.get_children():
		dimmed.append((material as Control).modulate.a < 1.0)
	assert_eq(dimmed, [false, false, true])
	assert_eq((screen.get_node("Scroll/Box/Bonus") as Label).text, "A floor explored to 100% pays a one-time bonus: 60g · 100g · 200g.")


func test_a_floor_explored_to_100_percent_shows_cleared_in_place_of_its_percent_and_can_still_be_sent_to() -> void:
	_dispatch.labyrinth.explored = {"floor_1": 100, "floor_2": 95}
	var screen := _screen()
	screen.show_labyrinth(_dispatch, UNLOCKED, 1_000)
	var rows := _rows(screen)
	assert_eq(rows[0].slice(0, 4), ["1", "The Galleries", "E · 1:00 · 45g · Glowmoss", "Cleared"])
	assert_eq(rows[0][-1], "Send ›")
	assert_does_not_have(rows[0], "100%")
	assert_eq(rows[1][3], "95%")
	assert_eq(_bars(_floor_rows(screen)[0]), [100])


func test_the_rows_keep_up_as_time_passes_and_change_in_place_when_a_party_comes_home_a_challenge_is_revealed_or_a_floor_opens() -> void:
	# Whatever the outcome, the return takes it to half explored.
	_dispatch.labyrinth.explored = {"floor_1": 45}
	assert_true(_dispatch.send("floor_1", PAIR, 1, 1_000))
	var screen := _screen()
	screen.show_labyrinth(_dispatch, UNLOCKED, 1_010)
	var rows := _floor_rows(screen)
	var pair_name: String = _dispatch.adventurers.parties.parties[0]["name"]
	assert_eq(_rows(screen)[0], ["1", "The Galleries", "E · 1:00 · 45g · Glowmoss", "45%", pair_name, "0:50"])
	screen.show_labyrinth(_dispatch, UNLOCKED, 1_045)
	assert_eq(_rows(screen)[0][-1], "0:15")
	assert_eq(_bars(rows[0]), [45, 45])
	assert_eq(_dimmed(rows[1]), true)
	# Home: at least 5% more, the last challenge known, Send back, and the floor below open.
	_dispatch.checkpoint(1_060)
	screen.show_labyrinth(_dispatch, UNLOCKED, 1_060)
	var explored := _dispatch.labyrinth.explored_percent("floor_1")
	assert_gte(explored, 50)
	assert_eq(_rows(screen)[0], ["1", "The Galleries", "E · 1:00 · 45g · Glowmoss", "%d%%" % explored, "Traps", "Navigation", "Attrition", "Send ›"])
	assert_eq(_dimmed(rows[1]), false)
	assert_eq(_rows(screen)[1][-1], "Send ›")
	# The same rows, changed in place.
	assert_eq(_floor_rows(screen), rows)


func test_a_tap_on_an_open_floor_nobody_is_on_asks_to_send_a_party_there_and_a_tap_on_one_with_a_party_out_or_not_open_does_nothing() -> void:
	_dispatch.labyrinth.explored = {"floor_1": 60}
	assert_true(_dispatch.send("floor_1", ["ilse"], 1, 1_000))
	var screen := _screen()
	screen.show_labyrinth(_dispatch, UNLOCKED, 1_010)
	var asked: Array[String] = []
	screen.send_pressed.connect(asked.append)
	await wait_process_frames(1)
	var rows := _floor_rows(screen)
	_tap(_middle_of(rows[0] as Control))
	_tap(_middle_of(rows[2] as Control))
	assert_eq(asked, [] as Array[String])
	_tap(_middle_of(rows[1] as Control))
	assert_eq(asked, ["floor_2"] as Array[String])


# The game as main.tscn runs it, on a new game saved at SAVE_PATH.
func _new_game() -> Control:
	MainScript.set("save_path", SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Control
	_layer.add_child(_main)
	(_main.get_node("Start/Menu/Choices/NewGame") as Button).pressed.emit()
	return _main


func test_the_labyrinth_tab_stays_disabled_until_goals_unlock_the_labyrinth_and_then_opens_the_labyrinth_screen() -> void:
	var main := _new_game()
	var tab := main.get_node("TabBar/Tabs/Labyrinth") as Button
	var labyrinth := main.get_node("Body/Labyrinth") as Control
	var hall := main.get_node("Body/HallView") as Control
	await wait_process_frames(2)
	assert_true(tab.disabled)
	_tap(_middle_of(tab))
	assert_false(labyrinth.visible)
	assert_true(hall.visible)
	(main.get("_goals") as Goals).unlocked.append(Labyrinth.UNLOCK)
	(main.get_node("Tick") as Timer).timeout.emit()
	assert_false(tab.disabled)
	_tap(_middle_of(tab))
	assert_true(labyrinth.visible)
	assert_false(hall.visible)
	assert_eq(_shown_texts(labyrinth.get_node("Scroll/Box/Floors").get_child(0))[0], "1")
	# Away and back again.
	_tap(_middle_of(main.get_node("TabBar/Tabs/Hall") as Control))
	assert_false(labyrinth.visible)
	assert_true(hall.visible)


func test_a_tap_on_an_open_floor_opens_the_picker_for_it_whose_send_sends_by_hand_only_while_the_floor_is_open_and_goes_back_to_the_labyrinth() -> void:
	var main := _new_game()
	var goals := main.get("_goals") as Goals
	var dispatch := main.get("_dispatch") as Dispatch
	goals.unlocked.append(Labyrinth.UNLOCK)
	(main.get_node("Tick") as Timer).timeout.emit()
	var labyrinth := main.get_node("Body/Labyrinth") as LabyrinthScreen
	var picker := main.get_node("Body/PartyPicker") as PartyPicker
	await wait_process_frames(2)
	_tap(_middle_of(main.get_node("TabBar/Tabs/Labyrinth") as Control))
	await wait_process_frames(2)
	_tap(_middle_of(labyrinth.get_node("Scroll/Box/Floors").get_child(0) as Control))
	await wait_process_frames(2)
	# In portrait, a screen of its own with Back.
	assert_true(picker.visible)
	assert_false(labyrinth.visible)
	assert_eq(_shown_texts(picker.get_node("Root/Quest")).slice(0, 3), ["The Galleries", "Floor 1", "E · 1:00 · 45g · fail 0g"] as Array[String])
	assert_eq((picker.get_node("Root/Buttons/Cancel") as Button).text, "Back")
	var party: PackedStringArray = dispatch.adventurers.parties.parties[0]["members"]
	# A floor not open sends nobody, and the picker stays.
	picker.send_pressed.emit("floor_2", party)
	assert_eq(dispatch.outings.size(), 0)
	assert_true(picker.visible)
	_tap(_middle_of(picker.get_node("Root/Scroll/Box/List").get_child(0) as Control))
	await wait_process_frames(1)
	_tap(_middle_of(picker.get_node("Root/Buttons/Send") as Control))
	await wait_process_frames(1)
	assert_eq(dispatch.outings.size(), 1)
	assert_eq(dispatch.outings[0]["quest"], "floor_1")
	assert_eq(goals.out_by_hand, PackedStringArray([Goals.outing_key(dispatch.outings[0])]))
	assert_false(picker.visible)
	assert_true(labyrinth.visible)
	assert_has(_shown_texts(labyrinth.get_node("Scroll/Box/Floors").get_child(0)), dispatch.adventurers.parties.parties[0]["name"])
