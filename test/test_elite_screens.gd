extends GutTest

const MainScript: GDScript = preload("res://main.gd")
const SAVE_PATH: String = "user://test_elite_screens_save.cfg"
const UNLOCKED: PackedStringArray = ["auto", "sealed_gate", "labyrinth"]
const PAIR: PackedStringArray = ["bram", "tobin"]
## The guild reaches rank C inside period 1, so period 2's window, 1_440 to 1_680, is its first.
const RANK_C_AT: int = 1_000
const OPENS: int = 1_440
const CRYPT: String = "The flooded crypt of The Drowned Stair"
const VAULT: String = "The sealed vault of The Galleries"
const WARNING: String = "Deadly · if it fails, anyone brought to 0 health dies"
## The failure colour, as Needs you's count and a challenge not met show it.
const FAILURE_COLOR: Color = Color(0.9373, 0.4784, 0.3843)

var _dispatch: Dispatch
## The screens are put on a layer above GUT's own output window.
var _layer: CanvasLayer
## The game, while a test runs it.
var _main: Control = null
## The window's size and design size before the test, which a test that turns the window puts
## back.
var _window_size: Vector2i
var _content_size: Vector2i


func before_each() -> void:
	# A new game's Bram and Tobin in one party and Ilse, hired, in a party of her own, everyone rank D
	# so a rank C elite takes them; period 2's elite is The Drowned Stair's.
	_dispatch = Dispatch.new(1_000)
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	assert_true(_dispatch.adventurers.parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	_rank_d(_dispatch)
	_dispatch.adventurers.gear.stash_cap = 1_000
	_dispatch.labyrinth.elite_seed = _elite_seed(2, "floor_2")
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_window_size = get_window().size
	_content_size = get_window().content_scale_size


func after_each() -> void:
	# Gone before the save path is the player's again, so no tick of it can save there.
	if _main != null:
		_main.free()
		_main = null
	get_window().size = _window_size
	get_window().content_scale_size = _content_size
	MainScript.set("save_path", "user://save.cfg")
	DirAccess.remove_absolute(SAVE_PATH)


func _rank_d(dispatch: Dispatch) -> void:
	for adventurer: String in dispatch.adventurers.roster:
		dispatch.adventurers.roster[adventurer]["rank"] = "D"


# An elite seed with which period `period`'s elite is on `floor_id`, and the next period's on `next`
# unless that is "".
func _elite_seed(period: int, floor_id: String, next: String = "") -> int:
	var labyrinth := Labyrinth.new()
	for each: int in 10_000:
		labyrinth.elite_seed = each
		if labyrinth.elite_floor(period) == floor_id and (next.is_empty() or labyrinth.elite_floor(period + 1) == next):
			return each
	fail_test("no elite seed found")
	return -1


# A roll seed with which `party` of `dispatch` fails `quest` and each of them takes damage, so those
# at 1 health die.
func _deadly_seed(dispatch: Dispatch, quest: String, party: PackedStringArray) -> int:
	var luck := dispatch.party_stat(party, "luck")
	var spirit := dispatch.party_stat(party, "spirit")
	for roll_seed: int in 10_000:
		var lucky: bool = Outcome.lucky_break(roll_seed, luck) and dispatch.challenge_chances(quest, party).min() < Outcome.EVEN_CHANCE
		var outcome := Outcome.roll(roll_seed, dispatch.success_chance(quest, party, lucky), Outcome.MOST_DAMAGE["C"], party, spirit, luck)
		var hurt := 0
		for adventurer: String in party:
			hurt += 1 if int(outcome.damage[adventurer]) >= 1 else 0
		if not outcome.success and hurt == party.size():
			return roll_seed
	fail_test("no deadly seed found")
	return -1


# The Labyrinth screen, with Touch as main.tscn has it.
func _screen() -> LabyrinthScreen:
	_layer.add_child(Touch.new())
	var screen := (load("res://screens/labyrinth.tscn") as PackedScene).instantiate() as LabyrinthScreen
	_layer.add_child(screen)
	return screen


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


# The elite rows shown under DEADLY, each as the words it shows.
func _deadly_rows(labyrinth: Node) -> Array:
	var rows := []
	for row: Node in labyrinth.get_node("Scroll/Box/Deadly").get_children():
		if (row as Control).is_visible_in_tree():
			rows.append(_shown_texts(row))
	return rows


func _deadly_row(labyrinth: Node) -> Control:
	for row: Node in labyrinth.get_node("Scroll/Box/Deadly").get_children():
		if (row as Control).is_visible_in_tree():
			return row
	return null


# The values of the bars `node` shows, in tree order.
func _bars(node: Node) -> Array:
	var values := []
	for bar: Node in node.find_children("*", "ProgressBar", true, false):
		if (bar as Control).is_visible_in_tree():
			values.append(int((bar as ProgressBar).value))
	return values


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


func test_with_an_elite_open_the_labyrinth_shows_a_deadly_row_with_time_left_and_when_the_window_closes_unsent_the_row_goes() -> void:
	var screen := _screen()
	var section := screen.get_node("Scroll/Box/DeadlySection") as Label
	var floors := screen.get_node("Scroll/Box/Floors")
	# Before the window, and in it before rank C: no section, but the floors.
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS - 1, RANK_C_AT)
	assert_false(section.visible)
	assert_eq(_deadly_rows(screen), [])
	assert_eq(_shown_texts(floors.get_child(0)).slice(0, 2), ["1", "The Galleries"] as Array[String])
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 60)
	assert_false(section.visible)
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 60, RANK_C_AT)
	assert_true(section.visible)
	assert_eq(section.text, "DEADLY")
	assert_true(section.get_theme_color(&"font_color").is_equal_approx(FAILURE_COLOR))
	assert_eq(_deadly_rows(screen), [[CRYPT, "Deadly", "C · 2:30 · 180g · closes in 3:00", "Curse", "Navigation", "Attrition", "Send ›"]])
	var tag := _deadly_row(screen).find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.text == "Deadly")[0] as Label
	assert_true(tag.get_theme_color(&"font_color").is_equal_approx(FAILURE_COLOR))
	# Above the floors.
	assert_lt(section.get_index(), floors.get_index())
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 239, RANK_C_AT)
	assert_eq(_deadly_rows(screen)[0][2], "C · 2:30 · 180g · closes in 0:01")
	# Closed unsent: the section goes, the floors stay.
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 240, RANK_C_AT)
	assert_false(section.visible)
	assert_eq(_deadly_rows(screen), [])
	assert_eq(_shown_texts(floors.get_child(0)).slice(0, 2), ["1", "The Galleries"] as Array[String])


