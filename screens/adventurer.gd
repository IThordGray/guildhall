class_name Adventurer
extends Control

## The player is done looking at this adventurer.
signal back_pressed
## The player chose to level up `adventurer`, a key of Adventurers.roster.
signal level_up_pressed(adventurer: String)
## The player chose to promote `adventurer` to their next rank.
signal promote_pressed(adventurer: String)
## The player chose to put the stash item at `index` on `adventurer`.
signal wear_pressed(adventurer: String, index: int)
## The player chose to put what `adventurer` wears in `slot`, a key of Gear.SLOTS, into the stash.
signal take_off_pressed(adventurer: String, slot: String)
## The player chose to put `adventurer` in training.
signal train_pressed(adventurer: String)
## The player chose to end `adventurer`'s training and bank its XP.
signal stop_training_pressed(adventurer: String)
## The player asked to dismiss `adventurer` from the guild.
signal dismiss_pressed(adventurer: String)
## The player chose to move `adventurer` to `to`: a party's id, Parties.RESERVES or
## Parties.NEW_PARTY. Only a move Parties.move_refusal allows is asked for.
signal party_pressed(adventurer: String, to: String)
## The player swiped to the next adventurer in roster order (`step` 1) or the previous (`step` -1).
signal swiped(step: int)
## A slot's tray opened (`open` true) or closed.
signal tray_toggled(open: bool)
## The player asked to hire the candidate shown.
signal hire_pressed
## The player accepted the walk-in shown into a free bed.
signal accept_pressed
## The player turned the walk-in shown away.
signal turn_away_pressed
## The player asked to swap the walk-in shown for someone in the guild, every bed being taken.
signal swap_pressed

## A stat at this value fills its bar.
const STAT_BAR_FULL: int = 20
## The width a health row keeps for its text, and the XP numbers under it, so their bars line up:
## the design's 64 dp.
const HEALTH_TEXT_WIDTH_PX: float = 177.0
## The small type of a stat chip's name, its total, and what gear adds to it.
const CHIP_NAME_FONT_PX: int = 33
const CHIP_TOTAL_FONT_PX: int = 36
const CHIP_GEAR_FONT_PX: int = 28
## A gear slot's box and the whole scale of the item's icon that fills it, and its name's size under
## it: as large as four to a row allows in portrait, smaller in landscape so eight fit beside the
## stash. The "+" in an empty one that a stash item fits.
const SLOT_BOX_PX: Vector2i = Vector2i(172, 116)
const SLOT_ICON_SCALE: Vector2i = Vector2i(5, 3)
const SLOT_NAME_FONT_PX: Vector2i = Vector2i(28, 24)
const SLOT_PLUS_FONT_PX: int = 50
## How see-through the other slots are while one slot's tray is open.
const SLOT_DIM_ALPHA: float = 0.35
## The whole scale of a stash item's icon in the stash strip, and of an item's icon in a tray row.
const STASH_ICON_SCALE: Vector2i = Vector2i(3, 2)
const TRAY_ICON_SCALE: Vector2i = Vector2i(5, 2)
## How tall a tray row is: the design's 52 dp. The space between its icon, words and button, and the
## size of its item name and of its line of changes: smaller in the narrow landscape column, so the
## name and the changes each keep to one line, and three changes fit whole beside Wear.
const TRAY_ROW_PX: int = 144
const TRAY_GAP_PX: Vector2i = Vector2i(Roster.ROW_GAP_PX, 8)
const TRAY_NAME_FONT_PX: Vector2i = Vector2i(36, Roster.SMALL_FONT_PX)
const CHANGE_FONT_PX: Vector2i = Vector2i(30, 22)
## The space between the parts of a tray row's line of changes and the dots between them: tighter
## in landscape, as above.
const CHANGE_GAP_PX: Vector2i = Vector2i(10, 6)
## The stats' short names, for a tray row's one line of changes.
const SHORT_STATS: Dictionary[String, String] = {
	"strength": "Str", "agility": "Agi", "perception": "Per", "mind": "Mind", "spirit": "Spi",
	"defence": "Def", "endurance": "End", "presence": "Pre", "luck": "Luck",
}
## In landscape, the share of the screen's width the stash or the tray takes on the left (the
## design's 286 of 768 dp), and the space between it and the rest.
const SIDE_SHARE: float = 0.38
const SIDE_GAP_PX: float = 44.0
## The round badge counting the stash items that fit a slot, and how far it sticks out past the
## box's top-right corner: the design's 16 and 5 dp.
const FIT_BADGE_PX: int = 44
const FIT_BADGE_OVERHANG_PX: int = 14
## How many gear slots go to a row: four in portrait, all eight in landscape.
const GEAR_COLUMNS_PORTRAIT: int = 4
const GEAR_COLUMNS_LANDSCAPE: int = 8
## The gaps between the sections, the header's lines, the stat chips' rows and the gear slots: as
## the scene has them in portrait, tighter in landscape so everything fits above Back without
## scrolling.
const SECTION_GAP_PX: Vector2i = Vector2i(22, 16)
const HEADER_LINE_GAP_PX: Vector2i = Vector2i(14, 6)
const CHIP_ROW_GAP_PX: Vector2i = Vector2i(11, 6)
const SLOT_GAP_PX: Vector2i = Vector2i(16, 6)
## How tall Back is: as the scene has it in portrait; in landscape a small button, so a header with
## Level up in it still fits.
const BACK_HEIGHT_PX: Vector2i = Vector2i(144, Roster.SMALL_BUTTON_PX)
## What the tray is open on instead of a gear slot when it lists the parties to move to.
const PARTY_TRAY: String = "party"
## A press-drag-release at least this far sideways, and further sideways than up or down, is a swipe.
const SWIPE_MIN_PX: float = 120.0

