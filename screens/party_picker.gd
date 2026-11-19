class_name PartyPicker
extends PanelContainer

## The player chose to send `party`, keys of Dispatch.ADVENTURERS, on `quest`.
signal send_pressed(quest: String, party: PackedStringArray)

var _quest: String = ""
var _picked: PackedStringArray = PackedStringArray()
var _toggles: Dictionary[String, Button] = {}
## The dispatch and time last shown, so picking someone can update the odds at once.
var _dispatch: Dispatch
var _now: int = 0

@onready var _title: Label = $Box/Title
@onready var _list: VBoxContainer = $Box/List
@onready var _odds: Label = $Box/Odds
@onready var _reason: Label = $Box/Reason
@onready var _send: Button = $Box/Buttons/Send


func _ready() -> void:
	for adventurer: String in Dispatch.ADVENTURERS:
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.custom_minimum_size = Vector2(0, 150)
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.add_theme_font_size_override("font_size", 44)
		for state: String in ["font_pressed_color", "font_hover_pressed_color"]:
			toggle.add_theme_color_override(state, Color(1, 0.84, 0.4))
		toggle.toggled.connect(_on_toggled.bind(adventurer))
		_toggles[adventurer] = toggle
		_list.add_child(toggle)
	_send.pressed.connect(func() -> void: send_pressed.emit(_quest, _picked))
	$Box/Buttons/Cancel.pressed.connect(hide)


## Opens the picker for `quest` with nobody picked.
func open(quest: String, dispatch: Dispatch, now: int) -> void:
	_quest = quest
	_picked = PackedStringArray()
	for toggle: Button in _toggles.values():
		toggle.set_pressed_no_signal(false)
	var info: Dictionary = Dispatch.QUESTS[quest]
	_title.text = "%s · difficulty %d" % [info["name"], info["difficulty"]]
	show()
	show_dispatch(dispatch, now)


## Shows `dispatch` at `now`.
func show_dispatch(dispatch: Dispatch, now: int) -> void:
	_dispatch = dispatch
	_now = now
	for adventurer: String in _toggles:
		var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
		var toggle := _toggles[adventurer]
		toggle.text = "%s · %s %s · power %d\n%s" % [info["name"], info["class"], info["rank"], info["power"], dispatch.status(adventurer, now)]
		toggle.disabled = not dispatch.can_go(adventurer, now)
	_odds.text = "Party power %d · %d%% success" % [Dispatch.party_power(_picked), Dispatch.success_chance(_quest, _picked)]
	var reason := dispatch.party_refusal(_picked, now)
	_reason.text = reason
	_reason.visible = not reason.is_empty()
	_send.disabled = not reason.is_empty()


func _on_toggled(picked: bool, adventurer: String) -> void:
	if picked:
		_picked.append(adventurer)
	else:
		_picked.remove_at(_picked.find(adventurer))
	show_dispatch(_dispatch, _now)