func test_with_a_party_out_on_the_elite_the_deadly_row_shows_the_party_and_its_time_left_past_the_window_until_it_is_home() -> void:
	assert_true(_dispatch.send("elite_2", PAIR, 1, OPENS + 200))
	var screen := _screen()
	var section := screen.get_node("Scroll/Box/DeadlySection") as Control
	var pair_name: String = _dispatch.adventurers.parties.parties[0]["name"]
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 230, RANK_C_AT)
	assert_eq(_deadly_rows(screen), [[CRYPT, "Deadly", "C · 2:30 · 180g", pair_name, "2:00"]])
	# 30 of its 150 seconds, and both faces.
	assert_eq(_bars(_deadly_row(screen)), [30])
	assert_eq(_deadly_row(screen).find_children("*", "TextureRect", true, false).size(), 2)
	# Past the window it is still out.
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 250, RANK_C_AT)
	assert_true(section.visible)
	assert_eq(_deadly_rows(screen)[0][-1], "1:40")
	# Home: nothing open, nobody out.
	_dispatch.checkpoint(OPENS + 350)
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 350, RANK_C_AT)
	assert_false(section.visible)
	assert_eq(_deadly_rows(screen), [])


func test_a_tap_on_the_open_elite_asks_to_send_a_party_on_it_and_a_tap_while_a_party_is_out_on_it_does_nothing() -> void:
	var screen := _screen()
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 60, RANK_C_AT)
	var asked: Array[String] = []
	screen.send_pressed.connect(asked.append)
	await wait_process_frames(1)
	_tap(_middle_of(_deadly_row(screen)))
	assert_eq(asked, ["elite_2"] as Array[String])
	assert_true(_dispatch.send("elite_2", ["ilse"], 1, OPENS + 60))
	screen.show_labyrinth(_dispatch, UNLOCKED, OPENS + 61, RANK_C_AT)
	await wait_process_frames(1)
	_tap(_middle_of(_deadly_row(screen)))
	assert_eq(asked, ["elite_2"] as Array[String])


