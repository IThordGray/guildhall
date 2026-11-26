extends GutTest

const MainScript: GDScript = preload("res://main.gd")
const SAVE_PATH: String = "user://test_town_screens_save.cfg"
## Seed 7's stock in period 100, and in period 101.
const STOCK_100: Array = [
	["Red cloak", "Standard · Back · Presence +1", "12g"],
	["Night cloak", "Fine · Back · Agility +3", "60g"],
	["Leather vest", "Standard · Armour · Endurance +1", "12g"],
	["Apprentice robe", "Standard · Clothes · Mind +1", "12g"],
]
const STOCK_101: Array = [
	["Moonherb staff", "Fine · Weapon · Mind +3", "60g"],
	["Leather jerkin", "Standard · Clothes · Agility +1", "12g"],
	["Green sash", "Standard · Belt · Endurance +1", "12g"],
	["Chain shirt", "Standard · Armour · Defence +2", "12g"],
]
## 100 seconds into period 100.
const IN_100: int = 100 * Market.STOCK_SECONDS + 100

## The screens are put on a layer above GUT's own output window.
var _layer: CanvasLayer
## The game, while a test runs it.
var _main: Control = null
## When the next stock comes in, in a test that waits for it.
var _rollover: int = 0


func before_each() -> void:
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


# The words of every label and button in `node` shown on screen, in tree order.
func _shown_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for part: Node in node.find_children("*", "", true, false):
		if not (part is Label or part is Button) or not (part as Control).is_visible_in_tree():
			continue
		var text: String = (part as Label).text if part is Label else (part as Button).text
		if not text.is_empty():
			texts.append(text)
	return texts


func _stock_rows(screen: Control) -> Array[Node]:
	return screen.get_node("Box/Scroll/Lists/Stock/Items").get_children()


func _material_rows(screen: Control) -> Array[Node]:
	return screen.get_node("Box/Scroll/Lists/Materials/Items").get_children()


# Each row of `rows` as the words it shows.
func _texts_of(rows: Array[Node]) -> Array:
	var texts := []
	for row: Node in rows:
		texts.append(_shown_texts(row))
	return texts


# Whether `row` shows dimmed.
func _dimmed(row: Node) -> bool:
	return (row.get_child(0) as Control).modulate.a < 1.0 if row is MarginContainer else (row as Control).modulate.a < 1.0


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


func _tap_on(control: Control) -> void:
	_tap(control.get_global_rect().get_center())
	await wait_process_frames(1)


# The Market screen, with Touch as main.tscn has it.
func _market_screen() -> MarketScreen:
	_layer.add_child(Touch.new())
	var screen := (load("res://screens/market.tscn") as PackedScene).instantiate() as MarketScreen
	_layer.add_child(screen)
	return screen


func _market(seed_value: int) -> Market:
	var market := Market.new()
	market.stock_seed = seed_value
	return market


func _gear(stashed: int, cap: int) -> Gear:
	var gear := Gear.new()
	gear.stash_cap = cap
	for i: int in stashed:
		gear.stow("iron_cap")
	return gear


func test_the_market_lists_the_four_items_with_their_price_and_the_materials_with_what_selling_all_brings() -> void:
	var screen := _market_screen()
	var labyrinth := Labyrinth.new()
	labyrinth.materials = {"Glowmoss": 7, "Riverglass": 1}
	var market := _market(7)
	assert_true(market.buy(2, _rich(), _gear(0, 12), IN_100))
	screen.show_market(market, _gear(9, 12), labyrinth, 1, IN_100)
	assert_eq((screen.get_node("Box/Header/Stash") as Label).text, "9 / 12")
	var rows := _stock_rows(screen)
	# The third is sold: dimmed, "Sold", no price.
	assert_eq(_texts_of(rows), [STOCK_100[0], STOCK_100[1], ["Leather vest", "Sold"], STOCK_100[3]])
	assert_eq([_dimmed(rows[0]), _dimmed(rows[1]), _dimmed(rows[2]), _dimmed(rows[3])], [false, false, true, false])
	assert_eq(rows[0].find_children("*", "TextureRect", true, false).size(), 1)
	var materials := _material_rows(screen)
	assert_eq(_texts_of(materials), [
		["Glowmoss ×7", "4g each", "Sell all · 28g"],
		["Riverglass ×1", "6g each", "Sell all · 6g"],
		["Bone silver ×0", "10g each"],
	])
	assert_eq([_dimmed(materials[0]), _dimmed(materials[1]), _dimmed(materials[2])], [false, false, true])