## The adventurer shown; "" while a candidate or the walk-in is.
var _adventurer: String = ""
## The guild as last shown, and when, so a tap on the gear shows its choice without waiting on it.
var _dispatch: Dispatch
var _shown_at: int = 0
## The slot whose tray is open, a key of Gear.SLOTS, or PARTY_TRAY; "" while the stash strip shows
## instead.
var _tray_slot: String = ""
## Where in the stash the item picked in the tray is, previewed in the stats; -1 for none.
var _picked: int = -1
## The stats the last Wear changed, whose chips keep a highlight until the next pick, another slot
## or the tray closing.
var _changed: PackedStringArray = PackedStringArray()
## Each stat's chip, its total, and what gear adds to it.
var _chips: Dictionary[String, PanelContainer] = {}
var _values: Dictionary[String, Label] = {}
var _gear_values: Dictionary[String, Label] = {}
var _health: HBoxContainer
## Who is shown (an adventurer's id, or a visitor's "who"), their gear, how many stash items fit
## each slot, the open tray and whether the slots open trays, as shown, so the gear is rebuilt only
## when these change or the layout does; the same for the stash and tray.
var _gear_shown: Array = []
var _stash_shown: Array = []
var _tray_shown: Array = []
## Why the last party row tapped can't move the adventurer shown; "" once anything else happens.
var _party_refusal: String = ""
## Whether the landscape layout shows, which leaves out the notes under the stats.
var _landscape: bool = false
## Whether, in landscape, the roster sits in the left column beside this screen, giving it up only
## to the open tray.
var _beside_roster: bool = false
## Whether a press that started on this screen is held, so its release may be a swipe.
var _press_held: bool = false
## Where the held press started, in viewport pixels.
var _press_at: Vector2 = Vector2.ZERO

@onready var _figure: TextureRect = $Box/Scroll/Content/Card/Header/Row/Figure
@onready var _name: Label = $Box/Scroll/Content/Card/Header/Row/Words/NameLine/Name
@onready var _status: Label = $Box/Scroll/Content/Card/Header/Row/Words/NameLine/Status
@onready var _details: Label = $Box/Scroll/Content/Card/Header/Row/Words/Details
## Progress toward the next promotion, and the tick once the level it needs is reached.
@onready var _progress: HBoxContainer = $Box/Scroll/Content/Card/Header/Row/Words/Progress
@onready var _progress_text: Label = $Box/Scroll/Content/Card/Header/Row/Words/Progress/Text
@onready var _progress_tick: Control = $Box/Scroll/Content/Card/Header/Row/Words/Progress/Tick
@onready var _level_up: Button = $Box/Scroll/Content/Card/Header/Row/Words/LevelUp
@onready var _xp: HBoxContainer = $Box/Scroll/Content/Card/Header/Row/Words/Xp
@onready var _xp_bar: ProgressBar = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Bar
@onready var _xp_text: Label = $Box/Scroll/Content/Card/Header/Row/Words/Xp/Text
@onready var _promote: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Promote
## Why a candidate's Hire can't be pressed.
@onready var _hire_reason: Label = $Box/Scroll/Content/Card/Header/Row/Words/HireReason
@onready var _training_xp: Label = $Box/Scroll/Content/Card/Header/Row/Words/Actions/TrainingXp
@onready var _stop: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Stop
@onready var _train: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Train
@onready var _dismiss: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Dismiss
## A candidate's or the walk-in's actions, in the same row.
@onready var _hire: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Hire
@onready var _turn_away: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/TurnAway
@onready var _accept: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Accept
@onready var _swap: Button = $Box/Scroll/Content/Card/Header/Row/Words/Actions/Swap
## "Party · <name>", or Reserve, and Change, which opens the party tray.
@onready var _party_line: HBoxContainer = $Box/Scroll/Content/Card/Header/Row/Words/PartyLine
@onready var _party_name: Label = $Box/Scroll/Content/Card/Header/Row/Words/PartyLine/Name
@onready var _last_level_up: Label = $Box/Scroll/Content/Card/Stats/Rows/LastLevelUp
@onready var _training_notes: Label = $Box/Scroll/Content/Card/Stats/Rows/TrainingNotes
## The key to the gear badges, shown while any slot has stash items that fit.
@onready var _fit_key: Control = $Box/Scroll/Content/GearColumn/Line/FitKey
@onready var _gear: GridContainer = $Box/Scroll/Content/GearColumn/Gear
## Under the gear in portrait, beside everything in landscape: the stash strip, or the open tray in
## its place.
@onready var _stash: PanelContainer = $Box/Scroll/Content/Stash
@onready var _stash_title: Label = $Box/Scroll/Content/Stash/Rows/Line/Title
@onready var _stash_hint: Label = $Box/Scroll/Content/Stash/Rows/Line/Hint
@onready var _tiles: HFlowContainer = $Box/Scroll/Content/Stash/Rows/Tiles
@onready var _stash_empty: Label = $Box/Scroll/Content/Stash/Rows/Empty
@onready var _tray: PanelContainer = $Box/Scroll/Content/Tray
@onready var _tray_title: Label = $Box/Scroll/Content/Tray/Rows/Line/Title
@onready var _tray_list: VBoxContainer = $Box/Scroll/Content/Tray/Rows/List


func _ready() -> void:
	# One chip per stat, three to a row: its name, then its total and what gear adds.
	var grid := $Box/Scroll/Content/Card/Stats/Rows/Grid as GridContainer
	for stat: String in Adventurers.STATS:
		var name_label := Label.new()
		name_label.text = Adventurers.STATS[stat]
		name_label.theme_type_variation = &"Secondary"
		name_label.add_theme_font_size_override(&"font_size", CHIP_NAME_FONT_PX)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var value := Label.new()
		value.theme_type_variation = &"Numbers"
		value.add_theme_font_size_override(&"font_size", CHIP_TOTAL_FONT_PX)
		var from_gear := Label.new()
		from_gear.theme_type_variation = &"GoldAmount"
		from_gear.add_theme_font_size_override(&"font_size", CHIP_GEAR_FONT_PX)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.add_child(name_label)
		line.add_child(value)
		line.add_child(from_gear)
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_child(line)
		_chips[stat] = chip
		_values[stat] = value
		_gear_values[stat] = from_gear
		grid.add_child(chip)
	# Thin and small, as the XP bar under it.
	_health = health_row()
	_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_health.get_child(0) as Control).custom_minimum_size.y = Roster.HEALTH_BAR_PX
	(_health.get_child(1) as Label).add_theme_font_size_override(&"font_size", Roster.NUMBERS_FONT_PX)
	($Box/Scroll/Content/Card/Header/Row/Words/Hp as HBoxContainer).add_child(_health)
	_xp_text.custom_minimum_size.x = HEALTH_TEXT_WIDTH_PX
	_progress_tick.draw.connect(_draw_tick)
	_level_up.pressed.connect(func() -> void: level_up_pressed.emit(_adventurer))
	_promote.pressed.connect(_on_promote)
	_train.pressed.connect(func() -> void: train_pressed.emit(_adventurer))
	_stop.pressed.connect(func() -> void: stop_training_pressed.emit(_adventurer))
	_dismiss.pressed.connect(func() -> void: dismiss_pressed.emit(_adventurer))
	_hire.pressed.connect(hire_pressed.emit)
	_turn_away.pressed.connect(turn_away_pressed.emit)
	_accept.pressed.connect(accept_pressed.emit)
	_swap.pressed.connect(swap_pressed.emit)
	($Box/Back as Button).pressed.connect(back_pressed.emit)
	($Box/Scroll/Content/Tray/Rows/Line/Done as Button).pressed.connect(_open_tray.bind("", -1))
	($Box/Scroll/Content/Card/Header/Row/Words/PartyLine/Change as Button).pressed.connect(_on_slot_tapped.bind(PARTY_TRAY))
	# Leaving the screen, by Back or anything else, closes the tray.
	visibility_changed.connect(func() -> void:
		if not visible:
			_set_tray("", -1))


