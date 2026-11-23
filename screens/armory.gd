class_name Armory
extends Control

## The player is done looking at the guild's gear.
signal back_pressed
## The player chose to sell `item`, an item id in the stash.
signal sell_pressed(item: String)

## The stash, as shown, so the list is rebuilt only when it changes.
var _shown: Array = []

@onready var _stash_section: Label = $Box/Scroll/Lists/StashSection
@onready var _stash: VBoxContainer = $Box/Scroll/Lists/Stash/Items


func _ready() -> void:
	($Box/Back as Button).pressed.connect(back_pressed.emit)


## Shows every item in `adventurers`' stash, each with Sell at its price: the Armory is storage
## only, not who wears what.
func show_gear(adventurers: Adventurers) -> void:
	var gear := adventurers.gear
	var shown := [gear.stash.duplicate()]
	if shown == _shown:
		return
	_shown = shown
	_stash_section.text = "STASH · %d / %d" % [gear.stash.size(), gear.stash_cap]
	for row: Node in _stash.get_children():
		_stash.remove_child(row)
		row.queue_free()
	if gear.stash.is_empty():
		var empty := Label.new()
		empty.text = "Empty"
		empty.theme_type_variation = &"Caption"
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(empty)
		_stash.add_child(row)
	for item: String in gear.stash:
		var sell := Button.new()
		sell.text = "Sell %dg" % Gear.price(item)
		sell.custom_minimum_size = Vector2(260, 120)
		sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sell.pressed.connect(sell_pressed.emit.bind(item))
		var line := _item_line(item)
		line.add_child(sell)
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(line)
		_stash.add_child(Touch.whole_card(row, sell))


# `item`'s icon, its name and its bonus.
static func _item_line(item: String) -> HBoxContainer:
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Adventurer.item_name(item))
	words.add_child(Adventurer.bonus_label(item))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 32)
	line.add_child(Adventurer.item_icon(item, 3))
	line.add_child(words)
	return line