func _rich() -> Gold:
	return Gold.new(1_000)


func test_the_countdown_shows_the_time_to_the_next_stock_and_at_the_rollover_the_rows_show_the_new_stock() -> void:
	var screen := _market_screen()
	var market := _market(7)
	var gear := _gear(0, 6)
	var labyrinth := Labyrinth.new()
	screen.show_market(market, gear, labyrinth, 0, IN_100)
	var countdown := screen.get_node("Box/Scroll/Lists/ForSale/Countdown") as Label
	# 2880 seconds a stock, 100 gone.
	assert_eq(countdown.text, "new stock in 46:20")
	var rows := _stock_rows(screen)
	screen.show_market(market, gear, labyrinth, 0, 101 * Market.STOCK_SECONDS - 1)
	assert_eq(countdown.text, "new stock in 0:01")
	# The countdown ticks; the rows stay.
	assert_eq(_stock_rows(screen), rows)
	assert_eq(_texts_of(rows), STOCK_100)
	screen.show_market(market, gear, labyrinth, 0, 101 * Market.STOCK_SECONDS)
	assert_eq(countdown.text, "new stock in 48:00")
	assert_eq(_texts_of(_stock_rows(screen)), STOCK_101)


func test_a_tap_on_an_item_row_asks_to_buy_that_item_and_on_a_material_row_to_sell_it_all_only_while_there_is_some() -> void:
	var screen := _market_screen()
	var labyrinth := Labyrinth.new()
	labyrinth.materials = {"Riverglass": 3}
	var market := _market(7)
	assert_true(market.buy(0, _rich(), _gear(0, 12), IN_100))
	screen.show_market(market, _gear(0, 12), labyrinth, 0, IN_100)
	var bought := []
	var sold: Array[String] = []
	screen.buy_pressed.connect(func(slot: int, item: String) -> void: bought.append([slot, item]))
	screen.sell_pressed.connect(sold.append)
	await wait_process_frames(2)
	await _tap_on(_stock_rows(screen)[0] as Control)
	await _tap_on(_material_rows(screen)[0] as Control)
	assert_eq(bought, [])
	assert_eq(sold, [] as Array[String])
	await _tap_on(_stock_rows(screen)[1] as Control)
	await _tap_on(_material_rows(screen)[1] as Control)
	assert_eq(bought, [[1, "night_cloak"]])
	assert_eq(sold, ["Riverglass"] as Array[String])


# The game as main.tscn runs it, on a new game saved at SAVE_PATH.
func _new_game() -> Control:
	MainScript.set("save_path", SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH)
	_main = (load("res://main.tscn") as PackedScene).instantiate() as Control
	_layer.add_child(_main)
	(_main.get_node("Start/Menu/Choices/NewGame") as Button).pressed.emit()
	return _main


# Game time at `game_seconds` from now on, ticking with real time.
func _set_time(main: Control, game_seconds: int) -> void:
	main.set("_clock", GameClock.new(game_seconds - Time.get_unix_time_from_system()))


# The start of the next stock period after real time, so game time only moves forward.
func _next_period_start() -> int:
	return (floori(Time.get_unix_time_from_system() / Market.STOCK_SECONDS) + 1) * Market.STOCK_SECONDS


func _tick(main: Control) -> void:
	(main.get_node("Tick") as Timer).timeout.emit()


# A new game with the town open and the Market shown, 1000 seconds into a stock period.
func _at_the_market() -> Control:
	var main := _new_game()
	_set_time(main, _next_period_start() + 1_000)
	(main.get("_goals") as Goals).unlocked.append(Market.UNLOCK)
	_tick(main)
	await wait_process_frames(2)
	await _tap_on(main.get_node("Body/HallView/Scroll/Box/Top/Header/Switch/Row/Town") as Control)
	await wait_process_frames(1)
	await _tap_on(main.get_node("Body/Town/Box/Plan/Market") as Control)
	await wait_process_frames(1)
	return main


