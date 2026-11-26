class_name Reception
extends Control

## The player is done looking at the guild's rank.
signal back_pressed
## The player asked to rank the guild up.
signal rank_up_pressed

## What reaching each rank opens, in words for the player, by rank.
const OPENS: Dictionary[String, PackedStringArray] = {
	"E": ["Ground-floor wing: 3 rooms", "Storeroom, Infirmary, Quest hall", "Mostly rank-E quests", "Rank-E recruits", "Walk-ins sooner"],
	"D": ["Tier-3 room upgrades", "A second Bunk room", "Extend: the First floor"],
}
## Each checklist line's name, by what Hall.rank_up_checklist calls it, for the lines not named by
## what they need (`_need_row`).
const NEED_NAMES: Dictionary[String, String] = {"reputation": "Reputation", "rooms": "Rooms in use"}
## In landscape, the width of the column with the rank card and Back.
const SIDE_WIDTH_PX: float = 554.0
const BAR_SIZE_PX: Vector2 = Vector2(200, 12)
const VALUE_WIDTH_PX: float = 170.0
const TICK_PX: float = 50.0
const PIP_PX: float = 17.0

## The rank, reputation and checklist as shown, so the lists are rebuilt only when they change.
var _shown: Array = []

@onready var _box: VBoxContainer = $Box
@onready var _parties: Control = $Box/Header/Parties
@onready var _parties_count: Label = $Box/Header/Parties/Count
@onready var _columns: BoxContainer = $Box/Scroll/Columns
@onready var _side: VBoxContainer = $Box/Scroll/Columns/Side
@onready var _rank: BoxContainer = $Box/Scroll/Columns/Side/Card/Rank
@onready var _words: VBoxContainer = $Box/Scroll/Columns/Side/Card/Rank/Words
@onready var _letter: Label = $Box/Scroll/Columns/Side/Card/Rank/Badge/Letter
@onready var _name: Label = $Box/Scroll/Columns/Side/Card/Rank/Words/Name
@onready var _reputation: HBoxContainer = $Box/Scroll/Columns/Side/Card/Rank/Words/Reputation
@onready var _reputation_count: Label = $Box/Scroll/Columns/Side/Card/Rank/Words/Reputation/Count
@onready var _gap: Control = $Box/Scroll/Columns/Side/Gap
@onready var _needs: Control = $Box/Scroll/Columns/Needs
@onready var _needs_section: Label = $Box/Scroll/Columns/Needs/Section
@onready var _need_rows: VBoxContainer = $Box/Scroll/Columns/Needs/List/Rows
@onready var _opens: Control = $Box/Scroll/Columns/Opens
@onready var _opens_section: Label = $Box/Scroll/Columns/Opens/Section
@onready var _open_rows: VBoxContainer = $Box/Scroll/Columns/Opens/List/Rows
@onready var _buttons: HBoxContainer = $Box/Buttons
@onready var _rank_up: Button = $Box/Buttons/RankUp
@onready var _back: Button = $Box/Buttons/Back


func _ready() -> void:
	_rank_up.pressed.connect(rank_up_pressed.emit)
	_back.pressed.connect(back_pressed.emit)


## Landscape shows how many parties are out beside the title, and puts the rank card with Rank up
## and Back under it in a column, then the checklist and what the next rank opens side by side;
## portrait stacks them, with Back and Rank up side by side last.
func set_landscape(landscape: bool) -> void:
	_parties.visible = landscape
	_columns.vertical = not landscape
	_rank.vertical = landscape
	_words.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if landscape else Control.SIZE_FILL
	_reputation.alignment = BoxContainer.ALIGNMENT_CENTER if landscape else BoxContainer.ALIGNMENT_BEGIN
	_side.custom_minimum_size.x = SIDE_WIDTH_PX if landscape else 0.0
	_gap.visible = landscape
	_buttons.visible = not landscape
	for button: Button in [_rank_up, _back] if landscape else [_back, _rank_up]:
		button.reparent(_side if landscape else _buttons, false)


