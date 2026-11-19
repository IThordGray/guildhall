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

@onready var _title: Label = $Box/Heading/Title
@onready var _meta: Label = $Box/Heading/Meta
@onready var _list: VBoxContainer = $Box/List
@onready var _coverage: HFlowContainer = $Box/Forecast/Box/Coverage
@onready var _chance: Control = $Box/Forecast/Box/Chance
@onready var _odds: Label = $Box/Forecast/Box/Chance/Odds
@onready var _band: Control = $Box/Forecast/Box/Band
@onready var _band_fill: Control = $Box/Forecast/Box/Band/Fill
@onready var _note: Label = $Box/Forecast/Box/Note
@onready var _reason: Label = $Box/Reason
@onready var _send: Button = $Box/Buttons/Send


func _ready() -> void:
	for adventurer: String in Dispatch.ADVENTURERS:
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.custom_minimum_size = Vector2(0, 150)
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	_title.text = info["name"]
	_meta.text = "Rank %s · %s · %d gold" % [info["rank"], Duration.label(info["seconds"]), info["gold"]]
	show()
	show_dispatch(dispatch, now)
	_show_forecast()


## Shows `dispatch` at `now`.
func show_dispatch(dispatch: Dispatch, now: int) -> void:
	_dispatch = dispatch
	_now = now
	for adventurer: String in _toggles:
		var info: Dictionary = Dispatch.ADVENTURERS[adventurer]
		var toggle := _toggles[adventurer]
		var health := "health %d / %d" % [dispatch.health(adventurer, now), dispatch.adventurers.max_health(adventurer)]
		toggle.text = "%s · %s %s · power %d\n%s · %s" % [info["name"], info["class"], info["rank"], dispatch.adventurers.power(adventurer), dispatch.status(adventurer, now), health]
		toggle.disabled = not dispatch.can_go(adventurer, now)
	var reason := dispatch.party_refusal(_quest, _picked, now)
	_reason.text = reason
	_reason.visible = not reason.is_empty()
	_send.disabled = not reason.is_empty()


# Which challenges the picked party covers and the chance range it is shown; only picking
# someone changes them while the picker is open.
func _show_forecast() -> void:
	for old: Node in _coverage.get_children():
		old.queue_free()
	var unknown := _dispatch.unknown_challenges(_quest)
	for challenge: String in Dispatch.QUESTS[_quest]["challenges"]:
		if challenge in unknown:
			_coverage.add_child(QuestBoard.chip("? unknown", &"ChipUnknown"))
			continue
		var names := PackedStringArray()
		for adventurer: String in Challenges.covered_by(challenge, _picked):
			names.append(Dispatch.ADVENTURERS[adventurer]["name"])
		if names.is_empty():
			_coverage.add_child(QuestBoard.chip(challenge, &"ChipUncovered"))
		else:
			_coverage.add_child(QuestBoard.chip("%s · %s" % [challenge, ", ".join(names)], &"ChipCovered"))
	var picked := not _picked.is_empty()
	_chance.visible = picked
	_band.visible = picked
	var note := "If it fails: %d gold." % Dispatch.failure_gold(_quest)
	if picked:
		var shown := _dispatch.chance_range(_quest, _picked)
		_odds.text = "%d–%d%%" % [shown.x, shown.y]
		_band_fill.anchor_left = shown.x / 100.0
		_band_fill.anchor_right = shown.y / 100.0
		# Every quest starts with at most one challenge unknown.
		if not unknown.is_empty():
			note = "One challenge is still unknown; revealing it narrows the range. " + note
	_note.text = note


func _on_toggled(picked: bool, adventurer: String) -> void:
	if picked:
		_picked.append(adventurer)
	else:
		_picked.remove_at(_picked.find(adventurer))
	show_dispatch(_dispatch, _now)
	_show_forecast()
