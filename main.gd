extends Control

const SAVE_PATH: String = "user://save.cfg"
## The landscape rail, which holds the gold and the tabs.
const RAIL_WIDTH_PX: float = 200.0
## In landscape, the space between the screens and the rail or the window's sides, and between
## the board and the party picker.
const SIDE_MARGIN_PX: float = 44.0
## In landscape, the space between the screens and the window's top and bottom.
const END_MARGIN_PX: float = 32.0
## In landscape, Roster, Debrief and Level up are a centred column at most this wide.
const COLUMN_WIDTH_PX: float = 1100.0
## In landscape, the share of the body's width the quest board takes; the party picker has the rest.
const BOARD_SHARE: float = 0.42

var _gold: Gold
var _hall: Hall
var _dispatch: Dispatch
var _daily_board: Board
## The slot the convert panel is open for.
var _chosen_slot: String = ""
## Where the debrief the Debrief screen shows is in Dispatch.debriefs.
var _open_debrief: int = -1
## The adventurer the Adventurer screen shows.
var _shown_adventurer: String = ""
## Whether the window is wider than tall, so the landscape layout shows.
var _landscape: bool = false
## Each part that moves with the orientation: its portrait anchors and offsets as main.tscn has
## them, each a Vector4 of left, top, right, bottom.
var _portrait_places: Dictionary[Control, Array] = {}

@onready var _top_bar: Control = $TopBar
@onready var _build_label: Label = $TopBar/Row/BuildLabel
@onready var _gold_label: Label = $TopBar/Row/GoldLabel
@onready var _parties_label: Label = $TopBar/Row/PartiesLabel
@onready var _body: Control = $Body
@onready var _hall_view: HallView = $Body/HallView
@onready var _board: QuestBoard = $Body/QuestBoard
@onready var _debrief: Debrief = $Body/Debrief
@onready var _tab_bar: PanelContainer = $TabBar
@onready var _tabs: BoxContainer = $TabBar/Tabs
@onready var _rail_gold: Control = $TabBar/Tabs/Gold
@onready var _rail_gold_label: Label = $TabBar/Tabs/Gold/Label
@onready var _debrief_badge: Label = $TabBar/Tabs/Quests/Badge
@onready var _roster: Roster = $Body/Roster
@onready var _adventurer: Adventurer = $Body/Adventurer
@onready var _level_up: LevelUp = $Body/LevelUp
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
	_board.debrief_pressed.connect(_on_debrief_pressed)
	_debrief.done_pressed.connect(_on_debrief_done)
	_picker.send_pressed.connect(_on_party_sent)
	_roster.adventurer_pressed.connect(_on_adventurer_pressed)
	_adventurer.back_pressed.connect(_on_adventurer_back)
	_adventurer.level_up_pressed.connect(_on_level_up_pressed)
	_adventurer.wear_pressed.connect(_on_wear_pressed)
	_level_up.continue_pressed.connect(_on_level_up_continue)
	_tick.timeout.connect(_on_tick)
	for part: Control in [_tab_bar, _body, _board, _debrief, _roster, _adventurer, _level_up, _picker]:
		_portrait_places[part] = [
			Vector4(part.anchor_left, part.anchor_top, part.anchor_right, part.anchor_bottom),
			Vector4(part.offset_left, part.offset_top, part.offset_right, part.offset_bottom),
		]
	get_window().size_changed.connect(_lay_out)
	_lay_out()
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
	# A party back from its quest while the app was away needs nothing here: the checkpoint applies
	# its outcome and adds its debrief, and the debriefs waiting on the Quests screen are the return
	# summary. A summary of a room restored or converted while away
	# (Hall.finished_since_checkpoint(now)) goes here, before _checkpoint folds the absence in.
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
	_rail_gold_label.text = _gold_label.text
	_parties_label.text = str(_dispatch.outings.size())
	_debrief_badge.text = str(_dispatch.debriefs.size())
	_debrief_badge.visible = not _dispatch.debriefs.is_empty()
	var quests := _daily_board.quests(_dispatch, now, _utc_offset_minutes(), _quest_halls(now))
	_hall_view.show_state(_hall, _dispatch, _gold, quests.size(), now)
	_board.show_board(quests, _dispatch, now)
	_roster.show_dispatch(_dispatch, now)
	if _adventurer.visible:
		_adventurer.show_adventurer(_shown_adventurer, _dispatch, now)
	if _picker.visible and _picker.has_quest():
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
		_picker.close()
	_checkpoint(now)


func _on_debrief_pressed(index: int) -> void:
	_open_debrief = index
	_debrief.show_debrief(_dispatch.debriefs[index], _dispatch.adventurers)
	_board.hide()
	_debrief.show()
	_show_picker()


func _on_debrief_done() -> void:
	_dispatch.read_debrief(_open_debrief)
	_debrief.hide()
	_board.show()
	_show_picker()
	_checkpoint(_now())


