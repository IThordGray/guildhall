extends GutTest


func _hall_view() -> HallView:
	var view := (load("res://screens/hall_view.tscn") as PackedScene).instantiate() as HallView
	add_child_autofree(view)
	return view


# The text of every visible label in `node`.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			texts.append((label as Label).text)
	return texts


func test_a_new_guild_is_offered_the_first_restoration_at_60_gold_and_30_seconds_then_the_second_at_its_own_price() -> void:
	var view := _hall_view()
	var hall := Hall.new(1_000)
	var gold := Gold.new(Gold.STARTING_GOLD)
	view.show_state(hall, Dispatch.new(1_000), gold, 3, 1_000)
	assert_has(_texts(view), "60g · 0:30")
	assert_does_not_have(_texts(view), "120g · 2:00")
	assert_true(hall.restore("back_left", gold, 1_000))
	view.show_state(hall, Dispatch.new(1_000), gold, 3, 1_010)
	assert_has(_texts(view), "120g · 2:00")
	assert_does_not_have(_texts(view), "60g · 0:30")
	# The room's bar and its In progress row run over the first restoration's 30 seconds.
	var bars: Array[float] = []
	for bar: Node in view.find_children("*", "ProgressBar", true, false):
		if (bar as ProgressBar).is_visible_in_tree():
			bars.append((bar as ProgressBar).max_value)
	assert_has(bars, 30.0)
	assert_does_not_have(bars, 120.0)
