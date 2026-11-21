class_name ConfirmSheet
extends Control
## A small sheet at the bottom of the screen, over the dimmed screen, that asks to confirm an action
## that costs gold and time: the one exception to opening everything as a full screen. A tap
## outside it, Cancel or Android's Back closes it.

## The player confirmed the action offered.
signal confirmed

@onready var _title: Label = $Sheet/Box/Title
@onready var _cost: Label = $Sheet/Box/Price/Cost
@onready var _time: Label = $Sheet/Box/Price/Time
@onready var _action: Button = $Sheet/Box/Buttons/Action


func _ready() -> void:
	($Dim as Button).pressed.connect(close)
	($Sheet/Box/Buttons/Cancel as Button).pressed.connect(close)
	_action.pressed.connect(confirmed.emit)


## Opens the sheet, or updates it while open, on `title`, costing `gold` and taking `seconds`, done
## by a button reading `action`; while `refusal` gives a reason, the button is disabled and reads it.
func offer(title: String, gold: int, seconds: int, action: String, refusal: String) -> void:
	_title.text = title
	_cost.text = "%dg" % gold
	_time.text = Duration.label(seconds)
	_action.disabled = not refusal.is_empty()
	_action.text = action if refusal.is_empty() else refusal
	if not visible:
		show()
		# Back closes the sheet instead of leaving the app.
		get_tree().quit_on_go_back = false


func close() -> void:
	hide()
	# After the Back that closed the sheet has been handled, so it does not leave the app as well.
	get_tree().set_deferred(&"quit_on_go_back", true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		close()