func _on_adventurer_pressed(adventurer: String) -> void:
	_shown_adventurer = adventurer
	_adventurer.show_adventurer(adventurer, _dispatch, _now())
	_roster.hide()
	_adventurer.show()


func _on_adventurer_back() -> void:
	_adventurer.hide()
	_roster.show()


func _on_level_up_pressed(adventurer: String) -> void:
	var gains := _dispatch.adventurers.level_up(adventurer)
	if gains.is_empty():
		return
	_level_up.show_level_up(adventurer, gains, _dispatch.adventurers)
	_adventurer.hide()
	_level_up.show()
	_checkpoint(_now())


func _on_wear_pressed(adventurer: String, index: int) -> void:
	_dispatch.wear(adventurer, index)
	_checkpoint(_now())


func _on_level_up_continue() -> void:
	_level_up.hide()
	_adventurer.show_adventurer(_shown_adventurer, _dispatch, _now())
	_adventurer.show()


# A tab pressed in code does not signal its group, so the tab is shown here.
func _on_go_send() -> void:
	var quests_tab := $TabBar/Tabs/Quests as Button
	quests_tab.button_pressed = true
	_on_tab_pressed(quests_tab)


func _on_tab_pressed(tab: BaseButton) -> void:
	_hall_view.visible = tab == $TabBar/Tabs/Hall
	_board.visible = tab == $TabBar/Tabs/Quests
	_debrief.hide()
	_roster.visible = tab == $TabBar/Tabs/Roster
	_adventurer.hide()
	_level_up.hide()
	_convert_panel.hide()
	_picker.close()
	_show_picker()


# The window's shape picks the layout, wider than tall being landscape: the rail instead of the
# top and bottom bars, and screens side by side. The design size turns with the window, so its
# short side stays the same either way.
func _lay_out() -> void:
	var window := get_window()
	var landscape := window.size.x > window.size.y
	if landscape == _landscape:
		return
	_landscape = landscape
	var portrait_size := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	window.content_scale_size = Vector2i(portrait_size.y, portrait_size.x) if landscape else portrait_size
	_top_bar.visible = not landscape
	_rail_gold.visible = landscape
	_tabs.vertical = landscape
	_tab_bar.theme_type_variation = &"Rail" if landscape else &"BottomBar"
	_hall_view.set_landscape(landscape)
	_board.set_landscape(landscape)
	_adventurer.set_landscape(landscape)
	_picker.set_landscape(landscape)
	if not landscape:
		for part: Control in _portrait_places:
			_place(part, _portrait_places[part][0], _portrait_places[part][1])
	else:
		var full := Vector4(0, 0, 1, 1)
		_place(_tab_bar, Vector4(0, 0, 0, 1), Vector4(0, 0, RAIL_WIDTH_PX, 0))
		_place(_body, full, Vector4(RAIL_WIDTH_PX + SIDE_MARGIN_PX, END_MARGIN_PX, -SIDE_MARGIN_PX, -END_MARGIN_PX))
		_place(_board, Vector4(0, 0, BOARD_SHARE, 1), Vector4(0, 0, -SIDE_MARGIN_PX / 2, 0))
		_place(_adventurer, full, Vector4.ZERO)
		for column: Control in [_debrief, _roster, _level_up]:
			_place(column, Vector4(0.5, 0, 0.5, 1), Vector4(-COLUMN_WIDTH_PX / 2, 0, COLUMN_WIDTH_PX / 2, 0))
		# The picker is not in the body, so it is placed against the window: from half a gap right
		# of the board's edge, BOARD_SHARE of the way across the body, to the body's right edge.
		var body_left := RAIL_WIDTH_PX + SIDE_MARGIN_PX
		var picker_left := body_left - BOARD_SHARE * (body_left + SIDE_MARGIN_PX) + SIDE_MARGIN_PX / 2
		_place(_picker, Vector4(BOARD_SHARE, 0, 1, 1), Vector4(picker_left, END_MARGIN_PX, -SIDE_MARGIN_PX, -END_MARGIN_PX))
	_show_picker()


# Sets `control`'s anchors and offsets, each given as left, top, right, bottom. Anchors pushed
# past their opposite on the way are set again after, so the order of sides does not matter.
static func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.set_anchor_and_offset(SIDE_LEFT, anchors.x, offsets.x, true)
	control.set_anchor_and_offset(SIDE_TOP, anchors.y, offsets.y, true)
	control.set_anchor_and_offset(SIDE_RIGHT, anchors.z, offsets.z, true)
	control.set_anchor_and_offset(SIDE_BOTTOM, anchors.w, offsets.w, true)


# In landscape the party picker sits beside the board whenever the board shows, prompting for a
# quest until one is picked; in portrait it pops up over the board only while a quest is picked.
func _show_picker() -> void:
	_picker.visible = _board.visible and (_landscape or _picker.has_quest())


func _quest_halls(now: int) -> int:
	return _hall.rooms_done("quest_hall", now)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


# Read each time, so the board's day follows a daylight-saving change.
func _utc_offset_minutes() -> int:
	return int(Time.get_time_zone_from_system()["bias"])
