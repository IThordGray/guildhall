extends Control

## Where the guild is saved. Tests point it elsewhere, so they never touch the player's save.
static var save_path: String = "user://save.cfg"

## The landscape rail, which holds the gold and the tabs.
const RAIL_WIDTH_PX: float = 200.0
## In landscape, the space between the screens and the rail or the window's sides, and between
## the board and the party picker.
const SIDE_MARGIN_PX: float = 44.0
## In landscape, the space between the screens and the window's top and bottom.
const END_MARGIN_PX: float = 32.0
## In landscape, Level up, the Armory and the swap pick are a centred column at most this wide.
const COLUMN_WIDTH_PX: float = 1100.0
## In landscape, the share of the body's width the quest board or the labyrinth takes; the party
## picker has the rest.
const BOARD_SHARE: float = 0.42
## How long the "+N" from a collected Tavern or a claimed goal takes to rise to the gold counter and
## fade.
const COLLECT_SECONDS: float = 0.6
## How much the gold counter grows when collected gold reaches it.
const COLLECT_PULSE_SCALE: float = 1.3
## What the confirmation sheet asks about when it confirms sending `_leaving` away: dismissing them,
## or swapping them for the walk-in.
const DISMISS: String = "dismiss"
const SWAP: String = "swap"
## What the confirmation sheet asks about when it confirms selling `_item` from the stash to make
## room for the loot waiting at `_loot`, letting that loot go, or selling `_item`.
const SWAP_LOOT: String = "swap_loot"
const LET_GO: String = "let_go"
const SELL: String = "sell"
## What the confirmation sheet asks about when it confirms upgrading the room `_upgrading`.
const UPGRADE: String = "upgrade"
## What the confirmation sheet asks about when it confirms ranking the guild up.
const RANK_UP: String = "rank_up"
## Play-testing only: the speeds the Test speed control cycles through.
const TEST_SPEEDS: Array[int] = [1, 10, 60]

