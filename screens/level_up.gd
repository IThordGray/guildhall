class_name LevelUp
extends Control

## The player has seen what the level-up changed.
signal continue_pressed

var _bars: Dictionary[String, ProgressBar] = {}
var _values: Dictionary[String, Label] = {}
var _names: Dictionary[String, Label] = {}
var _changes: Dictionary[String, Label] = {}

@onready var _token: Label = $Box/Top/Token
@onready var _title: Label = $Box/Top/Title
@onready var _details: Label = $Box/Top/Details
@onready var _xp_bar: ProgressBar = $Box/XpBar
@onready var _xp_text: Label = $Box/XpText


func _ready() -> void:
	var rows := $Box/Changed/Rows as VBoxContainer
	for stat: String in Adventurers.STATS:
		var row := Adventurer.stat_row(Adventurers.STATS[stat], &"Label")
		_names[stat] = row.get_child(0)
		_bars[stat] = row.get_child(1)
		_values[stat] = row.get_child(2)
		_values[stat].custom_minimum_size = Vector2(180, 0)
		var change := Label.new()
		change.custom_minimum_size = Vector2(110, 0)
		change.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_changes[stat] = change
		row.add_child(change)
		rows.add_child(row)
	($Box/Continue as Button).pressed.connect(continue_pressed.emit)


## Shows the level-up `adventurer` just had in `adventurers`, which raised each stat by `gains`.
func show_level_up(adventurer: String, gains: Dictionary, adventurers: Adventurers) -> void:
	var token := QuestBoard.token(adventurer)
	token.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_token.replace_by(token)
	_token.queue_free()
	_token = token
	var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
	var level: int = adventurers.levels[adventurer]
	_title.text = "%s reached level %d" % [info["name"], level]
	_details.text = "%s · rank %s" % [info["class"], info["rank"]]
	for stat: String in Adventurers.STATS:
		var now_value: int = adventurers.stats[adventurer][stat]
		var gain: int = gains[stat]
		_bars[stat].value = now_value
		var risen := gain > 0
		_values[stat].text = "%d → %d" % [now_value - gain, now_value] if risen else str(now_value)
		_values[stat].theme_type_variation = &"Numbers" if risen else &"Meta"
		_names[stat].theme_type_variation = &"Label" if risen else &"Secondary"
		_changes[stat].text = "+%d" % gain if risen else "–"
		_changes[stat].theme_type_variation = &"SuccessChip" if risen else &"Secondary"
	var xp: int = adventurers.xp[adventurer]
	var needed := adventurers.xp_needed(adventurer)
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_xp_text.text = Adventurer.xp_line(xp, needed, level + 1)
