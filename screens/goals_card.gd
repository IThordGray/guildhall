class_name GoalsCard
extends VBoxContainer

## The goals Odile has open for the guild, on the Hall: each with its progress, its reward or what it
## unlocks, and her line; a done one with Claim. Hidden while no goal is open or done.

## The player asked to claim the done goal `goal`, from its Claim button centred at `from` on screen.
signal claim_pressed(goal: String, from: Vector2)

## What the player sees a goal's unlock called, by Goals' "unlocks".
const UNLOCK_NAMES: Dictionary[String, String] = {Goals.AUTO: "Auto", "sealed_gate": "The sealed gate", Labyrinth.UNLOCK: "Labyrinth", "cooks_debt": "The cook's debt", "kitchen": "Kitchen", "lost_survey": "The lost survey"}
const BAR_SIZE_PX: Vector2 = Vector2(332, 12)
## How far Odile's lines lean, as a share of their height.
const ITALIC_SLANT: float = 0.2
## How strongly the Story tag's border shows its gold.
const TAG_BORDER_ALPHA: float = 0.55

## The goals as shown, each as its id, state and [have, need], so the rows are rebuilt only when
## one of them changes.
var _shown: Array = []
## The Story tag's gold outline, and Odile's slanted font, made once from the theme.
var _tag_style: StyleBoxFlat
var _italic: FontVariation

@onready var _rows: VBoxContainer = $List/Rows


func _ready() -> void:
	# The Pill's outline, which it takes from Chip: a lookup by type doesn't follow a variation's base.
	_tag_style = (get_theme_stylebox(&"normal", &"Chip") as StyleBoxFlat).duplicate()
	_tag_style.border_color = Color(get_theme_color(&"font_color", &"GoldText"), TAG_BORDER_ALPHA)
	_italic = FontVariation.new()
	_italic.base_font = get_theme_font(&"font", &"Secondary")
	# Applied to the outlines with y up, so this leans the tops of the letters right.
	_italic.variation_transform = Transform2D(Vector2(1.0, ITALIC_SLANT), Vector2(0.0, 1.0), Vector2.ZERO)


## Shows the goals `goals` has open or done at `now` (Goals.shown), for the guild of `dispatch` and
## `hall` that has finished the story quests in `story_done`.
func show_goals(goals: Goals, dispatch: Dispatch, hall: Hall, story_done: PackedStringArray, now: int) -> void:
	var shown := []
	for id: String in goals.shown(dispatch, hall, story_done, now):
		shown.append([id, goals.state(id, dispatch, hall, story_done, now), goals.progress(id, dispatch, hall, story_done, now)])
	if shown == _shown:
		return
	_shown = shown
	visible = not shown.is_empty()
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for goal: Array in shown:
		_rows.add_child(_row(goal[0], goal[1], goal[2]))


# Its name, after a Story tag for a story goal, and on the right its reward, or what it unlocks;
# then its progress, with a bar when it counts past 1, or once done, Claim with the reward in place
# of the reward on the right; then Odile's line, cut to one line.
func _row(id: String, state: Goals.State, have_need: Vector2i) -> PanelContainer:
	var goal: Dictionary = Goals.GOALS[id]
	var done := state == Goals.State.DONE
	var reward := "%dg" % goal["gold"]
	if goal.get("reputation", 0) > 0:
		reward += " · +%d rep" % goal["reputation"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	if goal["kind"] == Goals.STORY:
		var tag := QuestBoard.chip("Story", &"Pill")
		tag.add_theme_stylebox_override(&"normal", _tag_style)
		tag.add_theme_color_override(&"font_color", get_theme_color(&"font_color", &"GoldText"))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tag)
	var title := _label(goal["name"], &"RowTitle")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if not goal["unlocks"].is_empty():
		var unlocks := QuestBoard.chip("Unlocks " + UNLOCK_NAMES[goal["unlocks"]], &"Pill")
		unlocks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(unlocks)
	elif not done:
		top.add_child(_label(reward, &"GoldText"))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 10)
	lines.add_child(top)
	if done:
		var claim := Button.new()
		claim.text = "Claim +" + reward
		claim.theme_type_variation = &"GoldButton"
		claim.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		claim.pressed.connect(func() -> void: claim_pressed.emit(id, claim.get_global_rect().get_center()))
		lines.add_child(claim)
	else:
		var progress := HBoxContainer.new()
		progress.add_theme_constant_override("separation", 22)
		progress.add_child(_label("%d / %d" % [have_need.x, have_need.y], &"Meta"))
		if have_need.y > 1:
			var bar := ProgressBar.new()
			bar.theme_type_variation = &"GoldBar"
			bar.show_percentage = false
			bar.custom_minimum_size = BAR_SIZE_PX
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.max_value = have_need.y
			bar.value = have_need.x
			progress.add_child(bar)
		lines.add_child(progress)
	var said := _label(goal["line"], &"Secondary")
	said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	said.add_theme_font_override(&"font", _italic)
	lines.add_child(said)
	var row := PanelContainer.new()
	row.theme_type_variation = &"ProgressRow"
	row.add_child(lines)
	return row


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
