extends Control

const SAVE_PATH: String = "user://save.cfg"

# The Ground floor seen from above, as fractions of the floor area: y = 0 is the back wall,
# y = 1 the front, at the bottom of the screen.
const GROUND_FLOOR: Dictionary[String, Rect2] = {
	"back_left": Rect2(0.0, 0.0, 0.5, 0.3),
	"back_right": Rect2(0.5, 0.0, 0.5, 0.3),
	"side_left": Rect2(0.0, 0.3, 0.3, 0.4),
	"reception": Rect2(0.3, 0.3, 0.4, 0.4),
	"side_right": Rect2(0.7, 0.3, 0.3, 0.4),
	"entrance": Rect2(0.0, 0.7, 1.0, 0.3),
}
const USABLE_NAMES: Dictionary[String, String] = {"entrance": "Entrance hall", "reception": "Reception"}
# Art is found by slot id and look, so replacing a file changes the art with no code change.
const ROOM_ART: String = "res://assets/hall/ground/%s_%s.png"

var _gold: Gold
var _hall: Hall
var _dispatch: Dispatch
var _slots: Dictionary[String, TextureButton] = {}
## The damaged slot the restore panel is open for.
var _chosen_slot: String = ""

@onready var _build_label: Label = $TopBar/BuildLabel
@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _floor: Control = $Floor
@onready var _board: QuestBoard = $QuestBoard
@onready var _restore_panel: Control = $RestorePanel
@onready var _restore_reason: Label = $RestorePanel/Box/Reason
@onready var _restore_button: Button = $RestorePanel/Box/Buttons/Restore
@onready var _tick: Timer = $Tick


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_build_label.text = BuildInfo.label(version)
	$RestorePanel/Box/Cost.text = "Restore — %d gold · %s" % [Hall.RESTORE_COST_GOLD, Duration.label(Hall.RESTORE_SECONDS)]
	$RestorePanel/Box/Buttons/Cancel.pressed.connect(_restore_panel.hide)
	_restore_button.pressed.connect(_on_restore_pressed)
	$TabBar/Hall.toggled.connect(_on_hall_tab_toggled)
	_board.send_pressed.connect(_on_send_pressed)
	_tick.timeout.connect(_on_tick)
	var now := _now()
	_gold = Gold.load_or_start(SAVE_PATH)
	_hall = Hall.load_or_start(SAVE_PATH, now)
	_dispatch = Dispatch.load_or_start(SAVE_PATH, now)
	_build_floor()
	_arrive()


# Web sends only window focus events; mobile and desktop send the application ones. The tick
# being stopped marks the app as left, so the duplicates each platform sends do nothing.
func _notification(what: int) -> void:
	if _gold == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_leave()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, \
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_arrive()


func _arrive() -> void:
	if not _tick.is_stopped():
		return
	var now := _now()
	# A return summary goes here, before _checkpoint folds the absence in: a party back from its
	# quest (Dispatch.returned_since_checkpoint(now), its reward paid at the checkpoint) and a room
	# restored (Hall.finished_since_checkpoint(now)) are what happened while the app was away.
	_checkpoint(now)
	_tick.start()


func _leave() -> void:
	if _tick.is_stopped():
		return
	_checkpoint(_now())
	_tick.stop()


# Saving every tick keeps the save within a second of the moment the app was left: a web reload
# sends no notification, and a save made while the page unloads may never reach IndexedDB.
func _on_tick() -> void:
	_checkpoint(_now())


func _checkpoint(now: int) -> void:
	_dispatch.checkpoint(now, _gold)
	_hall.checkpoint(now)
	var file := ConfigFile.new()
	_gold.write(file)
	_hall.write(file)
	_dispatch.write(file)
	if file.save(SAVE_PATH) != OK:
		push_error("Could not save to " + SAVE_PATH)
	_gold_label.text = "Gold %d" % _gold.amount
	_show_hall(now)
	_board.show_dispatch(_dispatch, now)
	if _restore_panel.visible:
		_show_restore_panel(now)


func _build_floor() -> void:
	for slot: String in GROUND_FLOOR:
		var area: Rect2 = GROUND_FLOOR[slot]
		var button := TextureButton.new()
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.anchor_left = area.position.x
		button.anchor_top = area.position.y
		button.anchor_right = area.end.x
		button.anchor_bottom = area.end.y
		button.pressed.connect(_on_slot_pressed.bind(slot))
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 48)
		label.add_theme_constant_override("outline_size", 14)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		button.add_child(label)
		_floor.add_child(button)
		_slots[slot] = button


func _show_hall(now: int) -> void:
	for slot: String in _slots:
		var button := _slots[slot]
		var label := button.get_child(0) as Label
		match _hall.state(slot, now):
			Hall.State.USABLE:
				_show_art(button, slot, "restored")
				label.text = USABLE_NAMES[slot]
			Hall.State.RESTORED:
				_show_art(button, slot, "restored")
				label.text = "Empty room"
			Hall.State.RESTORING:
				_show_art(button, slot, "damaged")
				label.text = Duration.label(_hall.seconds_left(now))
			Hall.State.DAMAGED:
				_show_art(button, slot, "damaged")
				label.text = "Damaged"


func _show_art(button: TextureButton, slot: String, look: String) -> void:
	var path := ROOM_ART % [slot, look]
	if button.texture_normal == null or button.texture_normal.resource_path != path:
		button.texture_normal = load(path)


func _on_slot_pressed(slot: String) -> void:
	var now := _now()
	if _hall.state(slot, now) != Hall.State.DAMAGED:
		return
	_chosen_slot = slot
	_restore_panel.show()
	_show_restore_panel(now)


func _show_restore_panel(now: int) -> void:
	var reason := _hall.refusal(_chosen_slot, _gold, now)
	_restore_reason.text = reason
	_restore_reason.visible = not reason.is_empty()
	_restore_button.disabled = not reason.is_empty()


func _on_restore_pressed() -> void:
	var now := _now()
	if _hall.restore(_chosen_slot, _gold, now):
		_restore_panel.hide()
	_checkpoint(now)


func _on_send_pressed(quest: String) -> void:
	var now := _now()
	_dispatch.send(quest, _gold, now)
	_checkpoint(now)


# The two tabs share a button group, so the Hall tab turning off means Quests turned on.
func _on_hall_tab_toggled(hall: bool) -> void:
	_floor.visible = hall
	_board.visible = not hall
	_restore_panel.hide()


func _now() -> int:
	return int(Time.get_unix_time_from_system())
