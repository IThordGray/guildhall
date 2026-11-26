extends GutTest

## Shown chance low ends these tests are built on (Dispatch.chance_range), for Bram and Tobin, rank D,
## every stat 18: elites 49 to 54, wyrm 54, vault 62; every stat 22: elites 83 to 85. Gold: elite_1
## 135, elite_2 180, elite_3 390, wyrm 210, vault 150.

const ELITES: PackedStringArray = ["elite_1", "elite_2", "elite_3"]
const RANK_C_AT: int = 1_000
## The elite floors are drawn from this, so the periods each opens in are always the same.
const ELITE_SEED: int = 11

var _dispatch: Dispatch
var _parties: Parties
## Bram and Tobin's party, then Ilse's.
var _first: String
var _second: String
## The screens are put on a layer above GUT's own output window, with Touch as main.tscn has it.
var _layer: CanvasLayer


func before_each() -> void:
	_guild(0, 18)


# A guild at `at` of Bram and Tobin in one party and Ilse in a party of her own, everyone rank D with
# every stat at `stat`, the stash with room for all loot, and elites drawn from ELITE_SEED.
func _guild(at: int, stat: int) -> void:
	# The same party names each time.
	seed(7)
	_dispatch = Dispatch.new(at)
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	_parties = _dispatch.adventurers.parties
	assert_true(_parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	for adventurer: String in _dispatch.adventurers.roster:
		_dispatch.adventurers.roster[adventurer]["rank"] = "D"
		for each: String in Adventurers.STATS:
			_dispatch.adventurers.stats[adventurer][each] = stat
	_dispatch.adventurers.gear.stash_cap = 100_000
	_dispatch.labyrinth.elite_seed = ELITE_SEED
	_first = _parties.party_of("bram")
	_second = _parties.party_of("ilse")


# The unix seconds the first window from rank C on that opens `elite` opens at.
func _opens(elite: String) -> int:
	var floor_id: String = Dispatch.QUESTS[elite]["elite"]
	var period := Labyrinth.elite_period(RANK_C_AT) + 1
	while _dispatch.labyrinth.elite_floor(period) != floor_id:
		period += 1
	return period * Labyrinth.ELITE_EVERY


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


# Turns Auto on for the party with `id` in `mode`, and its Elite as `elite` says.
func _auto(id: String, mode: String, elite: bool) -> void:
	_parties.set_auto(id, true)
	_parties.set_mode(id, mode)
	_parties.set_elite_auto(id, elite)


# One Auto check at `at` of a rank C guild with `board`.
func _check(board: Board, at: int) -> void:
	Auto.checkpoint(_dispatch, board, at, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "C", true, RANK_C_AT)


# The quest the party with `id` is out on; "" while home.
func _out(id: String) -> String:
	for outing: Dictionary in _dispatch.outings:
		if outing["party_id"] == id:
			return outing["quest"]
	return ""


# How many times parties have come back from an elite.
func _elite_tries() -> int:
	var total := 0
	for elite: String in ELITES:
		total += int(_dispatch.tries.get(elite, 0))
	return total


# How many times parties have come back from a board quest.
func _board_tries() -> int:
	var total := 0
	for quest: String in _dispatch.tries:
		if not Dispatch.is_elite(quest):
			total += int(_dispatch.tries[quest])
	return total


func test_elite_is_off_for_every_party_by_default_and_after_loading_an_older_save_and_is_saved() -> void:
	assert_false(_parties.elite_auto(_first))
	assert_false(_parties.elite_auto(_second))
	_parties.set_elite_auto(_first, true)
	var file := ConfigFile.new()
	_parties.write(file)
	var again := ConfigFile.new()
	assert_eq(again.parse(file.encode_to_text()), OK)
	var loaded := Parties.read(again, [])
	assert_true(loaded.elite_auto(_first))
	assert_false(loaded.elite_auto(_second))
	# Turned off again, it saves off.
	loaded.set_elite_auto(_first, false)
	var off := ConfigFile.new()
	loaded.write(off)
	assert_false(Parties.read(off, []).elite_auto(_first))
	var old := ConfigFile.new()
	old.set_value("parties", "parties", [{"id": "party_1", "name": "The Iron Wolves", "seed": 1, "members": PackedStringArray(["bram"]), "auto": true, "mode": Parties.BOLD}])
	old.set_value("parties", "next_id", 2)
	var from_old := Parties.read(old, [])
	assert_true(from_old.auto("party_1"))
	assert_false(from_old.elite_auto("party_1"))


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


# A party row's switches, Auto then Elite.
func _switches(row: Node) -> Array:
	return row.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.toggle_mode)


