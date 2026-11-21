class_name Roster
extends Control

## The player tapped `adventurer`, a key of Adventurers.roster, to see them.
signal adventurer_pressed(adventurer: String)
## The player asked to hire the candidate in `slot` of Recruits.candidates.
signal hire_pressed(slot: int)
## The player asked to see the guild's gear.
signal armory_pressed

## The space above and below the figure in an adventurer's row.
const ROW_PADDING_PX: int = 22

## The adventurers the rows were built for, in roster order, so they are rebuilt only when someone
## joins or leaves.
var _built: Array = []
var _statuses: Dictionary[String, Label] = {}
var _details: Dictionary[String, Label] = {}
var _healths: Dictionary[String, HBoxContainer] = {}
## The candidates the candidate rows were built for, so they are rebuilt only when one is hired or
## arrives; the parts that change without that: by slot, each candidate's hire button and why it
## can't be pressed, and the one line under them for the empty slots, the soonest refill.
var _candidates_shown: Array[Dictionary] = []
var _hires: Dictionary[int, Button] = {}
var _hire_reasons: Dictionary[int, Label] = {}
var _countdown: Label

@onready var _list: VBoxContainer = $Scroll/Box/List
@onready var _beds: Label = $Scroll/Box/Header/Beds
@onready var _candidates: VBoxContainer = $Scroll/Box/Candidates


func _ready() -> void:
	($Scroll/Box/Header/Armory as Button).pressed.connect(armory_pressed.emit)


func show_dispatch(dispatch: Dispatch, now: int) -> void:
	var roster := dispatch.adventurers.roster
	if roster.keys() != _built:
		_build(dispatch.adventurers)
	for adventurer: String in _statuses:
		var info: Dictionary = roster[adventurer]
		_details[adventurer].text = "%s · rank %s · level %d" % [info["class"], info["rank"], dispatch.adventurers.levels[adventurer]]
		var status := _statuses[adventurer]
		status.text = dispatch.status(adventurer, now)
		status.theme_type_variation = status_look(dispatch, adventurer, now)
		Adventurer.show_health(_healths[adventurer], adventurer, dispatch, now)


## Shows how many beds `adventurers` fill of `beds`, and `recruits`' candidates at `now`: each with
## a hire button, disabled with the reason when `gold` or a bed is short; then, while a slot is
## empty, the soonest refill. `hall` is what a reason may suggest building.
func show_recruits(recruits: Recruits, adventurers: Adventurers, gold: Gold, beds: int, hall: Hall, now: int) -> void:
	_beds.text = "%d adventurers · %d beds" % [adventurers.roster.size(), beds]
	if recruits.candidates != _candidates_shown:
		_build_candidates(recruits.candidates)
	for slot: int in _hires:
		var reason := Recruits.refusal(adventurers, gold, beds, Recruits.hire_gold(recruits.candidates[slot]), hall)
		_hires[slot].disabled = not reason.is_empty()
		_hire_reasons[slot].text = reason
		_hire_reasons[slot].visible = not reason.is_empty()
	var left := recruits.seconds_to_next_refill(now)
	_countdown.visible = left >= 0
	_countdown.text = "New candidate in " + Duration.label(left)


## The adventurer `step` places after `adventurer` in `roster` order (Adventurers.roster), wrapping
## around at the ends.
static func adventurer_after(adventurer: String, step: int, roster: Dictionary) -> String:
	var order := roster.keys()
	return order[posmod(order.find(adventurer) + step, order.size())]


## How `adventurer`'s status reads at `now`: hurt, free to go, or busy.
static func status_look(dispatch: Dispatch, adventurer: String, now: int) -> StringName:
	if dispatch.injury_left(adventurer, now) > 0:
		return &"Alert"
	if dispatch.can_go(adventurer, now):
		return &"Ok"
	return &"Secondary"


# One row per adventurer in `adventurers`' roster: their figure in their gear, name, status, details
# and health.
func _build(adventurers: Adventurers) -> void:
	var roster := adventurers.roster
	_built = roster.keys()
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_statuses.clear()
	_details.clear()
	_healths.clear()
	for adventurer: String in roster:
		var name_line := HBoxContainer.new()
		name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _label(roster[adventurer]["name"], &"RowTitle")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_line.add_child(name_label)
		var status := _label("", &"Secondary")
		status.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_line.add_child(status)
		_statuses[adventurer] = status
		var details := _label("", &"Secondary")
		_details[adventurer] = details
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(name_line)
		words.add_child(details)
		_healths[adventurer] = Adventurer.health_row()
		words.add_child(_healths[adventurer])
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 32)
		var figure := TextureRect.new()
		figure.texture = QuestBoard.figure(Faces.seed_of(adventurer, roster[adventurer]), adventurers.gear.worn[adventurer])
		figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		figure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(figure)
		line.add_child(words)
		var row := Button.new()
		# A button does not fit its children, so the row is made tall enough for the figure.
		row.custom_minimum_size = Vector2(0, figure.texture.get_height() + 2 * ROW_PADDING_PX)
		row.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 36
		line.offset_right = -36
		row.pressed.connect(adventurer_pressed.emit.bind(adventurer))
		_list.add_child(row)


# One row per filled slot of `candidates`, in slot order: the candidate, what they show of
# themselves and a hire button, which a tap anywhere on the row presses. Then the refill line.
func _build_candidates(candidates: Array[Dictionary]) -> void:
	_candidates_shown = candidates.duplicate()
	for row: Node in _candidates.get_children():
		_candidates.remove_child(row)
		row.queue_free()
	_hires.clear()
	_hire_reasons.clear()
	for slot: int in candidates.size():
		var candidate := candidates[slot]
		if candidate.is_empty():
			continue
		var who: Dictionary = candidate["who"]
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_child(_label(who["name"], &"RowTitle"))
		words.add_child(_label("%s · rank %s" % [who["class"], who["rank"]], &"Secondary"))
		var hire := Button.new()
		hire.text = "Hire · %dg" % Recruits.hire_gold(candidate)
		hire.theme_type_variation = &"GoldButton"
		hire.custom_minimum_size = Vector2(0, 122)
		hire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hire.pressed.connect(hire_pressed.emit.bind(slot))
		_hires[slot] = hire
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 32)
		line.add_child(QuestBoard.face_token(who["face_seed"]))
		line.add_child(words)
		line.add_child(hire)
		# The stats and the reason a hire is refused take the row's full width, beside nothing.
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 16)
		box.add_child(line)
		box.add_child(_label(Recruits.stats_line(candidate), &"Secondary"))
		_hire_reasons[slot] = _label("", &"Alert")
		box.add_child(_hire_reasons[slot])
		var row := PanelContainer.new()
		row.add_child(box)
		_candidates.add_child(Touch.whole_card(row, hire))
	_countdown = _label("", &"Secondary")
	_candidates.add_child(_countdown)


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label