# Watched here, not in _gui_input: the scroll container and the buttons take the drags and presses
# first. Nothing is marked handled, so they still get every event. Only mouse events are read: touch
# arrives as the mouse events Godot emulates from it (on by default), the same ones buttons press on,
# so a swipe counts once.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not is_visible_in_tree():
		return
	if click.pressed:
		# Beside the roster, only the adventurer's side pages; a drag on the roster or the tray does not.
		var area: Control = $Box if _beside_roster else self
		_press_held = area.get_global_rect().has_point(click.position)
		_press_at = click.position
		return
	var held := _press_held
	_press_held = false
	if not held or click.canceled:
		return
	# A swipe is far past the tap's slop, so Touch has already kept the button it started on from
	# firing.
	var travel := click.position - _press_at
	# A candidate or the walk-in has no others to page through.
	if absf(travel.x) >= SWIPE_MIN_PX and absf(travel.x) > absf(travel.y) and not _adventurer.is_empty():
		# Swiping left brings the next adventurer in, as turning a page does.
		swiped.emit(1 if travel.x < 0 else -1)


## The header and stats sit over the gear either way. Portrait sets the gear four to a row with the
## stash strip or the tray under it. Landscape puts the stash or the tray in a column on the left and
## fits the rest and Back beside it on one screen: all eight gear slots in one row, tighter cards
## and gaps, Hire's refusal beside the buttons, and no section label lines, notes under the stats
## or hint in the stash's header.
## `beside_roster`, in landscape, leaves the left column to the roster except while the tray is open
## there, and puts the stash on one line under the gear, and no Back.
func set_landscape(landscape: bool, beside_roster: bool = false) -> void:
	_landscape = landscape
	_beside_roster = landscape and beside_roster
	var side := $Side as ScrollContainer
	side.visible = landscape and not (_beside_roster and _tray_slot.is_empty())
	side.set_anchor_and_offset(SIDE_RIGHT, SIDE_SHARE, -SIDE_GAP_PX / 2)
	($Box as Control).set_anchor_and_offset(SIDE_LEFT, SIDE_SHARE if landscape else 0.0, SIDE_GAP_PX / 2 if landscape else 0.0)
	_stash.reparent($Box/Scroll/Content if not landscape or _beside_roster else $Side/Content, false)
	_tray.reparent($Side/Content if landscape else $Box/Scroll/Content, false)
	# Beside the roster the stash's title and its tiles share one line, the tiles taking the room
	# after the title.
	_stash_title.size_flags_horizontal = Control.SIZE_FILL if _beside_roster else Control.SIZE_EXPAND_FILL
	var stash_line := _stash_title.get_parent()
	_tiles.reparent(stash_line if _beside_roster else stash_line.get_parent(), false)
	if not _beside_roster:
		_tiles.get_parent().move_child(_tiles, stash_line.get_index() + 1)
	_tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _beside_roster else Control.SIZE_FILL
	_tiles.alignment = FlowContainer.ALIGNMENT_END if _beside_roster else FlowContainer.ALIGNMENT_BEGIN
	_gear.columns = GEAR_COLUMNS_LANDSCAPE if landscape else GEAR_COLUMNS_PORTRAIT
	_gear.add_theme_constant_override(&"h_separation", _by_layout(SLOT_GAP_PX))
	# Its own width in landscape, from the left, so the last slot's badge has room before the
	# scroll's edge, which would cut it off.
	_gear.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if landscape else Control.SIZE_FILL
	for card: PanelContainer in [$Box/Scroll/Content/Card/Header, $Box/Scroll/Content/Card/Stats, _stash]:
		card.theme_type_variation = &"CardTight" if landscape else &""
	# Beside the roster the stash is a bare line, so a second line of tiles still fits.
	if _beside_roster:
		_stash.theme_type_variation = &"Bare"
	for line: Control in [$Box/Scroll/Content/Card/Stats/Rows/Line, $Box/Scroll/Content/GearColumn/Line]:
		line.visible = not landscape
	for box: Control in [$Box/Scroll/Content, $Box/Scroll/Content/Card, $Box/Scroll/Content/GearColumn]:
		box.add_theme_constant_override(&"separation", _by_layout(SECTION_GAP_PX))
	var words := $Box/Scroll/Content/Card/Header/Row/Words as VBoxContainer
	words.add_theme_constant_override(&"separation", _by_layout(HEADER_LINE_GAP_PX))
	($Box/Scroll/Content/Card/Stats/Rows/Grid as GridContainer).add_theme_constant_override(&"v_separation", _by_layout(CHIP_ROW_GAP_PX))
	var back := $Box/Back as Button
	back.visible = not _beside_roster
	back.custom_minimum_size.y = _by_layout(BACK_HEIGHT_PX)
	if landscape:
		back.add_theme_font_size_override(&"font_size", Roster.SMALL_FONT_PX)
	else:
		back.remove_theme_font_size_override(&"font_size")
	# The wide landscape header has room for the refusal on the buttons' row, on one line.
	var actions := $Box/Scroll/Content/Card/Header/Row/Words/Actions as Control
	_hire_reason.reparent(actions if landscape else words, false)
	if not landscape:
		words.move_child(_hire_reason, actions.get_index() + 1)
	_hire_reason.autowrap_mode = TextServer.AUTOWRAP_OFF if landscape else TextServer.AUTOWRAP_WORD_SMART
	# The gear, the stash and the tray are sized by the layout, so each is built again.
	_gear_shown = []
	_stash_shown = []
	_tray_shown = []
	if _dispatch != null and not _adventurer.is_empty():
		_show_gear_choice()


