class_name GearSlot
extends Control

## The player chose to put the stash item at `index` on `adventurer`.
signal wear_pressed(adventurer: String, index: int)
## The player chose to put what `adventurer` wears in `slot` into the stash.
signal take_off_pressed(adventurer: String, slot: String)
## The player is done without changing anything.
signal back_pressed

## The adventurer, slot, what they wear there, the stash and why they can't wear or take off, as
## shown, so the list is rebuilt only when these change.
var _shown: Array = []

@onready var _section: Label = $Box/Header/Section
@onready var _title: Label = $Box/Header/Title
@onready var _list: VBoxContainer = $Box/Scroll/List


func _ready() -> void:
	($Box/Back as Button).pressed.connect(back_pressed.emit)


## Shows `adventurer`'s gear `slot` as `dispatch` has it: what they wear there, with Take off, and
## each stash item that goes there, with Wear. A button that can't be pressed says why instead.
func show_slot(adventurer: String, slot: String, dispatch: Dispatch) -> void:
	var gear := dispatch.adventurers.gear
	var worn: String = gear.worn[adventurer].get(slot, "")
	var take_off_refusal := dispatch.take_off_refusal(adventurer, slot)
	var wear_refusal := dispatch.wear_refusal(adventurer)
	var shown := [adventurer, slot, worn, gear.stash.duplicate(), take_off_refusal, wear_refusal]
	if shown == _shown:
		return
	_shown = shown
	_section.text = Gear.SLOTS[slot].to_upper()
	_title.text = dispatch.adventurers.roster[adventurer]["name"]
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	if not worn.is_empty():
		var take_off := _button("Take off", take_off_refusal)
		take_off.pressed.connect(take_off_pressed.emit.bind(adventurer, slot))
		_list.add_child(_row(worn, take_off))
	var fitting := gear.fitting(slot)
	if fitting.is_empty():
		var nothing := Label.new()
		nothing.text = "Nothing in the stash for this slot"
		nothing.theme_type_variation = &"Secondary"
		nothing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(nothing)
		_list.add_child(row)
	for index: int in fitting:
		var wear := _button("Wear", wear_refusal)
		wear.pressed.connect(wear_pressed.emit.bind(adventurer, index))
		_list.add_child(_row(gear.stash[index], wear))


# A button reading `text`, or disabled and reading `refusal` when there is one.
static func _button(text: String, refusal: String) -> Button:
	var button := Button.new()
	button.text = text if refusal.is_empty() else refusal
	button.disabled = not refusal.is_empty()
	button.custom_minimum_size = Vector2(260, 120)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


# `item`'s icon, name and bonus, with `button` after them, which a tap anywhere on the row presses.
static func _row(item: String, button: Button) -> Control:
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Adventurer.item_name(item))
	words.add_child(Adventurer.bonus_label(item))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 32)
	line.add_child(Adventurer.item_icon(item, 3))
	line.add_child(words)
	line.add_child(button)
	var row := PanelContainer.new()
	row.theme_type_variation = &"ProgressRow"
	row.add_child(line)
	return Touch.whole_card(row, button)