var _clock: GameClock
var _gold: Gold
var _hall: Hall
var _dispatch: Dispatch
var _quest_board: Board
var _recruits: Recruits
var _walk_ins: WalkIns
var _goals: Goals
## The slot the Give it a job screen is open for.
var _chosen_slot: String = ""
## What the confirmation sheet asks about: the damaged slot to restore, Hall.EXTENSION, UPGRADE,
## RANK_UP, DISMISS, SWAP, SWAP_LOOT, LET_GO or SELL.
var _confirming: String = ""
## The adventurer DISMISS or SWAP sends away.
var _leaving: String = ""
## Where the loot SWAP_LOOT stows or LET_GO lets go is in Dispatch.waiting_loot.
var _loot: int = -1
## The stash item SWAP_LOOT or SELL sells.
var _item: String = ""
## The room UPGRADE upgrades.
var _upgrading: String = ""
## The adventurer the Adventurer screen shows, or last showed.
var _shown_adventurer: String = ""
## The candidate's slot, or Roster.WALK_IN, the Adventurer screen shows instead; Roster.NO_VISITOR
## while it shows an adventurer. Who they were when opened, so their leaving is seen even when
## someone new takes their place.
var _shown_visitor: int = Roster.NO_VISITOR
var _visitor_who: Dictionary = {}
## The screen the Adventurer screen's Back returns to, the Roster; or the Quests screen while Level
## up is open from it, which Continue then returns to.
var _adventurer_from: Control
## The screen the party picker sends from and goes back to: the Quests board or the Labyrinth.
var _picker_from: Control
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
@onready var _tab_bar: PanelContainer = $TabBar
@onready var _tabs: BoxContainer = $TabBar/Tabs
@onready var _rail_gold: Control = $TabBar/Tabs/Gold
@onready var _rail_gold_label: Label = $TabBar/Tabs/Gold/Label
@onready var _needs_you_badge: Label = $TabBar/Tabs/Quests/Badge
@onready var _walk_in_badge: Label = $TabBar/Tabs/Roster/Badge
@onready var _roster: Roster = $Body/Roster
@onready var _adventurer: Adventurer = $Body/Adventurer
@onready var _level_up: LevelUp = $Body/LevelUp
@onready var _armory: Armory = $Body/Armory
@onready var _reception: Reception = $Body/Reception
@onready var _swap_pick: SwapPick = $Body/SwapPick
@onready var _picker: PartyPicker = $Body/PartyPicker
@onready var _labyrinth: LabyrinthScreen = $Body/Labyrinth
@onready var _labyrinth_tab: Button = $TabBar/Tabs/Labyrinth
@onready var _convert_panel: ConvertPanel = $Body/ConvertPanel
@onready var _confirm_sheet: ConfirmSheet = $ConfirmSheet
@onready var _tick: Timer = $Tick
@onready var _start: StartScreen = $Start
@onready var _test_speed: Button = $TopBar/Row/TestSpeed


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_build_label.text = BuildInfo.label(version)
	_hall_view.restore_pressed.connect(_confirm)
	_hall_view.job_pressed.connect(_on_job_pressed)
	_hall_view.send_pressed.connect(_on_go_send)
	_hall_view.collect_pressed.connect(_on_collect_pressed)
	_hall_view.extend_pressed.connect(_confirm.bind(Hall.EXTENSION))
	_hall_view.upgrade_pressed.connect(func(slot: String) -> void:
		_upgrading = slot
		_confirm(UPGRADE))
	_hall_view.reception_pressed.connect(_open_reception)
	_hall_view.goals_card.claim_pressed.connect(_on_claim_pressed)
	_reception.back_pressed.connect(_close_reception)
	_reception.rank_up_pressed.connect(_confirm.bind(RANK_UP))
	_confirm_sheet.confirmed.connect(_on_confirmed)
	_convert_panel.convert_pressed.connect(_on_convert_pressed)
	_convert_panel.back_pressed.connect(_close_convert)
	($TabBar/Tabs/Hall as Button).button_group.pressed.connect(_on_tab_pressed)
	_board.send_pressed.connect(_on_send_pressed)
	_board.swap_pressed.connect(_on_loot_swap_pressed)
	_board.let_go_pressed.connect(_on_let_go_pressed)
	_board.level_up_pressed.connect(_on_quests_level_up_pressed)
	# The checkpoint before brings the party up to now as it was set; the one after sends it at once
	# when it is ready.
	_board.auto_toggled.connect(func(party: String, on: bool) -> void:
		var now := _now()
		_checkpoint(now)
		_dispatch.adventurers.parties.set_auto(party, on)
		_checkpoint(now))
	_board.mode_toggled.connect(func(party: String) -> void:
		var now := _now()
		_checkpoint(now)
		var parties := _dispatch.adventurers.parties
		parties.set_mode(party, Parties.BOLD if parties.mode(party) == Parties.SAFE else Parties.SAFE)
		_checkpoint(now))
	_picker.send_pressed.connect(_on_party_sent)
	_picker.back_pressed.connect(_close_picker)
	_picker.quest_left.connect(_close_picker)
	_labyrinth.send_pressed.connect(_on_floor_pressed)
	_roster.adventurer_pressed.connect(_open_adventurer.bind(_roster))
	_roster.hire_pressed.connect(_on_hire_pressed)
	_roster.visitor_pressed.connect(_open_visitor)
	_roster.armory_pressed.connect(_on_armory_pressed)
	_roster.accept_pressed.connect(_on_accept_pressed)
	_roster.turn_away_pressed.connect(_on_turn_away_pressed)
	_roster.swap_pressed.connect(_on_swap_pressed)
	_roster.reroll_pressed.connect(func(party: String) -> void:
		_dispatch.adventurers.parties.reroll(party)
		_checkpoint(_now()))
	_roster.name_typed.connect(func(party: String, typed: String) -> void:
		_dispatch.adventurers.parties.rename(party, typed)
		_checkpoint(_now()))
	# A move changes the ranks of the parties it touches, so the checkpoint before fills the board's
	# slots due by now with the parties as they were.
	_adventurer.party_pressed.connect(func(adventurer: String, to: String) -> void:
		var now := _now()
		_checkpoint(now)
		_dispatch.adventurers.parties.move(adventurer, to, _dispatch)
		_checkpoint(now))
	_swap_pick.picked.connect(_on_swap_picked)
	_swap_pick.back_pressed.connect(_close_swap_pick)
	_adventurer.dismiss_pressed.connect(_on_dismiss_pressed)
	_armory.back_pressed.connect(_on_armory_back)
	_armory.sell_pressed.connect(_on_sell_pressed)
	_adventurer.back_pressed.connect(_on_adventurer_back)
	_adventurer.level_up_pressed.connect(_on_level_up_pressed)
	_adventurer.promote_pressed.connect(_on_promote_pressed)
	_adventurer.wear_pressed.connect(_on_wear_pressed)
	_adventurer.take_off_pressed.connect(_on_take_off_pressed)
	_adventurer.train_pressed.connect(_on_train_pressed)
	_adventurer.stop_training_pressed.connect(_on_stop_training_pressed)
	_adventurer.swiped.connect(_on_adventurer_swiped)
	_adventurer.tray_toggled.connect(_on_adventurer_tray_toggled)
	_adventurer.hire_pressed.connect(func() -> void: _on_hire_pressed(_shown_visitor))
	_adventurer.accept_pressed.connect(_on_accept_pressed)
	_adventurer.turn_away_pressed.connect(_on_turn_away_pressed)
	_adventurer.swap_pressed.connect(_on_swap_pressed)
	_level_up.continue_pressed.connect(_on_level_up_continue)
	_tick.timeout.connect(_on_tick)
	_test_speed.pressed.connect(_on_test_speed_pressed)
	_start.continue_pressed.connect(_open_game)
	_start.new_game_pressed.connect(_on_new_game)
	for part: Control in [_tab_bar, _body, _board, _labyrinth, _roster, _adventurer, _level_up, _armory, _reception, _swap_pick, _convert_panel, _picker]:
		_portrait_places[part] = [
			Vector4(part.anchor_left, part.anchor_top, part.anchor_right, part.anchor_bottom),
			Vector4(part.offset_left, part.offset_top, part.offset_right, part.offset_bottom),
		]
	_picker_from = _board
	get_window().size_changed.connect(_lay_out)
	_lay_out()
	_start.show_start(FileAccess.file_exists(save_path))