## Shows `hall`'s rank, `dispatch`'s reputation, and what ranking up needs against what the guild
## has at `now` (Hall.rank_up_checklist), with what the next rank opens, and Rank up once every
## line is met; at the last rank, only the rank.
func show_guild(hall: Hall, dispatch: Dispatch, now: int) -> void:
	_parties_count.text = str(dispatch.outings.size())
	var checklist := hall.rank_up_checklist(dispatch, now)
	var shown := [hall.rank, dispatch.reputation, checklist]
	if shown == _shown:
		return
	_shown = shown
	_letter.text = hall.rank
	_name.text = "Rank %s guild" % hall.rank
	_reputation_count.text = str(dispatch.reputation)
	_rank_up.visible = hall.rank_up_refusal(dispatch, now).is_empty()
	var next: String = Hall.RANK_UPS.get(hall.rank, {}).get("to", "")
	_needs.visible = not next.is_empty()
	_opens.visible = not next.is_empty()
	if next.is_empty():
		return
	_rank_up.text = "Rank up · %dg" % Hall.RANK_UPS[hall.rank]["gold"]
	_needs_section.text = "TO RANK " + next
	_opens_section.text = "RANK %s OPENS" % next
	for row: Node in _need_rows.get_children() + _open_rows.get_children():
		row.get_parent().remove_child(row)
		row.queue_free()
	for line: Dictionary in checklist:
		_need_rows.add_child(_need_row(line))
	for text: String in OPENS.get(next, PackedStringArray()):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(PIP_PX, PIP_PX)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = get_theme_color(&"font_color", &"Secondary")
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 28)
		line.add_child(pip)
		line.add_child(_label(text, &"Label"))
		_open_rows.add_child(_row(line))


# A checklist line: its name, a story line's its quest's and a cleared line's its floor's; for
# reputation, and for parties while unmet, a small bar; what the guild has of what it needs, which
# the reputation and rooms lines always show, a story line never and every other line only while
# unmet; "not done" on a story line while unmet; and a green tick, named Tick, once met.
func _need_row(line: Dictionary) -> PanelContainer:
	var what: String = line["what"]
	var has: int = line["has"]
	var needs: int = line["needs"]
	var met: bool = line["met"]
	var parts := HBoxContainer.new()
	parts.add_theme_constant_override("separation", 28)
	var name_text: String
	match what:
		"parties":
			name_text = "%d parties" % needs + (" of %d" % line["size"] if line.has("size") else "")
		"hall_level":
			name_text = "Hall level %d" % needs
		"earned":
			name_text = "%d gold earned" % needs
		"explored":
			name_text = "Labyrinth %d%% explored" % needs
		"cleared":
			name_text = "%s cleared" % Dispatch.QUESTS[line["floor"]]["name"]
		"story":
			name_text = Dispatch.QUESTS[line["quest"]]["name"]
		"gold":
			name_text = "%d gold" % needs
		_:
			name_text = NEED_NAMES[what]
	var name_label := _label(name_text, &"Label")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts.add_child(name_label)
	if what == "story" and not met:
		parts.add_child(_label("not done", &"Label"))
	if what == "reputation" or (what == "parties" and not met):
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"GoldBar"
		bar.show_percentage = false
		bar.custom_minimum_size = BAR_SIZE_PX
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = needs
		bar.value = has
		parts.add_child(bar)
	if what in ["reputation", "rooms"] or (what != "story" and not met):
		var value := _label("%d / %d" % [has, needs], &"Meta" if met else &"Numbers")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = VALUE_WIDTH_PX
		parts.add_child(value)
	var tick := Control.new()
	tick.custom_minimum_size = Vector2(TICK_PX, TICK_PX)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if met:
		tick.name = "Tick"
		tick.draw.connect(_draw_tick.bind(tick))
	parts.add_child(tick)
	return _row(parts)


# A tick in the theme's green, drawn to fill `tick`.
func _draw_tick(tick: Control) -> void:
	var unit := tick.size / 24.0
	var points := PackedVector2Array([Vector2(5.0, 12.5) * unit, Vector2(9.5, 17.0) * unit, Vector2(19.0, 7.5) * unit])
	tick.draw_polyline(points, get_theme_color(&"font_color", &"Ok"), 2.6 * unit.x, true)


static func _row(content: Control) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = &"ProgressRow"
	row.add_child(content)
	return row


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
