class_name Adventurer
extends Control

## The player is done looking at this adventurer.
signal back_pressed
## The player chose to level up `adventurer`, a key of Dispatch.ADVENTURERS.
signal level_up_pressed(adventurer: String)

## A stat at this value fills its bar.
const STAT_BAR_FULL: int = 20

var _adventurer: String = ""
var _bars: Dictionary[String, ProgressBar] = {}
var _values: Dictionary[String, Label] = {}
## The level-ups the history shows, so it is rebuilt only when they change.
var _history_shown: Array = []

@onready var _token: Label = $Box/Header/Row/Token
@onready var _name: Label = $Box/Header/Row/Words/NameLine/Name
@onready var _status: Label = $Box/Header/Row/Words/NameLine/Status
@onready var _details: Label = $Box/Header/Row/Words/Details
@onready var _level_up: Button = $Box/Header/Row/Words/LevelUp
@onready var _xp: VBoxContainer = $Box/Header/Row/Words/Xp
@onready var _xp_bar: ProgressBar = $Box/Header/Row/Words/Xp/Bar
@onready var _xp_text: Label = $Box/Header/Row/Words/Xp/Text
@onready var _history: VBoxContainer = $Box/Stats/Rows/History


func _ready() -> void:
	var rows := $Box/Stats/Rows as VBoxContainer
	for stat: String in Adventurers.STATS:
		var row := stat_row(Adventurers.STATS[stat], &"Label")
		_bars[stat] = row.get_child(1)
		_values[stat] = row.get_child(2)
		rows.add_child(row)
		rows.move_child(row, _bars.size() - 1)
	_level_up.pressed.connect(func() -> void: level_up_pressed.emit(_adventurer))
	($Box/Back as Button).pressed.connect(back_pressed.emit)


## Shows `adventurer` as `dispatch` has them at `now`.
func show_adventurer(adventurer: String, dispatch: Dispatch, now: int) -> void:
	if adventurer != _adventurer:
		var token := QuestBoard.token(adventurer)
		_token.replace_by(token)
		_token.queue_free()
		_token = token
	_adventurer = adventurer
	var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
	var adventurers := dispatch.adventurers
	var level: int = adventurers.levels[adventurer]
	_name.text = info["name"]
	_status.text = dispatch.status(adventurer, now)
	_status.theme_type_variation = Roster.status_look(dispatch, adventurer, now)
	_details.text = "%s · rank %s · level %d" % [info["class"], info["rank"], level]
	var xp: int = adventurers.xp[adventurer]
	var needed := adventurers.xp_needed(adventurer)
	_level_up.visible = adventurers.level_up_ready(adventurer)
	_level_up.text = "Level up · XP %d / %d" % [xp, needed]
	_xp.visible = not _level_up.visible
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_xp_text.text = xp_line(xp, needed, level + 1)
	for stat: String in Adventurers.STATS:
		_bars[stat].value = adventurers.stats[adventurer][stat]
		_values[stat].text = str(adventurers.stats[adventurer][stat])
	var history: Array = adventurers.history[adventurer]
	if history != _history_shown:
		_history_shown = history.duplicate(true)
		for line: Node in _history.get_children():
			line.queue_free()
		for i: int in range(history.size() - 1, -1, -1):
			var line := Label.new()
			line.text = _history_line(history[i])
			line.theme_type_variation = &"Secondary"
			_history.add_child(line)


## A row for one stat: its name, a bar and a value, the name in `look`.
static func stat_row(stat_name: String, look: StringName) -> HBoxContainer:
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.theme_type_variation = look
	name_label.custom_minimum_size = Vector2(190, 0)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"OwnBar"
	bar.show_percentage = false
	bar.max_value = STAT_BAR_FULL
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Label.new()
	value.theme_type_variation = &"Numbers"
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.add_child(name_label)
	row.add_child(bar)
	row.add_child(value)
	return row


## XP toward the next level, in words for the player.
static func xp_line(xp: int, needed: int, next_level: int) -> String:
	return "XP %d / %d to level %d" % [xp, needed, next_level]


# "Level 3 · Might +1 · Grit +2", naming only the stats that rose.
func _history_line(entry: Dictionary) -> String:
	var parts := PackedStringArray(["Level %d" % entry["level"]])
	for stat: String in Adventurers.STATS:
		var gain: int = entry["gains"].get(stat, 0)
		if gain > 0:
			parts.append("%s +%d" % [Adventurers.STATS[stat], gain])
	if parts.size() == 1:
		parts.append("no change")
	return " · ".join(parts)