func test_the_hall_town_switch_is_hidden_until_the_town_is_unlocked_then_switches_the_hall_tab_between_the_hall_and_the_town() -> void:
	var main := _new_game()
	var hall := main.get_node("Body/HallView") as Control
	var town := main.get_node("Body/Town") as Control
	var title := hall.get_node("Scroll/Box/Top/Header/Title") as Control
	var hall_switch := hall.get_node("Scroll/Box/Top/Header/Switch") as Control
	await wait_process_frames(2)
	assert_true(title.is_visible_in_tree())
	assert_false(hall_switch.is_visible_in_tree())
	(main.get("_goals") as Goals).unlocked.append(Market.UNLOCK)
	_tick(main)
	await wait_process_frames(2)
	assert_true(hall_switch.is_visible_in_tree())
	await _tap_on(hall_switch.get_node("Row/Town") as Control)
	assert_true(town.visible)
	assert_false(hall.visible)
	assert_true((main.get_node("TabBar/Tabs/Hall") as Button).button_pressed)
	assert_has(_shown_texts(town), "Market")
	# Another tab and back keeps the town for the session.
	await _tap_on(main.get_node("TabBar/Tabs/Quests") as Control)
	assert_false(town.visible)
	await _tap_on(main.get_node("TabBar/Tabs/Hall") as Control)
	assert_true(town.visible)
	assert_false(hall.visible)
	await _tap_on(town.get_node("Box/Header/Switch/Row/Hall") as Control)
	assert_true(hall.visible)
	assert_false(town.visible)
	# The switch on each shows where it is.
	assert_true((hall_switch.get_node("Row/Hall") as Button).button_pressed)
	assert_true((town.get_node("Box/Header/Switch/Row/Town") as Button).button_pressed)


func test_the_market_opens_from_the_town_full_screen_and_back_returns_to_the_town() -> void:
	var main := await _at_the_market()
	var town := main.get_node("Body/Town") as Control
	var market := main.get_node("Body/Market") as Control
	assert_true(market.visible)
	assert_false(town.visible)
	assert_eq(_stock_rows(market).size(), Market.STOCK_SIZE)
	await _tap_on(market.get_node("Box/Back") as Control)
	assert_false(market.visible)
	assert_true(town.visible)


func test_buying_confirms_on_the_card_then_pays_puts_the_item_in_the_stash_and_the_row_shows_sold() -> void:
	var main := await _at_the_market()
	var gold := main.get("_gold") as Gold
	var stash := (main.get("_dispatch") as Dispatch).adventurers.gear.stash
	gold.amount = 500
	var stashed := stash.size()
	var market := main.get_node("Body/Market") as Control
	var row := _stock_rows(market)[0]
	var shown := _shown_texts(row)
	var name_shown := shown[0]
	var price := int(shown[2].trim_suffix("g"))
	await _tap_on(row as Control)
	var sheet := main.get_node("ConfirmSheet") as Control
	assert_true(sheet.visible)
	assert_eq((sheet.get_node("Sheet/Box/Title") as Label).text, "Buy " + name_shown)
	assert_eq((sheet.get_node("Sheet/Box/Note") as Label).text, "%d gold" % price)
	await _tap_on(sheet.get_node("Sheet/Box/Buttons/Action") as Control)
	assert_false(sheet.visible)
	assert_eq(gold.amount, 500 - price)
	assert_eq(stash.size(), stashed + 1)
	assert_eq(Gear.ITEMS[stash[-1]]["name"], name_shown)
	assert_eq(_shown_texts(_stock_rows(market)[0]), [name_shown, "Sold"] as Array[String])


func test_selling_confirms_on_the_card_then_adds_the_gold_and_the_count_goes_to_0() -> void:
	var main := await _at_the_market()
	var gold := main.get("_gold") as Gold
	var labyrinth := (main.get("_dispatch") as Dispatch).labyrinth
	gold.amount = 100
	labyrinth.materials = {"Glowmoss": 7}
	_tick(main)
	var market := main.get_node("Body/Market") as Control
	await _tap_on(_material_rows(market)[0] as Control)
	var sheet := main.get_node("ConfirmSheet") as Control
	assert_true(sheet.visible)
	assert_eq((sheet.get_node("Sheet/Box/Title") as Label).text, "Sell 7 Glowmoss")
	assert_eq((sheet.get_node("Sheet/Box/Note") as Label).text, "+28 gold")
	await _tap_on(sheet.get_node("Sheet/Box/Buttons/Action") as Control)
	assert_false(sheet.visible)
	assert_eq(gold.amount, 128)
	assert_eq(int(labyrinth.materials["Glowmoss"]), 0)
	assert_eq(_shown_texts(_material_rows(market)[0]), ["Glowmoss ×0", "4g each"] as Array[String])