# The portrait value of `values` (x) or the landscape one (y), as the layout shows.
func _by_layout(values: Vector2i) -> int:
	return values.y if _landscape else values.x


## Shows `adventurer` as `dispatch` has them at `now`: progress toward their next promotion while
## there is one; Promote only when promoting them would succeed; Train only when one of
## `training_places` would take them now, and a stint's XP up to `stint_xp` (Hall.stint_xp); Dismiss
## while they are home and not the last, disabled with the reason while something else keeps them.
## Another adventurer closes the tray; the same one keeps it as it is.
func show_adventurer(adventurer: String, dispatch: Dispatch, training_places: int, now: int, stint_xp: int = Dispatch.TRAINING_MAX_XP) -> void:
	if adventurer != _adventurer:
		_set_tray("", -1)
	_adventurer = adventurer
	_dispatch = dispatch
	_shown_at = now
	var adventurers := dispatch.adventurers
	var info: Dictionary = adventurers.roster[adventurer]
	_figure.texture = QuestBoard.figure(Faces.seed_of(adventurer, info), adventurers.gear.worn[adventurer])
	_name.text = info["name"]
	_status.text = dispatch.status(adventurer, now)
	_status.theme_type_variation = Roster.status_look(dispatch, adventurer, now)
	_details.text = Roster.details_line(adventurers, adventurer)
	var xp: int = adventurers.xp[adventurer]
	var needed := adventurers.xp_needed(adventurer)
	_level_up.visible = adventurers.level_up_ready(adventurer)
	_level_up.text = "Level up · XP %d / %d" % [xp, needed]
	_xp.visible = not _level_up.visible
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_xp_text.text = "%d / %d" % [xp, needed]
	_promote.visible = adventurers.can_promote(adventurer, not dispatch.quest_of(adventurer).is_empty())
	var next := adventurers.next_rank(adventurer)
	_promote.text = "Promote to %s" % next
	# Shown beside Promote too: Promote is the action, this line only says how close they are.
	_progress.visible = not next.is_empty()
	if _progress.visible:
		var needs: Dictionary = Adventurers.PROMOTIONS[next]
		var quests: int = needs["quests"]
		var done := mini(int(adventurers.successes[adventurer].get(next, 0)), quests)
		_progress_text.text = "To rank %s · %d / %d rank-%s quests · level %d" % [next, done, quests, next, needs["level"]]
		_progress_tick.visible = adventurers.levels[adventurer] >= int(needs["level"])
	_hire_reason.visible = false
	var training := dispatch.training.has(adventurer)
	_training_xp.visible = training
	_training_xp.text = "Training · +%d XP" % dispatch.training_xp(adventurer, now, stint_xp)
	_stop.visible = training
	# Train shows only when training would start now.
	_train.visible = dispatch.training_refusal(adventurer, training_places, now).is_empty()
	var keeps_them := dispatch.dismiss_refusal(adventurer)
	_dismiss.visible = dispatch.quest_of(adventurer).is_empty() and adventurers.roster.size() > 1
	_dismiss.disabled = not keeps_them.is_empty()
	_dismiss.text = "Dismiss" if keeps_them.is_empty() else keeps_them
	var hint := dispatch.training_hint(adventurer, now)
	_training_notes.text = "" if hint.is_empty() else "Grows fastest in " + hint
	var history: Array = adventurers.history[adventurer]
	_last_level_up.text = "" if history.is_empty() else _history_line(history.back())
	for button: Button in [_hire, _turn_away, _accept, _swap]:
		button.visible = false
	var party := adventurers.parties.party(adventurers.parties.party_of(adventurer))
	_party_line.visible = true
	_party_name.text = "Reserve" if party.is_empty() else party["name"]
	_show_gear_choice()


## Shows `visitor`, a candidate or the walk-in as Recruits and WalkIns keep them, as an adventurer
## is shown but read-only: tagged "Walk-in" when `walk_in`, else "Candidate", at full health, every
## stat and what they wear, with no XP, notes, stash or tray. A candidate has Hire, disabled with
## `refusal` under it when there is one; the walk-in has Turn away, and Accept while `free_bed`, else
## Swap.
func show_visitor(visitor: Dictionary, walk_in: bool, refusal: String, free_bed: bool) -> void:
	_set_tray("", -1)
	_adventurer = ""
	var who: Dictionary = visitor["who"]
	_figure.texture = QuestBoard.figure(who["face_seed"], visitor["worn"])
	_name.text = who["name"]
	_status.text = "Walk-in" if walk_in else "Candidate"
	_status.theme_type_variation = &"Secondary"
	_details.text = "%s · rank %s · level %d" % [Recruits.title(visitor), who["rank"], visitor.get("level", 1)]
	var most := Recruits.max_health(visitor)
	var bar := _health.get_child(0) as ProgressBar
	bar.max_value = most
	bar.value = most
	bar.theme_type_variation = &"HealthBar"
	var health_text := _health.get_child(1) as Label
	health_text.text = "%d / %d" % [most, most]
	health_text.theme_type_variation = &"Meta"
	for part: Control in [_progress, _level_up, _xp, _promote, _training_xp, _stop, _train, _dismiss, _party_line, _last_level_up, _training_notes, _stash, _tray, $Side]:
		part.visible = false
	_hire.visible = not walk_in
	_hire.text = "Hire · %dg" % Recruits.hire_gold(visitor)
	_hire.disabled = not refusal.is_empty()
	_hire_reason.text = refusal
	_hire_reason.visible = not walk_in and not refusal.is_empty()
	_turn_away.visible = walk_in
	_accept.visible = walk_in and free_bed
	_swap.visible = walk_in and not free_bed
	var totals := Recruits.totals(visitor)
	var title_stats := Adventurers.title_stats_of(totals)
	for stat: String in Adventurers.STATS:
		_show_chip(stat, totals[stat], totals[stat] - visitor["stats"][stat], 0, stat in title_stats, false)
	var no_fits: Array[int] = []
	no_fits.resize(Gear.SLOTS.size())
	no_fits.fill(0)
	var gear_shown := [who, visitor["worn"].duplicate(), no_fits, "", false]
	if gear_shown != _gear_shown:
		_gear_shown = gear_shown
		_show_gear(gear_shown[1], no_fits, false)