func _on_new_game() -> void:
	DirAccess.remove_absolute(save_path)
	_open_game()


# Loads the saved guild, or starts a fresh one when there is no save, and starts the tick.
func _open_game() -> void:
	_start.queue_free()
	_clock = GameClock.load_or_start(save_path)
	var now := _now()
	_gold = Gold.load_or_start(save_path)
	_hall = Hall.load_or_start(save_path, now)
	_dispatch = Dispatch.load_or_start(save_path, now)
	_dispatch.gold = _gold
	QuestBoard.worn = _dispatch.adventurers.gear.worn
	_quest_board = Board.load_or_start(save_path)
	_recruits = Recruits.load_or_start(save_path)
	_walk_ins = WalkIns.load_or_start(save_path)
	_goals = Goals.load_or_start(save_path)
	# What the Reception gives the guild depends on the hall the save holds; the stash's size
	# follows the hall at each checkpoint.
	_quest_board.reception_slots = _hall.reception("board_slots")
	_recruits.reception_slots = _hall.reception("candidate_slots")
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
	_clock.arrive(Time.get_unix_time_from_system())
	var now := _now()
	# A party back from its quest while the app was away needs nothing here: the checkpoint applies
	# its outcome and pays it, and only loot that found the stash full waits on the Quests screen. A
	# summary of a room restored or converted while away
	# (Hall.finished_since_checkpoint(now)) goes here, before _checkpoint folds the absence in.
	_checkpoint(now)
	_tick.start()


func _leave() -> void:
	if _tick.is_stopped():
		return
	_checkpoint(_now())
	_clock.leave(Time.get_unix_time_from_system())
	_tick.stop()


# Saving every tick keeps the save within a second of the moment the app was left: a web reload
# sends no notification, and a save made while the page unloads may never reach IndexedDB.
func _on_tick() -> void:
	_checkpoint(_now())


func _checkpoint(now: int) -> void:
	_hall.checkpoint(now)
	_dispatch.adventurers.gear.stash_cap = _hall.stash_cap(now)
	Auto.checkpoint(_dispatch, _quest_board, now, _hall.added_at("board_slots"), _hall.first_done_at("infirmary"), _hall.first_done_at("map_room"), _hall.rank, _goals.is_unlocked(Goals.AUTO))
	_goals.count_home(_dispatch)
	_recruits.refill(_dispatch.adventurers, now, _hall.added_at("candidate_slots"), _walk_ins.waiting_name(), _hall.ranked_at.get("E", -1))
	_walk_ins.refill(_dispatch.adventurers, _recruits, now, _hall.ranked_at.get("E", -1))
	var file := ConfigFile.new()
	_clock.write(file, Time.get_unix_time_from_system())
	_gold.write(file)
	_hall.write(file)
	_dispatch.write(file)
	_quest_board.write(file)
	_recruits.write(file)
	_walk_ins.write(file)
	_goals.write(file)
	if file.save(save_path) != OK:
		push_error("Could not save to " + save_path)
	_gold_label.text = str(_gold.amount)
	_rail_gold_label.text = _gold_label.text
	_parties_label.text = str(_dispatch.outings.size())
	var needs_you := _dispatch.needs_you_count()
	_needs_you_badge.text = str(needs_you)
	_needs_you_badge.visible = needs_you > 0
	_walk_in_badge.visible = not _walk_ins.walk_in.is_empty()
	_hall_view.show_state(_hall, _dispatch, _quest_board.filled(), now)
	_hall_view.goals_card.show_goals(_goals, _dispatch, _hall, _dispatch.story_done, now)
	var story := _dispatch.open_story_quests(_goals.unlocked)
	_board.show_board(_quest_board, _dispatch, now, _goals.is_unlocked(Goals.AUTO), story)
	_picker.show_board(_quest_board, story, _dispatch.open_floors(_goals.unlocked))
	_labyrinth_tab.disabled = not _goals.is_unlocked(Labyrinth.UNLOCK)
	if _labyrinth.visible:
		_labyrinth.show_labyrinth(_dispatch, _goals.unlocked, now)
	_roster.show_dispatch(_dispatch, now)
	_roster.show_recruits(_recruits, _dispatch.adventurers, _gold, _hall.beds(now), _hall, now)
	_roster.show_walk_in(_walk_ins.walk_in, _dispatch.adventurers.roster.size() < _hall.beds(now))
	if _adventurer.visible:
		_show_adventurer(now)
	if _armory.visible:
		_armory.show_gear(_dispatch.adventurers)
	if _reception.visible:
		_reception.show_guild(_hall, _dispatch, now)
	if _swap_pick.visible:
		# The walk-in may have left, replaced by the next, whom the pick then names.
		if _walk_ins.walk_in.is_empty():
			_close_swap_pick()
		else:
			_swap_pick.show_dispatch(_walk_ins.waiting_name(), _dispatch, now)
	if _picker.visible and _picker.has_quest():
		_picker.show_dispatch(_dispatch, now)
	if _convert_panel.visible:
		_convert_panel.show_hall(_hall, _chosen_slot, _gold, now)
	if _confirm_sheet.visible:
		_offer(now)