func test_the_picker_on_an_elite_shows_the_deadly_tag_and_warning_in_the_failure_colour_and_on_a_floor_neither() -> void:
	var picker := (load("res://screens/party_picker.tscn") as PackedScene).instantiate() as PartyPicker
	_layer.add_child(picker)
	picker.open("elite_2", _dispatch, OPENS + 60)
	var quest := picker.get_node("Root/Quest")
	assert_eq(_shown_texts(quest).slice(0, 5), [CRYPT, "Deadly", "C · 2:30 · 180g · fail 0g", WARNING, "Curse"] as Array[String])
	var warning := picker.get_node("Root/Quest/Box/DeadlyLine") as Label
	assert_true(warning.get_theme_color(&"font_color").is_equal_approx(FAILURE_COLOR))
	picker.open("floor_1", _dispatch, OPENS + 60)
	assert_eq(_shown_texts(quest).slice(0, 2), ["The Galleries", "Floor 1"] as Array[String])
	assert_does_not_have(_shown_texts(quest), "Deadly")
	assert_does_not_have(_shown_texts(quest), WARNING)


# The game as main.tscn runs it, on a new game saved at SAVE_PATH, everyone rank D and the
# labyrinth open.
func _new_game() -> Control:
	MainScript.set("save_path", SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Control
	_layer.add_child(_main)
	(_main.get_node("Start/Menu/Choices/NewGame") as Button).pressed.emit()
	_rank_d(_main.get("_dispatch") as Dispatch)
	(_main.get("_goals") as Goals).unlocked.append(Labyrinth.UNLOCK)
	_tick()
	return _main


func _tick() -> void:
	(_main.get_node("Tick") as Timer).timeout.emit()


# Sets the game's clock to `at` and ticks.
func _at(at: int) -> void:
	_main.set("_clock", GameClock.new(at - Time.get_unix_time_from_system()))
	_tick()


func _now() -> int:
	return _main.call("_now")


# The first period whose elite window is wholly ahead of the game's clock.
func _next_period() -> int:
	return Labyrinth.elite_period(_now()) + 2


func _tab(tab: String) -> void:
	await wait_process_frames(2)
	_tap(_middle_of(_main.get_node("TabBar/Tabs/" + tab) as Control))
	await wait_process_frames(2)


func test_on_the_labyrinth_tab_a_tap_on_the_open_elite_opens_the_picker_whose_send_sends_only_while_it_is_open() -> void:
	var main := _new_game()
	var dispatch := main.get("_dispatch") as Dispatch
	var labyrinth := main.get_node("Body/Labyrinth") as LabyrinthScreen
	var picker := main.get_node("Body/PartyPicker") as PartyPicker
	var period := _next_period()
	var opens := period * Labyrinth.ELITE_EVERY
	(main.get("_hall") as Hall).ranked_at["C"] = opens - 1
	dispatch.labyrinth.elite_seed = _elite_seed(period, "floor_2", "floor_1")
	_at(opens + 5)
	await _tab("Labyrinth")
	assert_eq(_deadly_rows(labyrinth).size(), 1)
	assert_eq(_deadly_rows(labyrinth)[0][0], CRYPT)
	_tap(_middle_of(_deadly_row(labyrinth)))
	await wait_process_frames(2)
	assert_true(picker.visible)
	assert_false(labyrinth.visible)
	assert_eq(_shown_texts(picker.get_node("Root/Quest")).slice(0, 4), [CRYPT, "Deadly", "C · 2:30 · 180g · fail 0g", WARNING] as Array[String])
	var party: PackedStringArray = dispatch.adventurers.parties.parties[0]["members"]
	# An elite not open sends nobody, and the picker stays, a tick later too.
	picker.send_pressed.emit("elite_1", party)
	assert_eq(dispatch.outings.size(), 0)
	_tick()
	assert_true(picker.visible)
	# Once the window closes the picker drops it and the row goes; Send then sends nobody.
	_at(opens + Labyrinth.ELITE_WINDOW + 5)
	await wait_process_frames(2)
	assert_false(picker.visible)
	assert_true(labyrinth.visible)
	assert_eq(_deadly_rows(labyrinth), [])
	picker.send_pressed.emit("elite_2", party)
	assert_eq(dispatch.outings.size(), 0)
	# The next window's elite, sent by hand.
	_at(opens + Labyrinth.ELITE_EVERY + 5)
	await wait_process_frames(2)
	assert_eq(_deadly_rows(labyrinth)[0][0], VAULT)
	_tap(_middle_of(_deadly_row(labyrinth)))
	await wait_process_frames(2)
	_tap(_middle_of(picker.get_node("Root/Scroll/Box/List").get_child(0) as Control))
	await wait_process_frames(1)
	_tap(_middle_of(picker.get_node("Root/Buttons/Send") as Control))
	await wait_process_frames(2)
	assert_eq(dispatch.outings.size(), 1)
	assert_eq(dispatch.outings[0]["quest"], "elite_1")
	assert_false(picker.visible)
	assert_true(labyrinth.visible)
	assert_has(_deadly_rows(labyrinth)[0], dispatch.adventurers.parties.parties[0]["name"])


# Sends `party` of the game on elite_2 to fail, those in `dying` at 1 health so they die, the rest at
# full health and tough enough to live, and ticks once it is home.
func _kill(party: PackedStringArray, dying: PackedStringArray) -> void:
	var dispatch := _main.get("_dispatch") as Dispatch
	var now := _now()
	for adventurer: String in party:
		if adventurer in dying:
			dispatch.wounds[adventurer] = {"health": 1, "at": now}
		else:
			dispatch.adventurers.levels[adventurer] = 40
	assert_true(dispatch.send("elite_2", party, _deadly_seed(dispatch, "elite_2", party), now))
	_at(now + 151)
	for adventurer: String in party:
		assert_eq(dispatch.adventurers.roster.has(adventurer), adventurer not in dying, adventurer)


func _needs_you_rows() -> Array:
	var rows := []
	for row: Node in _main.get_node("Body/QuestBoard/Scroll/Box/NeedsYou").get_children():
		rows.append(_shown_texts(row))
	return rows


func test_a_party_home_from_a_failed_elite_adds_a_fell_row_per_death_counted_on_the_quests_tab_which_the_player_clears_and_which_stays_cleared_after_save_and_load() -> void:
	var main := _new_game()
	var badge := main.get_node("TabBar/Tabs/Quests/Badge") as Label
	var count := main.get_node("Body/QuestBoard/Scroll/Box/NeedsYouHeader/Count") as Label
	var rows := main.get_node("Body/QuestBoard/Scroll/Box/NeedsYou")
	assert_false(badge.visible)
	_kill(PAIR, PAIR)
	await _tab("Quests")
	# Their gear filled the stash, so the elite's loot waits too, its party named by nobody.
	var shown := _needs_you_rows()
	assert_eq(shown.slice(0, 2), [["B", "Bram fell", CRYPT, "OK"], ["T", "Tobin fell", CRYPT, "OK"]])
	assert_eq(shown.size(), 3)
	assert_eq(shown[2][0], "Stash full")
	assert_true(badge.visible)
	assert_eq(badge.text, "3")
	assert_eq(count.text, "3")
	# A tap anywhere on a row clears it, and only it, for good.
	_tap(_middle_of(rows.get_child(0) as Control))
	await wait_process_frames(2)
	assert_eq(_needs_you_rows()[0], ["T", "Tobin fell", CRYPT, "OK"])
	assert_eq(_needs_you_rows().size(), 2)
	assert_eq(badge.text, "2")
	var saved := Dispatch.load_or_start(SAVE_PATH, _now())
	assert_eq(saved.fallen.size(), 2)
	assert_eq(saved.unseen_fallen(), PackedInt32Array([1]))
	assert_eq(saved.needs_you_count(), 2)
	_tap(_middle_of(rows.get_child(0) as Control))
	await wait_process_frames(2)
	assert_eq(_needs_you_rows().size(), 1)
	assert_eq(_needs_you_rows()[0][0], "Stash full")
	assert_eq(badge.text, "1")
	assert_eq(count.text, "1")
	var loaded := Dispatch.load_or_start(SAVE_PATH, _now())
	assert_eq(loaded.fallen.size(), 2)
	assert_eq(loaded.unseen_fallen(), PackedInt32Array())
	assert_eq(loaded.needs_you_count(), 1)


func test_loot_waiting_whose_party_is_all_dead_shows_with_no_names() -> void:
	var board := (load("res://screens/quest_board.tscn") as PackedScene).instantiate() as QuestBoard
	_layer.add_child(board)
	_dispatch.adventurers.gear.stash = PackedStringArray(["belt"])
	_dispatch.waiting_loot.append({"quest": "elite_2", "party": PAIR, "item": "goblin_bone_helm"})
	_dispatch.adventurers.remove("bram")
	_dispatch.adventurers.remove("tobin")
	board.show_board(Board.new(), _dispatch, 1_000)
	var rows := board.get_node("Scroll/Box/NeedsYou")
	assert_eq(_shown_texts(rows.get_child(0)), ["Stash full", CRYPT + " brought Goblin-bone helm", "Decide ›"] as Array[String])
	(rows.get_child(0).find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text == "Decide ›")[0] as Button).pressed.emit()
	assert_eq(_shown_texts(rows.get_child(0)).slice(0, 2), ["Stash full", CRYPT] as Array[String])


