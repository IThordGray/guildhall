class_name MarketScreen
extends Control

## The town's Market: its stock until the next, each item with its price or Sold, and the labyrinth
## materials it buys, each with what selling all of it brings.

## The player is done at the Market.
signal back_pressed
## The player chose to buy `item`, shown in slot `slot` of the stock.
signal buy_pressed(slot: int, item: String)
## The player chose to sell all of `material`, a key of Market.MATERIAL_GOLD.
signal sell_pressed(material: String)

## The stock as shown, its items and which are sold, so its rows are rebuilt only when it changes.
var _shown: Array = []
## Each material's row and its parts that change, by its name.
var _rows: Dictionary[String, Control] = {}
var _titles: Dictionary[String, Label] = {}
var _sells: Dictionary[String, Button] = {}

@onready var _parties: Control = $Box/Header/Parties
@onready var _parties_count: Label = $Box/Header/Parties/Count
@onready var _stash: Label = $Box/Header/Stash
@onready var _countdown: Label = $Box/Scroll/Lists/ForSale/Countdown
@onready var _stock: VBoxContainer = $Box/Scroll/Lists/Stock/Items
@onready var _materials: VBoxContainer = $Box/Scroll/Lists/Materials/Items


func _ready() -> void:
	($Box/Back as Button).pressed.connect(back_pressed.emit)
	for material: String in Market.MATERIAL_GOLD:
		_materials.add_child(_material_row(material))


## Landscape shows how many parties are out beside the title.
func set_landscape(landscape: bool) -> void:
	_parties.visible = landscape


## Shows `market` at `now` to a guild with `gear`'s stash, `labyrinth`'s materials and
## `parties_out` parties out.
func show_market(market: Market, gear: Gear, labyrinth: Labyrinth, parties_out: int, now: int) -> void:
	_parties_count.text = str(parties_out)
	_stash.text = "%d / %d" % [gear.stash.size(), gear.stash_cap]
	var stock := market.stock(now)
	# The stock changes when the period the Market has caught up to ends.
	_countdown.text = "new stock in " + Duration.label((market.period + 1) * Market.STOCK_SECONDS - now)
	var sold: Array[bool] = []
	for slot: int in stock.size():
		sold.append(market.is_sold(slot, now))
	var shown := [stock, sold]
	if shown != _shown:
		_shown = shown
		for row: Node in _stock.get_children():
			_stock.remove_child(row)
			row.queue_free()
		for slot: int in stock.size():
			_stock.add_child(_item_row(slot, stock[slot], sold[slot]))
	for material: String in _rows:
		var count := int(labyrinth.materials.get(material, 0))
		_titles[material].text = "%s ×%d" % [material, count]
		_sells[material].text = "Sell all · %dg" % (count * Market.MATERIAL_GOLD[material])
		_sells[material].visible = count > 0
		_rows[material].modulate = Color.WHITE if count > 0 else Roster.DISABLED_ROW_TINT


# `item` in slot `slot`: its icon, name and quality · slot · stats, and its price to buy it from a
# tap anywhere on the row; once `sold`, dimmed, "Sold" and no price.
func _item_row(slot: int, item: String, sold: bool) -> Control:
	var info: Dictionary = Gear.ITEMS[item]
	var line := _label("Sold", &"Caption") if sold else Adventurer.bonus_label(item)
	if not sold:
		line.text = "%s · %s · %s" % [info["quality"], Gear.SLOTS[info["slot"]], line.text]
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Adventurer.item_name(item))
	words.add_child(line)
	var row_line := HBoxContainer.new()
	row_line.add_theme_constant_override("separation", 32)
	row_line.add_child(Adventurer.item_icon(item, 3))
	row_line.add_child(words)
	var row := PanelContainer.new()
	row.theme_type_variation = &"ProgressRow"
	row.add_child(row_line)
	if sold:
		row.modulate = Roster.DISABLED_ROW_TINT
		return row
	var buy := Button.new()
	buy.text = "%dg" % Market.price(item)
	buy.theme_type_variation = &"GoldButton"
	buy.custom_minimum_size = Vector2(200, 120)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(buy_pressed.emit.bind(slot, item))
	row_line.add_child(buy)
	return Touch.whole_card(row, buy)


# `material`'s square as the Labyrinth shows it, its name and count over what each brings, and Sell
# all, pressed from a tap anywhere on the row while there is some.
func _material_row(material: String) -> Control:
	var square := ColorRect.new()
	square.color = LabyrinthScreen.MATERIAL_COLORS[material]
	square.custom_minimum_size = LabyrinthScreen.MATERIAL_SQUARE_PX
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titles[material] = _label("", &"RowTitle")
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(_titles[material])
	words.add_child(_label("%dg each" % Market.MATERIAL_GOLD[material], &"Caption"))
	var sell := Button.new()
	sell.custom_minimum_size = Vector2(0, 120)
	sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell.pressed.connect(sell_pressed.emit.bind(material))
	_sells[material] = sell
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 32)
	for part: Control in [square, words, sell]:
		line.add_child(part)
	var row := PanelContainer.new()
	row.theme_type_variation = &"ProgressRow"
	row.add_child(line)
	_rows[material] = row
	return Touch.whole_card(row, sell)


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
