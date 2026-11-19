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
var _daily_board: Board
var _slots: Dictionary[String, TextureButton] = {}
## The slot the restore or convert panel is open for.
var _chosen_slot: String = ""

@onready var _build_label: Label = $TopBar/BuildLabel
@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _parties_label: Label = $TopBar/PartiesLabel
@onready var _floor: Control = $Floor
@onready var _board: QuestBoard = $QuestBoard
@onready var _roster: Roster = $Roster
@onready var _picker: PartyPicker = $PartyPicker
@onready var _restore_panel: Control = $RestorePanel
@onready var _restore_reason: Label = $RestorePanel/Box/Reason
@onready var _restore_button: Button = $RestorePanel/Box/Buttons/Restore
@onready var _convert_panel: ConvertPanel = $ConvertPanel
@onready var _tick: Timer = $Tick


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_build_label.text = BuildInfo.label(version)
	$RestorePanel/Box/Cost.text = "Restore — %d gold · %s" % [Hall.RESTORE_COST_GOLD, Duration.label(Hall.RESTORE_SECONDS)]
	$RestorePanel/Box/Buttons/Cancel.pressed.connect(_restore_panel.hide)
	_restore_button.pressed.connect(_on_restore_pressed)
	_convert_panel.convert_pressed.connect(_on_convert_pressed)
	($TabBar/Hall as Button).button_group.pressed.connect(_on_tab_pressed)
	_board.send_pressed.connect(_on_send_pressed)
	_picker.send_pressed.connect(_on_party_sent)
	_tick.timeout.connect(_on_tick)
	var now := _now()
	_gold = Gold.load_or_start(SAVE_PATH)
	_hall = Hall.load_or_start(SAVE_PATH, now)
	_dispatch = Dispatch.load_or_start(SAVE_PATH, now)
	_daily_board = Board.load_or_start(SAVE_PATH)
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
	# quest (Dispatch.returned_since_checkpoint(now); the checkpoint applies its outcome, the reward
	# or the quarter and an injury, and records it in Dispatch.last_return) and a room restored or
	# converted (Hall.finished_since_checkpoint(now)) are what happened while the app was away.
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
	_dispatch.checkpoint(now, _gold, _hall.first_done_at("infirmary"))
	_hall.checkpoint(now)
	var file := ConfigFile.new()
	_gold.write(file)
	_hall.write(file)
	_dispatch.write(file)
	_daily_board.write(file)
	if file.save(SAVE_PATH) != OK:
		push_error("Could not save to " + SAVE_PATH)
	_gold_label.text = "Gold %d" % _gold.amount
	_parties_label.text = "Parties out %d" % _dispatch.outings.size()
	_show_hall(now)
	_board.show_board(_daily_board.quests(_dispatch, now, _utc_offset_minutes(), _quest_halls(now)), _dispatch, now)
	_roster.show_dispatch(_dispatch, now)
	if _picker.visible:
		_picker.show_dispatch(_dispatch, now)
	if _restore_panel.visible:
		_show_restore_panel(now)
	if _convert_panel.visible:
		_convert_panel.show_hall(_hall, _chosen_slot, _gold, now)


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
			Hall.State.CONVERTING:
				_show_art(button, slot, "restored")
				label.text = Duration.label(_hall.seconds_left(now))
			Hall.State.CONVERTED:
				var type := _hall.room_type(slot)
				_show_art(button, slot, type)
				label.text = Hall.ROOM_TYPES[type]["name"]


func _show_art(button: TextureButton, slot: String, look: String) -> void:
	var path := ROOM_ART % [slot, look]
	if button.texture_normal == null or button.texture_normal.resource_path != path:
		button.texture_normal = load(path)


func _on_slot_pressed(slot: String) -> void:
	var now := _now()
	match _hall.state(slot, now):
		Hall.State.DAMAGED:
			_chosen_slot = slot
			_restore_panel.show()
			_show_restore_panel(now)
		Hall.State.RESTORED:
			_chosen_slot = slot
			_convert_panel.show()
			_convert_panel.show_hall(_hall, slot, _gold, now)


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


func _on_convert_pressed(type: String) -> void:
	var now := _now()
	if _hall.convert_room(_chosen_slot, type, _gold, now):
		_convert_panel.hide()
	_checkpoint(now)


func _on_send_pressed(quest: String) -> void:
	var now := _now()
	_picker.open(quest, _dispatch, now)


# The seed comes from the global generator; the outcome it fixes is rolled from the seed alone.
func _on_party_sent(quest: String, party: PackedStringArray) -> void:
	var now := _now()
	if _daily_board.send(_dispatch, quest, party, randi(), _gold, now, _utc_offset_minutes(), _quest_halls(now), _hall.first_done_at("infirmary")):
		_picker.hide()
	_checkpoint(now)


func _on_tab_pressed(tab: BaseButton) -> void:
	_floor.visible = tab == $TabBar/Hall
	_board.visible = tab == $TabBar/Quests
	_roster.visible = tab == $TabBar/Roster
	_restore_panel.hide()
	_convert_panel.hide()
	_picker.hide()


func _quest_halls(now: int) -> int:
	return _hall.rooms_done("quest_hall", now)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


# Read each time, so the board's day follows a daylight-saving change.
func _utc_offset_minutes() -> int:
	return int(Time.get_time_zone_from_system()["bias"])