# Asks to confirm `what`, any of `_confirming`'s, before doing it.
func _confirm(what: String) -> void:
	_confirming = what
	_offer(_now())


# What `_confirming` costs and takes, and why it can't be done at `now`.
func _offer(now: int) -> void:
	if _confirming == SWAP and _walk_ins.walk_in.is_empty():
		_confirm_sheet.close()
	elif _confirming == DISMISS or _confirming == SWAP:
		var leaving: String = _dispatch.adventurers.roster[_leaving]["name"]
		var gone := _dispatch.adventurers.gear.leaving_with(_leaving)
		var note := "" if gone == 0 else ("1 item leaves with them" if gone == 1 else "%d items leave with them" % gone)
		if _confirming == DISMISS:
			_confirm_sheet.ask("Dismiss " + leaving, note, "Dismiss", _dispatch.dismiss_refusal(_leaving))
		else:
			_confirm_sheet.ask("Swap %s for %s" % [leaving, _walk_ins.waiting_name()], note, "Swap", _dispatch.dismiss_refusal(_leaving))
	elif _confirming == SWAP_LOOT:
		var swapping_in: String = Gear.ITEMS[_dispatch.waiting_loot[_loot]["item"]]["name"]
		_confirm_sheet.ask("Swap %s for %s" % [Gear.ITEMS[_item]["name"], swapping_in], "+%d gold" % Gear.price(_item), "Swap", _dispatch.adventurers.gear.sell_refusal(_item))
	elif _confirming == LET_GO:
		_confirm_sheet.ask("Let the %s go" % Gear.ITEMS[_dispatch.waiting_loot[_loot]["item"]]["name"], "", "Let it go", "")
	elif _confirming == SELL:
		_confirm_sheet.ask("Sell " + Gear.ITEMS[_item]["name"], "+%d gold" % Gear.price(_item), "Sell", _dispatch.adventurers.gear.sell_refusal(_item))
	elif _confirming == Hall.EXTENSION:
		_confirm_sheet.offer("Build the first floor", Hall.EXTEND_GOLD, Hall.EXTEND_SECONDS, "Extend", _hall.extend_refusal(_gold, now))
	elif _confirming == RANK_UP:
		var rank_up: Dictionary = Hall.RANK_UPS[_hall.rank]
		_confirm_sheet.ask("Rank up to " + rank_up["to"], "%d gold" % rank_up["gold"], "Rank up", _hall.rank_up_refusal(_dispatch.reputation, _gold, _dispatch.adventurers.parties.parties.size(), _dispatch.story_done, now))
	elif _confirming == UPGRADE:
		var next := _hall.next_upgrade(_upgrading, now)
		var info: Dictionary = Hall.ROOM_TYPES[_hall.room_type(_upgrading)]
		_confirm_sheet.offer("Upgrade " + info["name"], next["gold"], next["seconds"], "Upgrade", _hall.upgrade_refusal(_upgrading, _gold, now), next.get("blurb", ""))
	else:
		var next := _hall.next_restore()
		_confirm_sheet.offer("Restore " + HallView.slot_name(_hall, _confirming), next["gold"], next["seconds"], "Restore", _hall.refusal(_confirming, _gold, now))


func _on_confirmed() -> void:
	var now := _now()
	if _confirming == DISMISS or _confirming == SWAP:
		_send_away(now)
		return
	if _confirming == SWAP_LOOT:
		_dispatch.swap_loot(_loot, _item)
	elif _confirming == LET_GO:
		_dispatch.let_loot_go(_loot)
	elif _confirming == SELL:
		_dispatch.adventurers.gear.sell(_item, _gold)
	elif _confirming == Hall.EXTENSION:
		_hall.extend(_gold, now)
	elif _confirming == RANK_UP:
		# The checkpoint before brings the board, candidates and walk-ins up to now at the old rank.
		_checkpoint(now)
		_hall.rank_up(_dispatch.reputation, _gold, _dispatch.adventurers.parties.parties.size(), _dispatch.story_done, now)
	elif _confirming == UPGRADE:
		_hall.upgrade(_upgrading, _gold, now)
	else:
		_hall.restore(_confirming, _gold, now)
	_confirm_sheet.close()
	_checkpoint(now)