# What the gear choice changes on screen: the health and the stat chips, previewing the item picked
# in the tray ("8→9", green for a gain, red for a loss) and keeping the last Wear's changes lit; the
# gear, the open slot lit and the others dimmed; and under it the stash strip or the open tray.
func _show_gear_choice() -> void:
	var adventurers := _dispatch.adventurers
	var gear := adventurers.gear
	if not Gear.SLOTS.has(_tray_slot) or _picked not in gear.fitting(_tray_slot):
		_picked = -1
	var change: Dictionary = {"stats": {}, "health": 0} if _picked < 0 else adventurers.wear_change(_adventurer, gear.stash[_picked])
	show_health(_health, _adventurer, _dispatch, _shown_at)
	var health_text := _health.get_child(1) as Label
	var most := adventurers.max_health(_adventurer)
	var health_change: int = change["health"]
	if health_change != 0:
		health_text.text = "%d→%d" % [most, most + health_change]
	health_text.theme_type_variation = _change_look(health_change, &"Meta")
	var title_stats := adventurers.title_stats(_adventurer)
	for stat: String in Adventurers.STATS:
		var points: int = change["stats"].get(stat, 0)
		_show_chip(stat, adventurers.stat_total(_adventurer, stat), gear.bonus(_adventurer, stat), points, stat in title_stats, points > 0 or stat in _changed)
	_show_notes()
	var fits: Array[int] = []
	for slot: String in Gear.SLOTS:
		fits.append(gear.fitting(slot).size())
	var gear_shown := [_adventurer, gear.worn[_adventurer].duplicate(), fits, _tray_slot, true]
	if gear_shown != _gear_shown:
		_gear_shown = gear_shown
		_show_gear(gear_shown[1], fits, true)
	# Beside the roster the stash stays under the gear, dimmed, while the tray has the left column.
	_stash.visible = _tray_slot.is_empty() or _beside_roster
	_stash.modulate.a = 1.0 if _tray_slot.is_empty() else SLOT_DIM_ALPHA
	_tray.visible = not _tray_slot.is_empty()
	if _beside_roster:
		($Side as Control).visible = _tray.visible
	if _stash.visible:
		var stash_shown := [gear.stash.duplicate(), gear.stash_cap]
		if stash_shown != _stash_shown:
			_stash_shown = stash_shown
			_show_stash(gear)
	if _tray_slot == PARTY_TRAY:
		var parties := adventurers.parties
		# A party's members are shared with Parties, so the copy is what was shown.
		var party_shown: Array = [_adventurer, PARTY_TRAY, parties.party_of(_adventurer), parties.reserves(adventurers.roster), _party_refusal]
		for party: Dictionary in parties.parties:
			party_shown.append([party["name"], party["members"].duplicate(), parties.rank(party["id"], adventurers.roster)])
		if party_shown != _tray_shown:
			_tray_shown = party_shown
			_show_party_tray()
	elif _tray.visible:
		var worn: String = gear.worn[_adventurer].get(_tray_slot, "")
		var tray_shown := [_adventurer, _tray_slot, worn, gear.stash.duplicate(), _picked, _dispatch.wear_refusal(_adventurer), _dispatch.take_off_refusal(_adventurer, _tray_slot)]
		if tray_shown != _tray_shown:
			_tray_shown = tray_shown
			_show_tray(worn)


# A tick in the theme's green, drawn to fill the progress line's tick, as Reception's ticks are.
func _draw_tick() -> void:
	var unit := _progress_tick.size / 24.0
	var points := PackedVector2Array([Vector2(5.0, 12.5) * unit, Vector2(9.5, 17.0) * unit, Vector2(19.0, 7.5) * unit])
	_progress_tick.draw_polyline(points, get_theme_color(&"font_color", &"Ok"), 2.6 * unit.x, true)


# `stat`'s chip: its `total`, or "8→9" while a change of `points` is previewed, green for a gain and
# red for a loss; what gear adds to it, `from_gear`, while nothing is previewed; bordered as behind
# the title when `in_title`, and lit when `lit`.
func _show_chip(stat: String, total: int, from_gear: int, points: int, in_title: bool, lit: bool) -> void:
	_values[stat].text = str(total) if points == 0 else "%d→%d" % [total, total + points]
	_values[stat].theme_type_variation = _change_look(points, &"Numbers")
	_gear_values[stat].text = "+%d" % from_gear
	_gear_values[stat].visible = from_gear > 0 and points == 0
	if in_title:
		_chips[stat].theme_type_variation = &"StatChipTitleChanged" if lit else &"StatChipTitle"
	else:
		_chips[stat].theme_type_variation = &"StatChipChanged" if lit else &"StatChip"


# The look of a number that a change of `points` would move: Gain or Loss, or `unchanged`.
static func _change_look(points: int, unchanged: StringName) -> StringName:
	return unchanged if points == 0 else (&"Gain" if points > 0 else &"Loss")


# Opens the tray of `slot` with the stash item at `picked` picked (-1 for none), or closes it for
# "", and shows the choice.
func _open_tray(slot: String, picked: int) -> void:
	var opens := not slot.is_empty() and slot != _tray_slot
	_set_tray(slot, picked)
	_show_gear_choice()
	if opens and not _landscape:
		_scroll_to_tray()


# Scrolls the portrait page as little as brings the whole tray into view, or as much of it as fits,
# its top first. Waits a frame for the tray's rows to be laid out, then leaves a page the finger
# has started dragging alone.
func _scroll_to_tray() -> void:
	await get_tree().process_frame
	if _press_held or _tray_slot.is_empty() or _landscape:
		return
	var scroll := $Box/Scroll as ScrollContainer
	var top := _tray.position.y
	var at := maxf(scroll.scroll_vertical, top + _tray.size.y - scroll.size.y)
	scroll.scroll_vertical = roundi(minf(at, top))


