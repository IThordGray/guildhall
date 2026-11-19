class_name QuestBoard
extends Control

## The player asked to send a party on `quest`, a key of Dispatch.QUESTS.
signal send_pressed(quest: String)
## The player asked to read the debrief at `index` in Dispatch.debriefs.
signal debrief_pressed(index: int)

## The length of each dash in an unknown challenge's chip border.
const DASH_LENGTH: float = 12.0

var _rows: Dictionary[String, Control] = {}
## Each quest's challenge chips, and how many of them were unknown when last shown, so they change
## only when a return reveals one.
var _chips: Dictionary[String, HFlowContainer] = {}
var _unknown_shown: Dictionary[String, int] = {}
## The quests shown, in board order, so the rows change only when the board does.
var _shown: PackedStringArray = PackedStringArray()
## The debriefs and parties out the rows were built for, so they are rebuilt only when those
## change; `_back_labels` and `_out_rows` are their parts that change with time, in the same order.
var _debriefs_shown: Array[Dictionary] = []
var _back_labels: Array[Label] = []
var _outings_shown: Array[Dictionary] = []
var _out_rows: Array[OutRow] = []

@onready var _debriefs_header: Control = $Scroll/Box/DebriefsHeader
@onready var _debrief_count: Label = $Scroll/Box/DebriefsHeader/Count
@onready var _debriefs: VBoxContainer = $Scroll/Box/Debriefs
@onready var _out_section: Control = $Scroll/Box/OutSection
@onready var _out: VBoxContainer = $Scroll/Box/Out
@onready var _list: VBoxContainer = $Scroll/Box/List
@onready var _empty: Label = $Scroll/Box/Empty


## A party-out row's parts that change each second.
class OutRow extends RefCounted:
	var bar: ProgressBar
	var time: Label


func _ready() -> void:
	for quest: String in Dispatch.QUESTS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(_label(info["name"], &"Heading"))
		words.add_child(_label("Rank %s · %s · %d gold" % [info["rank"], Duration.label(info["seconds"]), info["gold"]], &"Meta"))
		var chips := HFlowContainer.new()
		chips.theme_type_variation = &"Chips"
		words.add_child(chips)
		_chips[quest] = chips
		var send := Button.new()
		send.text = "Send party"
		send.theme_type_variation = &"GoldButton"
		send.custom_minimum_size = Vector2(0, 122)
		send.pressed.connect(send_pressed.emit.bind(quest))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(words)
		line.add_child(send)
		var row := PanelContainer.new()
		row.visible = false
		row.add_child(line)
		_rows[quest] = row
		_list.add_child(row)


## Shows the debriefs waiting and the parties out in `dispatch` at `now`, then `quests`, the board
## in board order.
func show_board(quests: PackedStringArray, dispatch: Dispatch, now: int) -> void:
	_show_debriefs(dispatch, now)
	_show_out(dispatch, now)
	_show_challenges(dispatch)
	if quests == _shown:
		return
	_shown = quests
	for quest: String in _rows:
		_rows[quest].visible = quest in quests
	for i: int in quests.size():
		_list.move_child(_rows[quests[i]], i)
	_empty.visible = quests.is_empty()