func test_the_elite_switch_shows_on_a_party_row_only_at_rank_c_with_auto_unlocked_and_a_tap_turns_it_on_or_off() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_layer.add_child(Touch.new())
	var screen := (load("res://screens/quest_board.tscn") as PackedScene).instantiate() as QuestBoard
	_layer.add_child(screen)
	var asked: Array = []
	screen.elite_toggled.connect(func(party: String, on: bool) -> void:
		asked.append([party, on])
		_parties.set_elite_auto(party, on)
		screen.show_board(Board.new(), _dispatch, 1_000, true, PackedStringArray(), true))
	# Before rank C: the Auto switch shows, the Elite one doesn't.
	screen.show_board(Board.new(), _dispatch, 1_000, true, PackedStringArray(), false)
	var row := screen.get_node("Scroll/Box/PartyList").get_child(1)
	var switches := _switches(row)
	assert_eq(switches.size(), 2)
	var auto := switches[0] as Button
	var elite := switches[1] as Button
	assert_true(auto.is_visible_in_tree())
	assert_false(elite.is_visible_in_tree())
	# At rank C with Auto locked: neither.
	screen.show_board(Board.new(), _dispatch, 1_000, false, PackedStringArray(), true)
	assert_false(auto.is_visible_in_tree())
	assert_false(elite.is_visible_in_tree())
	# At rank C with Auto unlocked: it shows, off, whatever the party's Auto.
	screen.show_board(Board.new(), _dispatch, 1_000, true, PackedStringArray(), true)
	assert_true(elite.is_visible_in_tree())
	assert_has(_texts(row), "Elite")
	assert_false(elite.button_pressed)
	await wait_process_frames(1)
	_tap(elite.get_global_rect().get_center())
	assert_eq(asked, [[_second, true]])
	assert_true(elite.button_pressed)
	assert_true(_parties.elite_auto(_second))
	_tap(elite.get_global_rect().get_center())
	assert_eq(asked, [[_second, true], [_second, false]])
	assert_false(elite.button_pressed)
	assert_false(_parties.elite_auto(_second))
	# Neither Auto nor the other party's Elite was touched.
	assert_false(_parties.auto(_second))
	assert_false(auto.button_pressed)
	assert_false(_parties.elite_auto(_first))


# The text of every label in `node`, visible or not, in tree order.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for part: Node in node.find_children("*", "Label", true, false):
		texts.append((part as Label).text)
	return texts


func test_a_ready_auto_party_with_elite_on_takes_an_open_elite_that_meets_its_mode_and_pays_more_than_the_best_board_quest() -> void:
	# Bold, every stat 18: the elites' low ends and the wyrm's (210 gold) all reach 40.
	var opens := _opens("elite_3")
	_guild(opens, 18)
	_auto(_first, Parties.BOLD, true)
	_check(_board(["wyrm", "vault"], opens), opens)
	assert_eq(_out(_first), "elite_3")
	assert_eq(_dispatch.labyrinth.elite_taken, Labyrinth.elite_period(opens))
	# An elite paying less than the wyrm: the wyrm.
	for cheaper: String in ["elite_1", "elite_2"]:
		opens = _opens(cheaper)
		_guild(opens, 18)
		_auto(_first, Parties.BOLD, true)
		assert_has(_dispatch.open_elites(RANK_C_AT, opens), cheaper)
		_check(_board(["wyrm", "vault"], opens), opens)
		assert_eq(_out(_first), "wyrm", cheaper)


func test_a_ready_auto_party_turns_to_an_elite_the_moment_its_window_opens() -> void:
	# Waiting on a board with nothing it takes, it goes as the window opens, not before.
	var opens := _opens("elite_3")
	_guild(opens - 30, 22)
	_auto(_first, Parties.SAFE, true)
	var board := _board(["wyrm"], opens - 30)
	_check(board, opens - 30)
	assert_eq(_out(_first), "")
	_check(board, opens + 30)
	assert_eq(_dispatch.outings[0]["quest"], "elite_3")
	assert_eq(_dispatch.outings[0]["since"], opens)


