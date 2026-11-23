class_name StashPick
extends Control

## Which stash item is discarded to make room for loot a full stash would lose: every stash item, a
## tap anywhere on one picking it.

## The player picked `stash_item`, an item id in the stash, to discard for the loot.
signal picked(stash_item: String)
## The player went back without picking anything.
signal back_pressed

@onready var _title: Label = $Box/Title
@onready var _list: VBoxContainer = $Box/Scroll/List


func _ready() -> void:
	($Box/Back as Button).pressed.connect(back_pressed.emit)


## Shows every item in `gear`'s stash to make room for `item`.
func show_stash(item: String, gear: Gear) -> void:
	_title.text = "Make room for %s" % Gear.ITEMS[item]["name"]
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	for stash_item: String in gear.stash:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(Adventurer.item_icon(stash_item, 3))
		var name_label := Adventurer.item_name(stash_item)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(name_label)
		var row := PanelContainer.new()
		row.theme_type_variation = &"ProgressRow"
		row.add_child(line)
		# Over the whole row, so a tap anywhere on it picks the item.
		var pick := Button.new()
		pick.flat = true
		pick.pressed.connect(picked.emit.bind(stash_item))
		row.add_child(pick)
		_list.add_child(row)