# The tray open on `slot` ("" for closed) with the stash item at `picked` picked; a fresh choice
# lights no Wear's changes.
func _set_tray(slot: String, picked: int) -> void:
	var toggled := slot.is_empty() != _tray_slot.is_empty()
	_tray_slot = slot
	_picked = picked
	_party_refusal = ""
	_changed = PackedStringArray()
	if toggled:
		tray_toggled.emit(not slot.is_empty())


## Whether a slot's tray is open.
func tray_open() -> bool:
	return not _tray_slot.is_empty()


# A tap on `slot` opens its tray, or closes it when it is the one open.
func _on_slot_tapped(slot: String) -> void:
	_open_tray("" if slot == _tray_slot else slot, -1)


# Wears the item picked, lighting the stats it changes; the tray stays open with nothing picked.
func _wear_picked() -> void:
	var change := _dispatch.adventurers.wear_change(_adventurer, _dispatch.adventurers.gear.stash[_picked])
	var index := _picked
	_picked = -1
	_changed = PackedStringArray(change["stats"].keys())
	wear_pressed.emit(_adventurer, index)


# Asks to promote the adventurer shown, lighting the stats a promotion raises (Adventurers.promote),
# as Wear lights what it changes.
func _on_promote() -> void:
	_changed = _dispatch.adventurers.promotion_stats(_adventurer)
	promote_pressed.emit(_adventurer)


# The notes under the stats, the latest level-up and the training hint, each while it has words;
# none in landscape or while the tray is open.
func _show_notes() -> void:
	for note: Label in [_last_level_up, _training_notes]:
		note.visible = not _landscape and _tray_slot.is_empty() and not note.text.is_empty()


