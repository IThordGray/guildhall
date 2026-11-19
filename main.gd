extends Control

const SAVE_PATH: String = "user://save.cfg"

var _gold: Gold
var _hall: Hall
var _dispatch: Dispatch
var _daily_board: Board
## The slot the convert panel is open for.
var _chosen_slot: String = ""

@onready var _build_label: Label = $TopBar/Row/BuildLabel
@onready var _gold_label: Label = $TopBar/Row/GoldLabel
@onready var _parties_label: Label = $TopBar/Row/PartiesLabel
@onready var _hall_view: HallView = $HallView
@onready var _board: QuestBoard = $QuestBoard
@onready var _roster: Roster = $Roster
@onready var _picker: PartyPicker = $PartyPicker
@onready var _convert_panel: ConvertPanel = $ConvertPanel
@onready var _tick: Timer = $Tick


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_build_label.text = BuildInfo.label(version)
	_hall_view.restore_pressed.connect(_on_restore_pressed)
	_hall_view.job_pressed.connect(_on_job_pressed)
	_hall_view.send_pressed.connect(_on_go_send)
	_convert_panel.convert_pressed.connect(_on_convert_pressed)
	($TabBar/Tabs/Hall as Button).button_group.pressed.connect(_on_tab_pressed)
	_board.send_pressed.connect(_on_send_pressed)
	_picker.send_pressed.connect(_on_party_sent)
	_tick.timeout.connect(_on_tick)
	var now := _now()
	_gold = Gold.load_or_start(SAVE_PATH)
	_hall = Hall.load_or_start(SAVE_PATH, now)
	_dispatch = Dispatch.load_or_start(SAVE_PATH, now)
	_daily_board = Board.load_or_start(SAVE_PATH)
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
	_gold_label.text = str(_gold.amount)
	_parties_label.text = str(_dispatch.outings.size())
	var quests := _daily_board.quests(_dispatch, now, _utc_offset_minutes(), _quest_halls(now))
	_hall_view.show_state(_hall, _dispatch, _gold, quests.size(), now)
	_board.show_board(quests, _dispatch, now)
	_roster.show_dispatch(_dispatch, now)
	if _picker.visible:
		_picker.show_dispatch(_dispatch, now)
	if _convert_panel.visible:
		_convert_panel.show_hall(_hall, _chosen_slot, _gold, now)


func _on_restore_pressed(slot: String) -> void:
	var now := _now()
	_hall.restore(slot, _gold, now)
	_checkpoint(now)


func _on_job_pressed(slot: String) -> void:
	_chosen_slot = slot
	_convert_panel.show()
	_convert_panel.show_hall(_hall, slot, _gold, _now())


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


# A tab pressed in code does not signal its group, so the tab is shown here.
func _on_go_send() -> void:
	var quests_tab := $TabBar/Tabs/Quests as Button
	quests_tab.button_pressed = true
	_on_tab_pressed(quests_tab)


func _on_tab_pressed(tab: BaseButton) -> void:
	_hall_view.visible = tab == $TabBar/Tabs/Hall
	_board.visible = tab == $TabBar/Tabs/Quests
	_roster.visible = tab == $TabBar/Tabs/Roster
	_convert_panel.hide()
	_picker.hide()


func _quest_halls(now: int) -> int:
	return _hall.rooms_done("quest_hall", now)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


# Read each time, so the board's day follows a daylight-saving change.
func _utc_offset_minutes() -> int:
	return int(Time.get_time_zone_from_system()["bias"])
