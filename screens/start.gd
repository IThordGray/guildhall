class_name StartScreen
extends Panel

## The player chose to carry on with the saved guild.
signal continue_pressed
## The player chose a fresh guild, having confirmed losing the saved one when there is one.
signal new_game_pressed

@onready var _choices: Control = $Menu/Choices
@onready var _continue: Button = $Menu/Choices/Continue
@onready var _confirm: Control = $Menu/Confirm


func _ready() -> void:
	_continue.pressed.connect(continue_pressed.emit)
	$Menu/Choices/NewGame.pressed.connect(_on_new_game_pressed)
	$Menu/Confirm/Box/Buttons/StartOver.pressed.connect(new_game_pressed.emit)
	$Menu/Confirm/Box/Buttons/Cancel.pressed.connect(_show_confirm.bind(false))


## Offers Continue only when there is a saved guild to continue.
func show_start(has_save: bool) -> void:
	_continue.visible = has_save


# A saved guild is only lost once the player confirms it.
func _on_new_game_pressed() -> void:
	if _continue.visible:
		_show_confirm(true)
	else:
		new_game_pressed.emit()


func _show_confirm(shown: bool) -> void:
	_choices.visible = not shown
	_confirm.visible = shown