## An item's icon at a whole `scale` of its 28 × 28 pixels, so they stay crisp.
static func item_icon(item: String, scale: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/items/%s.png" % item)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(28, 28) * scale
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## A label with `item`'s name in its quality's colour.
static func item_name(item: String) -> Label:
	var label := Label.new()
	label.text = Gear.ITEMS[item]["name"]
	label.theme_type_variation = StringName("Item" + Gear.ITEMS[item]["quality"])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## What `item` adds, "Strength +3 · Defence +4", in gold; "none" when nothing.
static func bonus_label(item: String) -> Label:
	var bonus: Dictionary = Gear.ITEMS[item]["bonus"]
	var parts := PackedStringArray()
	for stat: String in Adventurers.STATS:
		if bonus.has(stat):
			parts.append("%s +%d" % [Adventurers.STATS[stat], bonus[stat]])
	var label := Label.new()
	label.text = " · ".join(parts) if not parts.is_empty() else "none"
	label.theme_type_variation = &"GoldText" if not parts.is_empty() else &"Caption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


# The eight slots, in Gear.SLOTS order: each item's icon over the slot's name, an empty slot dashed.
# A slot that `fits` (a count per slot, in the same order) says stash items fit is bordered gold and
# counts them in a badge on its corner, an empty one with a "+" inside. While a tray is open its slot
# is bordered gold and the others dimmed, without badges. While `tappable`, a tap anywhere on a slot,
# box or name, opens its tray or closes it.
func _show_gear(worn: Dictionary, fits: Array[int], tappable: bool) -> void:
	for cell: Node in _gear.get_children():
		cell.queue_free()
	_fit_key.visible = _tray_slot.is_empty() and fits.any(func(count: int) -> bool: return count > 0)
	var box_px := _by_layout(SLOT_BOX_PX)
	var slots := Gear.SLOTS.keys()
	for i: int in slots.size():
		var slot: String = slots[i]
		var item: String = worn.get(slot, "")
		var fit := fits[i]
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(box_px, box_px)
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var slot_name := Label.new()
		slot_name.text = Gear.SLOTS[slot].to_upper()
		slot_name.theme_type_variation = &"Caption"
		slot_name.add_theme_font_size_override(&"font_size", _by_layout(SLOT_NAME_FONT_PX))
		slot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# The box sets the cell's width, so eight fit in a landscape row.
		slot_name.clip_text = true
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(box)
		cell.add_child(slot_name)
		if item.is_empty():
			box.theme_type_variation = &"ItemBoxEmptyFit" if fit > 0 else &"ItemBoxEmpty"
			if fit > 0:
				var plus := Label.new()
				plus.text = "+"
				plus.theme_type_variation = &"GoldText"
				plus.add_theme_font_size_override(&"font_size", SLOT_PLUS_FONT_PX)
				plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				box.add_child(plus)
		else:
			box.theme_type_variation = &"ItemBoxFit" if fit > 0 else &"ItemBox"
			box.add_child(item_icon(item, _by_layout(SLOT_ICON_SCALE)))
		if slot == _tray_slot:
			box.theme_type_variation = &"ItemBoxOn"
		elif item.is_empty():
			box.draw.connect(_draw_dashed_box.bind(box))
		# A MarginContainer stacks its children, so the button covers the whole cell and the cell
		# sets the size.
		var stack := MarginContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(cell)
		if tappable:
			var open := Button.new()
			open.flat = true
			open.pressed.connect(_on_slot_tapped.bind(slot))
			if fit > 0 and _tray_slot.is_empty():
				open.add_child(_fit_badge(fit, box_px))
			stack.add_child(open)
		if not _tray_slot.is_empty() and slot != _tray_slot:
			stack.modulate.a = SLOT_DIM_ALPHA
		_gear.add_child(stack)


# The gold badge counting `fit` stash items, on the top-right corner of a slot's box `box_px`
# square. It hangs from the slot's button, which no container lays out, from the top centre, where
# the box is centred.
static func _fit_badge(fit: int, box_px: int) -> Label:
	var badge := Label.new()
	badge.text = str(fit)
	badge.theme_type_variation = &"FitBadge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.5
	badge.anchor_right = 0.5
	badge.offset_left = box_px / 2.0 + FIT_BADGE_OVERHANG_PX - FIT_BADGE_PX
	badge.offset_right = box_px / 2.0 + FIT_BADGE_OVERHANG_PX
	badge.offset_top = -FIT_BADGE_OVERHANG_PX
	badge.offset_bottom = FIT_BADGE_PX - FIT_BADGE_OVERHANG_PX
	return badge


# "STASH · N / cap" over every stash item's icon as a tile, a tap on which opens its slot's tray
# with it picked; one muted line instead when the stash is empty.
func _show_stash(gear: Gear) -> void:
	for tile: Node in _tiles.get_children():
		tile.queue_free()
	_stash_title.text = "STASH · %d / %d" % [gear.stash.size(), gear.stash_cap]
	_stash_hint.visible = not _landscape and not gear.stash.is_empty()
	_tiles.visible = not gear.stash.is_empty()
	_stash_empty.visible = gear.stash.is_empty()
	for index: int in gear.stash.size():
		var item := gear.stash[index]
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"ItemBox"
		tile.add_child(item_icon(item, _by_layout(STASH_ICON_SCALE)))
		_tiles.add_child(_tappable(tile, _open_tray.bind(Gear.ITEMS[item]["slot"], index)))


# "<SLOT> · FITS FROM THE STASH" over what `worn` there, with Take off, then each stash item that
# fits, with what it changes against `worn`. A tap on an item picks it; the picked one is bordered
# gold, and a tap anywhere on it wears it. A button that can't be pressed says why instead.
func _show_tray(worn: String) -> void:
	for row: Node in _tray_list.get_children():
		row.queue_free()
	var gear := _dispatch.adventurers.gear
	# The narrow landscape column has room beside Done for a short title only.
	var whose: String = _dispatch.adventurers.roster[_adventurer]["name"].to_upper() if _landscape else "FITS FROM THE STASH"
	_tray_title.text = "%s · %s" % [Gear.SLOTS[_tray_slot].to_upper(), whose]
	if not worn.is_empty():
		var wearing := Label.new()
		wearing.text = "Wearing now"
		wearing.theme_type_variation = &"Caption"
		var take_off := _tray_button("Take off", &"OutlineButton", _dispatch.take_off_refusal(_adventurer, _tray_slot))
		# Taking it off loses what it adds, so those stats stay lit, as after Wear.
		take_off.pressed.connect(func() -> void:
			_changed = PackedStringArray(Gear.ITEMS[worn]["bonus"].keys())
			take_off_pressed.emit(_adventurer, _tray_slot))
		_tray_list.add_child(Touch.whole_card(_tray_row(worn, wearing, take_off, &"TrayRowWorn"), take_off))
	var fitting := gear.fitting(_tray_slot)
	if fitting.is_empty():
		var nothing := Label.new()
		nothing.text = "Nothing in the stash fits " + Gear.SLOTS[_tray_slot].to_lower()
		nothing.theme_type_variation = &"Caption"
		nothing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tray_list.add_child(nothing)
	for index: int in fitting:
		var item := gear.stash[index]
		var changes := _change_line(_dispatch.adventurers.wear_change(_adventurer, item))
		if index == _picked:
			var wear := _tray_button("Wear", &"GoldButton", _dispatch.wear_refusal(_adventurer))
			wear.pressed.connect(_wear_picked)
			_tray_list.add_child(Touch.whole_card(_tray_row(item, changes, wear, &"TrayRowPicked"), wear))
		else:
			_tray_list.add_child(_tappable(_tray_row(item, changes, null, &"TrayRow"), _open_tray.bind(_tray_slot, index)))


# "PARTY · <NAME>" over why the last row tapped can't move them, if it can't; then a row per party,
# its name over its members' faces, with its rank; then Reserve and + New party. The one they are in
# is bordered gold; a tap anywhere on another asks to move them there, the tray staying open.
func _show_party_tray() -> void:
	for row: Node in _tray_list.get_children():
		row.queue_free()
	var adventurers := _dispatch.adventurers
	var parties := adventurers.parties
	_tray_title.text = "PARTY · " + adventurers.roster[_adventurer]["name"].to_upper()
	if not _party_refusal.is_empty():
		var refusal := Label.new()
		refusal.text = _party_refusal
		refusal.theme_type_variation = &"Alert"
		refusal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tray_list.add_child(refusal)
	var current := parties.party_of(_adventurer)
	for party: Dictionary in parties.parties:
		var rank := QuestBoard.chip(parties.rank(party["id"], adventurers.roster), &"Pill")
		rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_add_party_row(party["id"], current, party["name"], _faces(party["members"]), rank)
	var reserves := parties.reserves(adventurers.roster)
	_add_party_row(Parties.RESERVES, current, "Reserve", _faces(reserves) if not reserves.is_empty() else _caption("Nobody"), null)
	_add_party_row(Parties.NEW_PARTY, current, "+ New party", _caption("On their own"), null)


# A party tray row for `to` (a party's id, Parties.RESERVES or Parties.NEW_PARTY) titled `title`
# over `under`, with `end`, if any, at its end: bordered gold when it is `current`, else tappable.
func _add_party_row(to: String, current: String, title: String, under: Control, end: Control) -> void:
	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"RowTitle"
	# An empty picture, so the row's gap insets the words as an item's icon would.
	var row := _tray_row_of(Control.new(), title_label, under, end, &"TrayRowPicked" if to == current else &"TrayRow")
	_tray_list.add_child(row if to == current else _tappable(row, _on_party_row.bind(to)))


# A tap on a party row: the move asked for, or why it can't be, shown in the tray.
func _on_party_row(to: String) -> void:
	_party_refusal = _dispatch.adventurers.parties.move_refusal(_adventurer, to, _dispatch)
	_show_gear_choice()
	if _party_refusal.is_empty():
		party_pressed.emit(_adventurer, to)


# `members`' faces in what they wear, overlapping, as a quest's party shows them.
func _faces(members: PackedStringArray) -> HBoxContainer:
	var stack := HBoxContainer.new()
	stack.theme_type_variation = &"TokenStack"
	for member: String in members:
		var who: Dictionary = _dispatch.adventurers.roster[member]
		stack.add_child(QuestBoard.face_token(Faces.seed_of(member, who), _dispatch.adventurers.gear.worn[member]))
	return stack


static func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Caption"
	return label


# A tray row in `look`, two lines beside `item`'s icon: its name in its quality's colour, cut short
# with "…" if it must, over `under`; and `button`, if any, at the end.
func _tray_row(item: String, under: Control, button: Button, look: StringName) -> PanelContainer:
	return _tray_row_of(item_icon(item, _by_layout(TRAY_ICON_SCALE)), item_name(item), under, button, look)


# A tray row in `look`: `picture`, if any, beside `title`, cut short with "…" if it must, over
# `under`; and `end`, if any, at the end.
func _tray_row_of(picture: Control, title: Label, under: Control, end: Control, look: StringName) -> PanelContainer:
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override(&"font_size", _by_layout(TRAY_NAME_FONT_PX))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.add_child(title)
	words.add_child(under)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", _by_layout(TRAY_GAP_PX))
	if picture != null:
		line.add_child(picture)
	line.add_child(words)
	if end != null:
		line.add_child(end)
	var row := PanelContainer.new()
	row.theme_type_variation = look
	row.custom_minimum_size.y = TRAY_ROW_PX
	row.add_child(line)
	return row


# A small button in `look` reading `text`, or disabled and reading `refusal` when there is one.
static func _tray_button(text: String, look: StringName, refusal: String) -> Button:
	var button := Button.new()
	button.text = text if refusal.is_empty() else refusal
	button.disabled = not refusal.is_empty()
	button.theme_type_variation = look
	button.custom_minimum_size.y = Roster.SMALL_BUTTON_PX
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override(&"font_size", Roster.SMALL_FONT_PX)
	return button


# What a Adventurers.wear_change `change` moves, on one line: "Def +1 · Str −1 · HP +2", each gain
# green and each loss red, health last; "no change" when nothing moves. A line longer than its room
# is cut off at its end, never wrapped.
func _change_line(change: Dictionary) -> Control:
	var parts: Array[Label] = []
	var stats: Dictionary = change["stats"]
	for stat: String in stats:
		parts.append(_change_part(SHORT_STATS[stat], stats[stat]))
	if change["health"] != 0:
		parts.append(_change_part("HP", change["health"]))
	if parts.is_empty():
		var same := Label.new()
		same.text = "no change"
		same.theme_type_variation = &"Caption"
		parts.append(same)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", _by_layout(CHANGE_GAP_PX))
	for i: int in parts.size():
		if i > 0:
			var dot := Label.new()
			dot.text = "·"
			dot.theme_type_variation = &"Caption"
			line.add_child(dot)
		parts[i].add_theme_font_size_override(&"font_size", _by_layout(CHANGE_FONT_PX))
		line.add_child(parts[i])
	# A plain Control doesn't size its child, so the line keeps its own width and the room clips it;
	# the room only takes the line's height.
	var room := Control.new()
	room.clip_contents = true
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(line)
	line.minimum_size_changed.connect(func() -> void: room.custom_minimum_size.y = line.get_combined_minimum_size().y)
	return room


# "Def +1" in Gain, or "Def −1" in Loss.
static func _change_part(stat_name: String, points: int) -> Label:
	var part := Label.new()
	part.text = "%s %s%d" % [stat_name, "+" if points > 0 else "−", absi(points)]
	part.theme_type_variation = _change_look(points, &"Numbers")
	return part


# `card` under a see-through button over the whole of it, a tap on which calls `on_tap`.
static func _tappable(card: Control, on_tap: Callable) -> MarginContainer:
	var tap := Button.new()
	tap.flat = true
	tap.pressed.connect(on_tap)
	var stack := MarginContainer.new()
	stack.add_child(card)
	stack.add_child(tap)
	return stack


# A StyleBox can't draw a dashed border, so an empty slot's box is drawn here.
static func _draw_dashed_box(box: PanelContainer) -> void:
	var color := box.get_theme_color(&"border_color")
	var width := float(box.get_theme_constant(&"border_width"))
	var inset := Rect2(Vector2.ONE * width / 2, box.size - Vector2.ONE * width)
	var corners: Array[Vector2] = [inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)]
	for i: int in corners.size():
		box.draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, width, 14.0)


