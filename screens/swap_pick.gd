class_name SwapPick
extends Control

## Who leaves the guild to make room for the walk-in, every bed being taken: the roster's rows on one
## card, as the roster lists them, those who can't be dismissed showing why and not pickable.

## The player picked `adventurer`, a key of Adventurers.roster, to leave for the walk-in.
signal picked(adventurer: String)
## The player went back without picking anyone.
signal back_pressed

## The adventurers the rows were built for, in roster order, so they are rebuilt only when someone
## joins or leaves; each one's row, status and health.
var _built: Array = []
var _rows: Dictionary[String, Button] = {}
var _statuses: Dictionary[String, Label] = {}
var _healths: Dictionary[String, HBoxContainer] = {}

@onready var _title: Label = $Box/Title
@onready var _list: VBoxContainer = $Box/Scroll/List


func _ready() -> void:
	($Box/Back as Button).pressed.connect(back_pressed.emit)
	_list.draw.connect(QuestBoard.draw_card.bind(_list))
	# Rows laid out after the first draw move the lines between them.
	_list.sort_children.connect(_list.queue_redraw)


## Shows who in `dispatch` can leave at `now` for the walk-in `walk_in_name`: everyone, with the
## reason Dispatch.dismiss_refusal gives on a row that can't be picked.
func show_dispatch(walk_in_name: String, dispatch: Dispatch, now: int) -> void:
	_title.text = "Who leaves for %s?" % walk_in_name
	var adventurers := dispatch.adventurers
	if adventurers.roster.keys() != _built:
		_built = adventurers.roster.keys()
		for row: Node in _list.get_children():
			_list.remove_child(row)
			row.queue_free()
		_rows.clear()
		_statuses.clear()
		_healths.clear()
		for adventurer: String in adventurers.roster:
			var row := Roster.adventurer_row(adventurer, adventurers)
			(row.find_child("Details", true, false) as Label).text = Roster.details_line(adventurers, adventurer)
			row.pressed.connect(picked.emit.bind(adventurer))
			_rows[adventurer] = row
			_statuses[adventurer] = row.find_child("Status", true, false)
			_healths[adventurer] = row.find_child("Health", true, false)
			_list.add_child(row)
	for adventurer: String in _rows:
		var reason := dispatch.dismiss_refusal(adventurer)
		_rows[adventurer].disabled = not reason.is_empty()
		_statuses[adventurer].text = reason if not reason.is_empty() else dispatch.status(adventurer, now)
		_statuses[adventurer].theme_type_variation = &"Alert" if not reason.is_empty() else Roster.status_look(dispatch, adventurer, now)
		Adventurer.show_health(_healths[adventurer], adventurer, dispatch, now)
