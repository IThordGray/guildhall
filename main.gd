extends Control

const SAVE_PATH: String = "user://save.cfg"

var _gold: Gold

@onready var _build_label: Label = $BuildLabel
@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _away_message: Button = $AwayMessage
@onready var _tick: Timer = $Tick


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_build_label.text = BuildInfo.label(version)
	_away_message.pressed.connect(_away_message.hide)
	_tick.timeout.connect(_on_tick)
	_gold = Gold.load_or_start(SAVE_PATH, _now())
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
	var away_gold := _gold.away_report(now)
	if away_gold > 0:
		_away_message.text = "While you were away: +%d gold" % away_gold
		_away_message.show()
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
	_gold.checkpoint(now)
	if _gold.save(SAVE_PATH) != OK:
		push_error("Could not save to " + SAVE_PATH)
	_gold_label.text = "Gold %d" % _gold.saved


func _now() -> int:
	return int(Time.get_unix_time_from_system())