## A round token: an adventurer's face, or `who` as text when it is not an adventurer, such as a
## count.
static func token(who: String) -> Label:
	var is_adventurer := who in Dispatch.ADVENTURERS
	var label := _label("" if is_adventurer else who, &"Token")
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(80, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_adventurer:
		# The 20 × 18 face at a whole 3×, so its pixels stay crisp, centred in the circle.
		var face := TextureRect.new()
		face.texture = load("res://assets/faces/%s.png" % who)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.position = Vector2(10, 13)
		face.size = Vector2(60, 54)
		label.add_child(face)
	return label


## A challenge chip in `variation`: Chip, ChipCovered, ChipUncovered or ChipUnknown, the last with
## a dashed border.
static func chip(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if variation == &"ChipUnknown":
		label.draw.connect(func() -> void: _draw_dashed_border(label))
	return label


# A StyleBox can't draw a dashed border, so an unknown challenge's pill is drawn here: dashed
# straight sides, and every other dash-length step of each rounded end.
static func _draw_dashed_border(label: Label) -> void:
	var color := label.get_theme_color(&"border_color")
	var width := float(label.get_theme_constant(&"border_width"))
	var middle := label.size.y / 2.0
	var radius := middle - width / 2.0
	var left := middle
	var right := label.size.x - middle
	label.draw_dashed_line(Vector2(left, width / 2.0), Vector2(right, width / 2.0), color, width, DASH_LENGTH)
	label.draw_dashed_line(Vector2(left, label.size.y - width / 2.0), Vector2(right, label.size.y - width / 2.0), color, width, DASH_LENGTH)
	var step := DASH_LENGTH / radius
	for i: int in range(0, ceili(PI / step), 2):
		var from := PI / 2.0 + i * step
		var to := minf(from + step, PI * 1.5)
		label.draw_arc(Vector2(left, middle), radius, from, to, 4, color, width)
		label.draw_arc(Vector2(right, middle), radius, from - PI, to - PI, 4, color, width)


func _show_challenges(dispatch: Dispatch) -> void:
	for quest: String in _chips:
		var unknown := dispatch.unknown_challenges(quest)
		if _unknown_shown.get(quest, -1) == unknown.size():
			continue
		_unknown_shown[quest] = unknown.size()
		for old: Node in _chips[quest].get_children():
			old.queue_free()
		for challenge: String in Dispatch.QUESTS[quest]["challenges"]:
			_chips[quest].add_child(chip("?", &"ChipUnknown") if challenge in unknown else chip(challenge, &"Chip"))


func _show_debriefs(dispatch: Dispatch, now: int) -> void:
	if dispatch.debriefs != _debriefs_shown:
		_debriefs_shown = dispatch.debriefs.duplicate()
		for row: Node in _debriefs.get_children():
			row.queue_free()
		_back_labels.clear()
		for i: int in _debriefs_shown.size():
			var debrief := _debriefs_shown[i]
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.alignment = BoxContainer.ALIGNMENT_CENTER
			words.add_child(_label(Dispatch.QUESTS[debrief["quest"]]["name"], &"RowTitle"))
			var back := _label("", &"Secondary")
			words.add_child(back)
			_back_labels.append(back)
			var open := Button.new()
			open.text = "Debrief ›"
			open.theme_type_variation = &"GoldLink"
			open.pressed.connect(debrief_pressed.emit.bind(i))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 32)
			line.add_child(_tokens(debrief["party"]))
			line.add_child(words)
			line.add_child(open)
			var row := PanelContainer.new()
			row.theme_type_variation = &"DebriefRow"
			row.add_child(line)
			_debriefs.add_child(row)
		_debrief_count.text = str(_debriefs_shown.size())
		_debriefs_header.visible = not _debriefs_shown.is_empty()
		_debriefs.visible = not _debriefs_shown.is_empty()
	for i: int in _back_labels.size():
		_back_labels[i].text = dispatch.back_label(_debriefs_shown[i], now)


func _show_out(dispatch: Dispatch, now: int) -> void:
	if dispatch.outings != _outings_shown:
		_outings_shown = dispatch.outings.duplicate()
		for row: Node in _out.get_children():
			row.queue_free()
		_out_rows.clear()
		for outing: Dictionary in _outings_shown:
			var quest: Dictionary = Dispatch.QUESTS[outing["quest"]]
			var title := _label(quest["name"], &"RowTitle")
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var reward := _label("%d gold" % quest["gold"], &"Meta")
			reward.autowrap_mode = TextServer.AUTOWRAP_OFF
			var heading := HBoxContainer.new()
			heading.add_child(title)
			heading.add_child(reward)
			var out := OutRow.new()
			out.bar = ProgressBar.new()
			out.bar.theme_type_variation = &"GoldBar"
			out.bar.show_percentage = false
			out.bar.step = 1.0
			out.bar.max_value = quest["seconds"]
			out.bar.custom_minimum_size = Vector2(0, 16)
			out.bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			out.bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			out.time = _label("", &"Numbers")
			out.time.autowrap_mode = TextServer.AUTOWRAP_OFF
			_out_rows.append(out)
			var progress := HBoxContainer.new()
			progress.add_theme_constant_override("separation", 32)
			progress.add_child(_tokens(outing["party"]))
			progress.add_child(out.bar)
			progress.add_child(out.time)
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 24)
			box.add_child(heading)
			box.add_child(progress)
			var row := PanelContainer.new()
			row.add_child(box)
			_out.add_child(row)
		_out_section.visible = not _outings_shown.is_empty()
		_out.visible = not _outings_shown.is_empty()
	for i: int in _out_rows.size():
		var left := dispatch.seconds_left(_outings_shown[i], now)
		_out_rows[i].bar.value = _out_rows[i].bar.max_value - left
		_out_rows[i].time.text = Duration.label(left)


func _tokens(party: PackedStringArray) -> HBoxContainer:
	var stack := HBoxContainer.new()
	stack.theme_type_variation = &"TokenStack"
	for adventurer: String in party:
		stack.add_child(token(adventurer))
	return stack


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