# Dismisses `_leaving`, or swaps them for the walk-in, as `_confirming` says. The checkpoint before
# fills the board's slots due by now with the guild as it was, so only refills after it can follow a
# top rank that leaves.
func _send_away(now: int) -> void:
	_checkpoint(now)
	var gone := false
	if _confirming == DISMISS:
		gone = _dispatch.dismiss(_leaving)
	elif not _walk_ins.walk_in.is_empty():
		gone = _walk_ins.swap(_leaving, _dispatch, _hall.beds(now))
	_confirm_sheet.close()
	if gone:
		if _adventurer.visible:
			_on_adventurer_back()
		if _swap_pick.visible:
			_close_swap_pick()
	_checkpoint(now)


func _on_collect_pressed(slot: String) -> void:
	var now := _now()
	var amount := _hall.collect(slot, _gold, now)
	_checkpoint(now)
	if amount > 0:
		_show_collected(amount, _hall_view.room_center(slot))


# The checkpoint before brings what the goal counts up to now; the one after shows its reward and
# what it unlocked, and the next goals. Its gold rises from its Claim button, at `from`.
func _on_claim_pressed(goal: String, from: Vector2) -> void:
	var now := _now()
	_checkpoint(now)
	var claimed := _goals.claim(goal, _dispatch, _hall, _dispatch.story_done, now)
	_checkpoint(now)
	if claimed:
		_show_collected(Goals.GOALS[goal]["gold"], from)