# Turns the window wider than tall when `landscape`, else taller than wide.
func _turn(landscape: bool) -> void:
	get_window().size = Vector2i(1920, 1080) if landscape else Vector2i(1080, 1920)
	await wait_process_frames(2)
	assert_eq(_main.get("_landscape"), landscape)


# Where among the roster's rows the ones marked as the one shown beside it are.
func _marked_rows() -> Array[int]:
	var marked: Array[int] = []
	var at := 0
	for button: Node in _main.get_node("Body/Roster").find_children("*", "Button", true, false):
		if (button as Button).theme_type_variation == &"ListRowChosen":
			marked.append(at)
		at += 1
	return marked


func _shown_name() -> String:
	return (_main.get_node("Body/Adventurer/Box/Scroll/Content/Card/Header/Row/Words/NameLine/Name") as Label).text


func test_if_the_adventurer_on_screen_dies_the_roster_shows_instead_in_portrait_and_the_first_left_beside_it_in_landscape() -> void:
	var main := _new_game()
	var roster := main.get_node("Body/Roster") as Control
	var adventurer := main.get_node("Body/Adventurer") as Control
	(main.get("_dispatch") as Dispatch).adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	_rank_d(main.get("_dispatch") as Dispatch)
	await _turn(false)
	await _tab("Roster")
	main.call("_open_adventurer", "bram", roster)
	assert_true(adventurer.visible)
	assert_false(roster.visible)
	# Asked to dismiss him, which his death then closes.
	var sheet := main.get_node("ConfirmSheet") as Control
	main.call("_on_dismiss_pressed", "bram")
	assert_true(sheet.visible)
	_kill(PAIR, ["bram"])
	assert_false(sheet.visible)
	assert_false(adventurer.visible)
	assert_true(roster.visible)
	# In landscape, the first left beside the roster, marked.
	main.call("_open_adventurer", "tobin", roster)
	await _turn(true)
	assert_true(adventurer.visible)
	assert_eq(_shown_name(), "Tobin")
	_kill(["tobin"], ["tobin"])
	assert_true(adventurer.visible)
	assert_true(roster.visible)
	assert_eq(_shown_name(), "Ilse")
	assert_eq(_marked_rows().size(), 1)