## A row for one stat: its name, a bar and a value, the name in `look`.
static func stat_row(stat_name: String, look: StringName) -> HBoxContainer:
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.theme_type_variation = look
	name_label.custom_minimum_size = Vector2(250, 0)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"OwnBar"
	bar.show_percentage = false
	bar.max_value = STAT_BAR_FULL
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Label.new()
	value.theme_type_variation = &"Numbers"
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.add_child(name_label)
	row.add_child(bar)
	row.add_child(value)
	return row


## A row for health: a bar, then current / maximum and how long until full.
static func health_row() -> HBoxContainer:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A fixed width, so bars line up whether or not the time until full is shown.
	var text := Label.new()
	text.theme_type_variation = &"Meta"
	text.custom_minimum_size = Vector2(HEALTH_TEXT_WIDTH_PX, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	row.add_child(bar)
	row.add_child(text)
	return row


## Fills a `health_row` with `adventurer`'s health at `now`, the bar red under a quarter.
static func show_health(row: HBoxContainer, adventurer: String, dispatch: Dispatch, now: int) -> void:
	var points := dispatch.health(adventurer, now)
	var most := dispatch.adventurers.max_health(adventurer)
	var bar := row.get_child(0) as ProgressBar
	bar.max_value = most
	bar.value = points
	bar.theme_type_variation = &"InjuryBar" if Dispatch.under_a_quarter(points, most) else &"HealthBar"
	var to_full := dispatch.seconds_to_full(adventurer, now)
	var text := row.get_child(1) as Label
	text.text = "%d / %d" % [points, most] if to_full == 0 else "%d / %d · full in %s" % [points, most, Duration.label(to_full)]


## XP toward the next level, in words for the player.
static func xp_line(xp: int, needed: int, next_level: int) -> String:
	return "XP %d / %d to level %d" % [xp, needed, next_level]


# "Level 3 · Strength +1 · Defence +2", or "Promoted to E · Strength +1 · Agility +1", naming only
# the stats that rose.
func _history_line(entry: Dictionary) -> String:
	var parts := PackedStringArray(["Promoted to %s" % entry["rank"] if entry.has("rank") else "Level %d" % entry["level"]])
	for stat: String in Adventurers.STATS:
		var gain: int = entry["gains"].get(stat, 0)
		if gain > 0:
			parts.append("%s +%d" % [Adventurers.STATS[stat], gain])
	if parts.size() == 1:
		parts.append("no change")
	return " · ".join(parts)