# Purely a show of gold already added: a "+N" rises from `from` to the gold counter and fades,
# and the counter swells briefly. Each part frees or settles itself when its tween ends.
func _show_collected(amount: int, from: Vector2) -> void:
	var counter := _rail_gold_label if _landscape else _gold_label
	var rise := Label.new()
	rise.text = "+%d" % amount
	rise.theme_type_variation = &"GoldAmount"
	rise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rise)
	var half := rise.get_combined_minimum_size() / 2
	rise.global_position = from - half
	var fly := rise.create_tween().set_parallel()
	fly.tween_property(rise, "global_position", counter.get_global_rect().get_center() - half, COLLECT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(rise, "modulate:a", 0.0, COLLECT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.chain().tween_callback(rise.queue_free)
	# The counter swells as the "+N" reaches it.
	counter.pivot_offset = counter.size / 2
	var pulse := counter.create_tween()
	pulse.tween_interval(COLLECT_SECONDS / 2)
	pulse.tween_property(counter, "scale", Vector2.ONE * COLLECT_PULSE_SCALE, COLLECT_SECONDS / 4)
	pulse.tween_property(counter, "scale", Vector2.ONE, COLLECT_SECONDS / 4)


func _on_job_pressed(slot: String) -> void:
	_chosen_slot = slot
	_convert_panel.show_hall(_hall, slot, _gold, _now())
	_hall_view.hide()
	_convert_panel.show()


func _on_convert_pressed(type: String) -> void:
	var now := _now()
	if _hall.convert_room(_chosen_slot, type, _gold, now):
		_close_convert()
	_checkpoint(now)


func _close_convert() -> void:
	_convert_panel.hide()
	_hall_view.show()


func _open_reception() -> void:
	_reception.show_guild(_hall, _dispatch, _now())
	_hall_view.hide()
	_reception.show()


func _close_reception() -> void:
	_reception.hide()
	_hall_view.show()


func _on_send_pressed(quest: String) -> void:
	var now := _now()
	_picker.open(quest, _dispatch, now)
	_show_with_picker(_board, true)


func _on_floor_pressed(floor_id: String) -> void:
	_picker.open(floor_id, _dispatch, _now())
	_show_with_picker(_labyrinth, true)


# The seed comes from the global generator; the outcome it fixes is rolled from the seed alone. The
# outing, the last to leave, counts towards Goals' hand sends once it is home. A story quest goes
# while it is open, and a floor while it is open, with no board slot.
func _on_party_sent(quest: String, party: PackedStringArray) -> void:
	var now := _now()
	# Auto sends due by now go first, and a Quest hall finished since the last tick adds its slot.
	_checkpoint(now)
	var sent := false
	if Dispatch.is_story(quest):
		sent = quest in _dispatch.open_story_quests(_goals.unlocked) and _dispatch.send(quest, party, randi(), now, _hall.first_done_at("infirmary"))
	elif Dispatch.is_floor(quest):
		sent = quest in _dispatch.open_floors(_goals.unlocked) and _dispatch.send(quest, party, randi(), now, _hall.first_done_at("infirmary"))
	else:
		sent = _quest_board.send(_dispatch, quest, party, randi(), now, _hall.added_at("board_slots"), _hall.first_done_at("infirmary"), _hall.first_done_at("map_room"), _hall.rank)
	if sent:
		_goals.sent_by_hand(_dispatch.outings.back())
		_close_picker()
	_checkpoint(now)


# Back to the Quests or Labyrinth screen it was opened from, or, in landscape, its prompt; when
# another screen shows instead, it stays.
func _close_picker() -> void:
	_picker.close()
	_show_with_picker(_picker_from, _picker_from.visible or _picker.visible)


# Opens `adventurer` from `from`, the Roster, which Back returns to. In landscape the roster stays
# beside them, without Back, unless their tray is open.
func _open_adventurer(adventurer: String, from: Control) -> void:
	_shown_visitor = Roster.NO_VISITOR
	_shown_adventurer = adventurer
	_adventurer_from = from
	var beside := _landscape and from == _roster
	_adventurer.set_landscape(_landscape, beside)
	_show_adventurer(_now())
	from.visible = beside and not _adventurer.tray_open()
	_adventurer.show()


# The Roster tab. In landscape, the roster beside the adventurer last shown while they are still in
# the guild, else the first in roster order; in portrait, the roster alone.
func _show_roster() -> void:
	_shown_visitor = Roster.NO_VISITOR
	if not _landscape:
		_roster.show()
		return
	var roster := _dispatch.adventurers.roster
	_open_adventurer(_shown_adventurer if roster.has(_shown_adventurer) else roster.keys()[0], _roster)


# Opens the candidate in slot `visitor`, or the walk-in for Roster.WALK_IN, on the Adventurer
# screen: in landscape beside the roster, in portrait on its own with Back to it.
func _open_visitor(visitor: int) -> void:
	_shown_visitor = visitor
	_visitor_who = _visitor(visitor).get("who", {})
	_adventurer_from = _roster
	_adventurer.set_landscape(_landscape, _landscape)
	_show_adventurer(_now())
	_roster.visible = _landscape
	_adventurer.show()


# The candidate in slot `visitor`, or the walk-in for Roster.WALK_IN, as they are now; {} for nobody.
func _visitor(visitor: int) -> Dictionary:
	return _walk_ins.walk_in if visitor == Roster.WALK_IN else _recruits.candidates[visitor]


# Back to the roster once the candidate or walk-in shown has gone: in landscape beside the first
# adventurer.
func _leave_visitor() -> void:
	_shown_visitor = Roster.NO_VISITOR
	if _landscape:
		_open_adventurer(_dispatch.adventurers.roster.keys()[0], _roster)
	else:
		_adventurer.hide()
		_roster.show()


# Beside the roster, the open tray takes the roster's column and gives it back when it closes.
func _on_adventurer_tray_toggled(open: bool) -> void:
	if _adventurer.visible and _landscape and _adventurer_from == _roster:
		_roster.visible = not open


func _on_loot_swap_pressed(index: int, stash_item: String) -> void:
	_loot = index
	_item = stash_item
	_confirm(SWAP_LOOT)


func _on_let_go_pressed(index: int) -> void:
	_loot = index
	_confirm(LET_GO)


func _on_sell_pressed(item: String) -> void:
	_item = item
	_confirm(SELL)


func _on_armory_pressed() -> void:
	_armory.show_gear(_dispatch.adventurers)
	_roster.hide()
	_adventurer.hide()
	_armory.show()


func _on_armory_back() -> void:
	_armory.hide()
	_show_roster()


func _on_hire_pressed(slot: int) -> void:
	var now := _now()
	# A Common room finished since the last tick adds its slot before the hire.
	_hall.checkpoint(now)
	if _recruits.hire(slot, _dispatch.adventurers, _gold, _hall.beds(now), now, _hall.added_at("candidate_slots"), _walk_ins.waiting_name(), _hall.ranked_at.get("E", -1)):
		_open_newcomer()
	_checkpoint(now)


func _on_accept_pressed() -> void:
	var now := _now()
	if _walk_ins.accept(_dispatch.adventurers, _hall.beds(now)):
		_open_newcomer()
	_checkpoint(now)


# Shows who just joined, last in the roster: in landscape beside it, in portrait with Back to it.
func _open_newcomer() -> void:
	_open_adventurer(_dispatch.adventurers.roster.keys().back(), _roster)


# The checkpoint takes a sheet showing the walk-in back to the roster.
func _on_turn_away_pressed() -> void:
	_walk_ins.turn_away()
	_checkpoint(_now())


func _on_swap_pressed() -> void:
	_swap_pick.show_dispatch(_walk_ins.waiting_name(), _dispatch, _now())
	_roster.hide()
	_adventurer.hide()
	_swap_pick.show()


func _on_swap_picked(adventurer: String) -> void:
	_leaving = adventurer
	_confirm(SWAP)


func _close_swap_pick() -> void:
	_swap_pick.hide()
	_show_roster()


func _on_dismiss_pressed(adventurer: String) -> void:
	_leaving = adventurer
	_confirm(DISMISS)


func _on_adventurer_swiped(step: int) -> void:
	_shown_adventurer = Roster.adventurer_after(_shown_adventurer, step, _dispatch.adventurers.roster)
	_show_adventurer(_now())


func _on_adventurer_back() -> void:
	_adventurer.hide()
	_show_roster()


func _on_level_up_pressed(adventurer: String) -> void:
	var gains := _dispatch.adventurers.level_up(adventurer)
	if gains.is_empty():
		return
	_level_up.show_level_up(adventurer, gains, _dispatch.adventurers)
	_roster.hide()
	_adventurer.hide()
	_show_with_picker(_board, false)
	_level_up.show()
	_checkpoint(_now())


# Level up from the Quests screen, whose Continue returns there.
func _on_quests_level_up_pressed(adventurer: String) -> void:
	_adventurer_from = _board
	_on_level_up_pressed(adventurer)


# The checkpoint before the promotion fills the board's slots due by now at the rank before it, so
# only refills after it can draw on the new rank.
func _on_promote_pressed(adventurer: String) -> void:
	var now := _now()
	_checkpoint(now)
	_dispatch.adventurers.promote(adventurer, not _dispatch.quest_of(adventurer).is_empty())
	_checkpoint(now)


# The checkpoint shows the change on the Adventurer screen, which keeps its tray open.
func _on_wear_pressed(adventurer: String, index: int) -> void:
	_dispatch.wear(adventurer, index)
	_checkpoint(_now())


func _on_take_off_pressed(adventurer: String, slot: String) -> void:
	_dispatch.take_off(adventurer, slot)
	_checkpoint(_now())


func _on_train_pressed(adventurer: String) -> void:
	var now := _now()
	_dispatch.train(adventurer, _hall.rooms_done("training_room", now), now)
	_checkpoint(now)


func _on_stop_training_pressed(adventurer: String) -> void:
	var now := _now()
	_dispatch.stop_training(adventurer, now)
	_checkpoint(now)


# Shows the adventurer the Adventurer screen is on, as they are at `now`, their row marked while
# the roster is beside them.
func _show_adventurer(now: int) -> void:
	if _shown_visitor != Roster.NO_VISITOR:
		_show_visitor(now)
		return
	_adventurer.show_adventurer(_shown_adventurer, _dispatch, _hall.rooms_done("training_room", now), now)
	_roster.mark(_shown_adventurer if _landscape and _adventurer_from == _roster else "")


# Shows the candidate or walk-in the Adventurer screen is on, as they are at `now`, their card marked
# while the roster is beside them; or, once they have gone, the roster.
func _show_visitor(now: int) -> void:
	var visitor := _visitor(_shown_visitor)
	if visitor.is_empty() or visitor["who"] != _visitor_who:
		_leave_visitor()
		return
	var beds := _hall.beds(now)
	var walk_in := _shown_visitor == Roster.WALK_IN
	var refusal := "" if walk_in else Recruits.refusal(_dispatch.adventurers, _gold, beds, Recruits.hire_gold(visitor), _hall)
	_adventurer.show_visitor(visitor, walk_in, refusal, _dispatch.adventurers.roster.size() < beds)
	_roster.mark("", _shown_visitor if _landscape else Roster.NO_VISITOR)


func _on_level_up_continue() -> void:
	_level_up.hide()
	if _adventurer_from == _board:
		_show_with_picker(_board, true)
	else:
		_open_adventurer(_shown_adventurer, _adventurer_from)


# A tab pressed in code does not signal its group, so the tab is shown here.
func _on_go_send() -> void:
	var quests_tab := $TabBar/Tabs/Quests as Button
	quests_tab.button_pressed = true
	_on_tab_pressed(quests_tab)


func _on_tab_pressed(tab: BaseButton) -> void:
	_hall_view.visible = tab == $TabBar/Tabs/Hall
	_roster.hide()
	_adventurer.hide()
	_level_up.hide()
	_armory.hide()
	_reception.hide()
	_swap_pick.hide()
	_convert_panel.hide()
	_picker.close()
	if tab == _labyrinth_tab:
		_labyrinth.show_labyrinth(_dispatch, _goals.unlocked, _now())
		_show_with_picker(_labyrinth, true)
	else:
		_show_with_picker(_board, tab == $TabBar/Tabs/Quests)
	if tab == $TabBar/Tabs/Roster:
		_show_roster()


# The window's shape picks the layout, wider than tall being landscape: the rail instead of the
# top and bottom bars, and screens side by side. The design size turns with the window, so its
# short side stays the same either way.
func _lay_out() -> void:
	var window := get_window()
	var landscape := window.size.x > window.size.y
	if landscape == _landscape:
		return
	_landscape = landscape
	var roster_tab := _roster.visible or (_adventurer.visible and _adventurer_from == _roster)
	var portrait_size := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	window.content_scale_size = Vector2i(portrait_size.y, portrait_size.x) if landscape else portrait_size
	_top_bar.visible = not landscape
	_rail_gold.visible = landscape
	_tabs.vertical = landscape
	_tab_bar.theme_type_variation = &"Rail" if landscape else &"BottomBar"
	_test_speed.reparent(_tabs if landscape else $TopBar/Row, false)
	_test_speed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if landscape else TextServer.AUTOWRAP_OFF
	_hall_view.set_landscape(landscape)
	_board.set_landscape(landscape)
	_adventurer.set_landscape(landscape)
	_picker.set_landscape(landscape)
	_reception.set_landscape(landscape)
	_labyrinth.set_landscape(landscape)
	if not landscape:
		for part: Control in _portrait_places:
			_place(part, _portrait_places[part][0], _portrait_places[part][1])
	else:
		var full := Vector4(0, 0, 1, 1)
		_place(_tab_bar, Vector4(0, 0, 0, 1), Vector4(0, 0, RAIL_WIDTH_PX, 0))
		_place(_body, full, Vector4(RAIL_WIDTH_PX + SIDE_MARGIN_PX, END_MARGIN_PX, -SIDE_MARGIN_PX, -END_MARGIN_PX))
		_place(_board, Vector4(0, 0, BOARD_SHARE, 1), Vector4(0, 0, -SIDE_MARGIN_PX / 2, 0))
		_place(_labyrinth, Vector4(0, 0, BOARD_SHARE, 1), Vector4(0, 0, -SIDE_MARGIN_PX / 2, 0))
		_place(_adventurer, full, Vector4.ZERO)
		_place(_reception, full, Vector4.ZERO)
		# Where the Adventurer screen keeps its left column.
		_place(_roster, Vector4(0, 0, Adventurer.SIDE_SHARE, 1), Vector4(0, 0, -Adventurer.SIDE_GAP_PX / 2, 0))
		for column: Control in [_level_up, _armory, _swap_pick, _convert_panel]:
			_place(column, Vector4(0.5, 0, 0.5, 1), Vector4(-COLUMN_WIDTH_PX / 2, 0, COLUMN_WIDTH_PX / 2, 0))
		_place(_picker, Vector4(BOARD_SHARE, 0, 1, 1), Vector4(SIDE_MARGIN_PX / 2, 0, 0, 0))
	_show_with_picker(_picker_from, _picker_from.visible or _picker.visible)
	# The Roster tab keeps the adventurer, candidate or walk-in it shows: beside the roster in
	# landscape, on their own screen with Back in portrait.
	if roster_tab and _adventurer.visible and _shown_visitor != Roster.NO_VISITOR:
		_open_visitor(_shown_visitor)
	elif roster_tab and landscape:
		_show_roster()
	elif roster_tab and _adventurer.visible:
		_open_adventurer(_shown_adventurer, _roster)


# Sets `control`'s anchors and offsets, each given as left, top, right, bottom. Anchors pushed
# past their opposite on the way are set again after, so the order of sides does not matter.
static func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.set_anchor_and_offset(SIDE_LEFT, anchors.x, offsets.x, true)
	control.set_anchor_and_offset(SIDE_TOP, anchors.y, offsets.y, true)
	control.set_anchor_and_offset(SIDE_RIGHT, anchors.z, offsets.z, true)
	control.set_anchor_and_offset(SIDE_BOTTOM, anchors.w, offsets.w, true)


# Shows `screen`, the Quests board or the Labyrinth, with the party picker, hiding the other; or
# hides them all when `shown` is false. In landscape the picker sits beside `screen`, prompting for a
# quest or a floor until one is picked; in portrait it takes `screen`'s place while one is picked.
func _show_with_picker(screen: Control, shown: bool) -> void:
	_picker_from = screen
	_picker.set_prompt("Pick a floor" if screen == _labyrinth else "Pick a quest")
	for each: Control in [_board, _labyrinth]:
		each.visible = shown and each == screen and (_landscape or not _picker.has_quest())
	_picker.visible = shown and (_landscape or _picker.has_quest())


func _now() -> int:
	return _clock.now(Time.get_unix_time_from_system())


# Play-testing only: runs game time faster while the app is open. Removing it means deleting this
# and the TestSpeed control; the clock then stays at ×1.
func _on_test_speed_pressed() -> void:
	var next := TEST_SPEEDS[(TEST_SPEEDS.find(_clock.speed) + 1) % TEST_SPEEDS.size()]
	_clock.set_speed(next, Time.get_unix_time_from_system())
	_test_speed.text = "Test speed ×%d" % next