func test_if_the_adventurer_whose_level_up_shows_dies_continue_shows_the_roster() -> void:
	var main := _new_game()
	var dispatch := main.get("_dispatch") as Dispatch
	var roster := main.get_node("Body/Roster") as Control
	var adventurer := main.get_node("Body/Adventurer") as Control
	var level_up := main.get_node("Body/LevelUp") as LevelUp
	dispatch.adventurers.xp["bram"] = dispatch.adventurers.xp_needed("bram")
	await _tab("Roster")
	main.call("_open_adventurer", "bram", roster)
	main.call("_on_level_up_pressed", "bram")
	assert_true(level_up.visible)
	_kill(PAIR, ["bram"])
	level_up.continue_pressed.emit()
	assert_false(level_up.visible)
	assert_false(adventurer.visible)
	assert_true(roster.visible)


func test_if_everyone_dies_no_screen_crashes_and_the_roster_shows_with_no_one_selected_in_portrait_and_landscape() -> void:
	for landscape: bool in [false, true]:
		var main := _new_game()
		await _turn(landscape)
		var roster := main.get_node("Body/Roster") as Control
		var adventurer := main.get_node("Body/Adventurer") as Control
		await _tab("Roster")
		main.call("_open_adventurer", "bram", roster)
		assert_true(adventurer.visible)
		_kill(PAIR, PAIR)
		assert_eq((main.get("_dispatch") as Dispatch).adventurers.roster.size(), 0)
		assert_false(adventurer.visible, str(landscape))
		assert_true(roster.visible, str(landscape))
		assert_eq(_marked_rows(), [] as Array[int], str(landscape))
		for tab: String in ["Hall", "Quests", "Labyrinth", "Roster"]:
			await _tab(tab)
			_tick()
		assert_true(roster.visible, str(landscape))
		assert_false(adventurer.visible, str(landscape))
		# A candidate shown who leaves goes back to the roster, nobody beside it.
		var recruits := main.get("_recruits") as Recruits
		assert_gt(recruits.candidates.size(), 0)
		main.call("_open_visitor", 0)
		assert_true(adventurer.visible, str(landscape))
		recruits.candidates[0] = {}
		recruits.refill_at[0] = _now() + 10_000
		_tick()
		assert_false(adventurer.visible, str(landscape))
		assert_true(roster.visible, str(landscape))
		assert_eq(_marked_rows(), [] as Array[int], str(landscape))
		# Turning the window with nobody left.
		await _turn(not landscape)
		_tick()
		assert_true(roster.visible, str(landscape))
		_main.free()
		_main = null
		get_window().size = _window_size
		get_window().content_scale_size = _content_size