func test_with_elite_off_a_ready_auto_party_never_takes_an_open_elite() -> void:
	var opens := _opens("elite_3")
	_guild(opens, 18)
	_auto(_first, Parties.BOLD, false)
	_check(_board(["wyrm", "vault"], opens), opens)
	assert_eq(_out(_first), "wyrm")
	assert_eq(_dispatch.labyrinth.elite_taken, -1)
	# Nor through three hours of windows, while it keeps questing.
	_guild(RANK_C_AT, 22)
	_auto(_first, Parties.BOLD, false)
	_auto(_second, Parties.SAFE, false)
	var board := Board.new()
	board.reception_slots = 3
	board.refill(_dispatch, RANK_C_AT, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "C")
	_check(board, RANK_C_AT + Auto.REPLAY_SECONDS)
	assert_gt(_board_tries(), 0)
	assert_eq(_elite_tries(), 0)
	assert_eq(_dispatch.labyrinth.elite_taken, -1)


func test_a_party_that_does_not_meet_its_modes_threshold_never_takes_an_elite() -> void:
	# Every stat 18: the elites' low ends are under Safe's 70, and so is every board quest's.
	var opens := _opens("elite_3")
	_guild(opens, 18)
	_auto(_first, Parties.SAFE, true)
	var board := _board(["wyrm", "vault"], opens)
	_check(board, opens)
	assert_eq(_out(_first), "")
	assert_eq(_dispatch.labyrinth.elite_taken, -1)
	# The same party on Bold takes it.
	_parties.set_mode(_first, Parties.BOLD)
	_check(board, opens + 1)
	assert_eq(_out(_first), "elite_3")


func test_two_ready_parties_with_elite_on_the_first_in_party_order_takes_the_elite_and_the_next_the_board() -> void:
	var opens := _opens("elite_3")
	_guild(opens, 18)
	_auto(_first, Parties.BOLD, true)
	_auto(_second, Parties.BOLD, true)
	# Ilse alone is as strong on the wyrm as Bram and Tobin.
	for each: String in Adventurers.STATS:
		_dispatch.adventurers.stats["ilse"][each] = 36
	_check(_board(["wyrm", "vault"], opens), opens)
	assert_eq(_out(_first), "elite_3")
	assert_ne(_out(_second), "")
	assert_false(Dispatch.is_elite(_out(_second)))


# Everything the guild and board save, as text: gold, XP, health, stash, outings, labyrinth, board.
func _saved(board: Board) -> String:
	var file := ConfigFile.new()
	_dispatch.gold.write(file)
	_dispatch.write(file)
	board.write(file)
	return file.encode_to_text()


# Bram and Tobin on Bold and Ilse on Safe, both with Elite on, every stat 22, from rank C at
# RANK_C_AT, with a fresh board of three slots.
func _elite_parties() -> Board:
	_guild(RANK_C_AT, 22)
	_auto(_first, Parties.BOLD, true)
	_auto(_second, Parties.SAFE, true)
	var board := Board.new()
	board.reception_slots = 3
	board.refill(_dispatch, RANK_C_AT, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "C")
	return board


func test_elites_taken_by_auto_after_an_absence_within_its_last_3_hours_give_the_same_as_checking_every_second() -> void:
	var end := RANK_C_AT + Auto.REPLAY_SECONDS
	var away := _elite_parties()
	_check(away, end)
	var once := _saved(away)
	var watched := _elite_parties()
	for second: int in range(RANK_C_AT, end + 1):
		_check(watched, second)
	assert_eq(_saved(watched), once)
	# What it played out: elites and board quests.
	assert_gt(_elite_tries(), 1)
	assert_gt(_board_tries(), 0)


func test_the_averaged_settle_of_a_long_absence_never_takes_an_elite() -> void:
	# Two days and three hours away: only the windows of the last three hours are seen.
	var end := RANK_C_AT + 2 * 86_400 + Auto.REPLAY_SECONDS
	var board := _elite_parties()
	_check(board, end)
	var windows := Auto.REPLAY_SECONDS / Labyrinth.ELITE_EVERY + 1
	assert_gt(_elite_tries(), 0)
	assert_lte(_elite_tries(), windows)
	assert_gte(_dispatch.labyrinth.elite_taken, Labyrinth.elite_period(end - Auto.REPLAY_SECONDS))
	# The two days before were averaged: far more board quests than windows.
	assert_gt(_board_tries(), 10 * windows)