func test_a_refusal_shows_on_the_card_and_cancel_changes_nothing() -> void:
	var main := await _at_the_market()
	var gold := main.get("_gold") as Gold
	var gear := (main.get("_dispatch") as Dispatch).adventurers.gear
	var labyrinth := (main.get("_dispatch") as Dispatch).labyrinth
	var market := main.get_node("Body/Market") as Control
	var sheet := main.get_node("ConfirmSheet") as Control
	var action := sheet.get_node("Sheet/Box/Buttons/Action") as Button
	var price := int(_shown_texts(_stock_rows(market)[0])[2].trim_suffix("g"))
	# Short of gold by 5.
	gold.amount = price - 5
	await _tap_on(_stock_rows(market)[0] as Control)
	assert_true(action.disabled)
	assert_eq(action.text, "Need 5 more gold")
	await _tap_on(sheet.get_node("Sheet/Box/Buttons/Cancel") as Control)
	assert_false(sheet.visible)
	# The stash full.
	gold.amount = 500
	while gear.stash.size() < gear.stash_cap:
		gear.stow("iron_cap")
	await _tap_on(_stock_rows(market)[0] as Control)
	assert_true(action.disabled)
	assert_eq(action.text, "Stash full")
	await _tap_on(sheet.get_node("Sheet/Box/Buttons/Cancel") as Control)
	# Room again, and Cancel.
	gear.stash.remove_at(0)
	var stash := gear.stash.duplicate()
	await _tap_on(_stock_rows(market)[0] as Control)
	assert_false(action.disabled)
	await _tap_on(sheet.get_node("Sheet/Box/Buttons/Cancel") as Control)
	assert_false(sheet.visible)
	labyrinth.materials = {"Riverglass": 2}
	_tick(main)
	await _tap_on(_material_rows(market)[1] as Control)
	assert_true(sheet.visible)
	await _tap_on(sheet.get_node("Sheet/Box/Buttons/Cancel") as Control)
	assert_false(sheet.visible)
	assert_eq(gold.amount, 500)
	assert_eq(gear.stash, stash)
	assert_eq(int(labyrinth.materials["Riverglass"]), 2)
	assert_eq(_shown_texts(_stock_rows(market)[0])[2], "%dg" % price)


# A new game 3 seconds before a new stock, with gold, the town open and the Market shown, on a
# seed whose first item changes at the rollover, so the old and new stock can be told apart.
# `_rollover` is when the new stock comes in.
func _at_the_market_before_a_new_stock() -> Control:
	var main := _new_game()
	_rollover = _next_period_start() + Market.STOCK_SECONDS
	var market := _market(0)
	while market.stock(_rollover - 3)[0] == market.stock(_rollover)[0]:
		market = _market(market.stock_seed + 1)
	(main.get("_market") as Market).stock_seed = market.stock_seed
	_set_time(main, _rollover - 3)
	(main.get("_goals") as Goals).unlocked.append(Market.UNLOCK)
	(main.get("_gold") as Gold).amount = 500
	_tick(main)
	await wait_process_frames(2)
	await _tap_on(main.get_node("Body/HallView/Scroll/Box/Top/Header/Switch/Row/Town") as Control)
	await _tap_on(main.get_node("Body/Town/Box/Plan/Market") as Control)
	return main


func test_a_confirm_opened_on_the_old_stock_does_not_buy_a_different_item_after_the_rollover() -> void:
	var main := await _at_the_market_before_a_new_stock()
	var gold := main.get("_gold") as Gold
	var stash := (main.get("_dispatch") as Dispatch).adventurers.gear.stash
	var stashed := stash.duplicate()
	var market := main.get_node("Body/Market") as Control
	var old_name := _shown_texts(_stock_rows(market)[0])[0]
	await _tap_on(_stock_rows(market)[0] as Control)
	var sheet := main.get_node("ConfirmSheet") as Control
	assert_eq((sheet.get_node("Sheet/Box/Title") as Label).text, "Buy " + old_name)
	# The new stock comes in before Buy is tapped.
	_set_time(main, _rollover + 1)
	await _tap_on(sheet.get_node("Sheet/Box/Buttons/Action") as Control)
	assert_false(sheet.visible)
	assert_eq(gold.amount, 500)
	assert_eq(stash, stashed)
	assert_ne(_shown_texts(_stock_rows(market)[0])[0], old_name)


func test_a_confirm_open_at_the_rollover_closes_and_the_rows_show_the_new_stock() -> void:
	var main := await _at_the_market_before_a_new_stock()
	var market := main.get_node("Body/Market") as Control
	var old_name := _shown_texts(_stock_rows(market)[0])[0]
	await _tap_on(_stock_rows(market)[0] as Control)
	var sheet := main.get_node("ConfirmSheet") as Control
	assert_true(sheet.visible)
	_set_time(main, _rollover + 1)
	_tick(main)
	assert_false(sheet.visible)
	assert_ne(_shown_texts(_stock_rows(market)[0])[0], old_name)
