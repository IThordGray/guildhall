extends GutTest

## The screens are put on a layer above GUT's own output window, with Touch as main.tscn has it.
var _layer: CanvasLayer


func before_each() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_layer.add_child(Touch.new())


# A rank-E hall that reached rank D at 2_000 with 500 gold earned by then.
func _rank_d_hall() -> Hall:
	var hall := Hall.new(1_000)
	hall.layout = Hall.NEW_LAYOUT_E
	hall.rank = "D"
	hall.ranked_at.assign({"E": 1_000, "D": 2_000})
	hall.earned_at.assign({"E": 100, "D": 500})
	return hall


# A guild that meets every line of rank C: 150 reputation, The Third Ring cleared and 1,000 gold
# held, 1,800 earned in all. Nothing else: no parties of three, nothing explored past floor 3.
func _ready_guild() -> Dispatch:
	var dispatch := Dispatch.new(3_000)
	dispatch.reputation = 150
	dispatch.gold = Gold.new(1_000)
	dispatch.gold.earned = 1_800
	dispatch.labyrinth.explored.assign({"floor_3": 100})
	return dispatch


func _screen(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	_layer.add_child(screen)
	return screen


# The texts of the visible labels of each row under `rows`, then "✓" when it shows the tick.
func _rows(reception: Reception, rows: String) -> Array:
	var shown_rows := []
	for row: Node in reception.get_node(rows).get_children():
		var shown := []
		for part: Node in row.find_children("*", "Label", true, false):
			if (part as Label).is_visible_in_tree():
				shown.append((part as Label).text)
		if row.find_child("Tick", true, false) != null:
			shown.append("✓")
		shown_rows.append(shown)
	return shown_rows


func test_at_rank_d_with_all_three_met_rank_up_pays_1000_and_the_guild_is_rank_c_with_the_rank_up_recorded() -> void:
	var hall := _rank_d_hall()
	var dispatch := _ready_guild()
	assert_eq(hall.rank_up_refusal(dispatch, 3_000), "")
	assert_true(hall.rank_up(dispatch, 3_000))
	assert_eq(dispatch.gold.amount, 0)
	assert_eq(hall.rank, "C")
	assert_eq(hall.ranked_at, {"E": 1_000, "D": 2_000, "C": 3_000})
	assert_eq(hall.earned_at, {"E": 100, "D": 500, "C": 1_800})
	# Rank C grows no new rooms, and reputation is not spent.
	assert_eq(hall.layout, Hall.NEW_LAYOUT_E)
	assert_eq(dispatch.reputation, 150)
	assert_eq(hall.rank_up_refusal(dispatch, 3_000), "Highest rank for now")


func test_at_rank_d_with_any_one_line_unmet_ranking_up_is_refused_with_that_lines_reason_and_nothing_changes() -> void:
	var cases: Array = [
		["Need 1 more reputation", func(dispatch: Dispatch) -> void: dispatch.reputation = 149],
		["Clear The Third Ring first", func(dispatch: Dispatch) -> void: dispatch.labyrinth.explored["floor_3"] = 99],
		["Need 1 more gold", func(dispatch: Dispatch) -> void: dispatch.gold.amount = 999],
	]
	for unmet: Array in cases:
		var reason: String = unmet[0]
		var hall := _rank_d_hall()
		var dispatch := _ready_guild()
		(unmet[1] as Callable).call(dispatch)
		var held := dispatch.gold.amount
		assert_eq(hall.rank_up_refusal(dispatch, 3_000), reason)
		assert_false(hall.rank_up(dispatch, 3_000), reason)
		assert_eq(dispatch.gold.amount, held, reason)
		assert_eq(hall.rank, "D", reason)
		assert_eq(hall.ranked_at, {"E": 1_000, "D": 2_000}, reason)
		assert_eq(hall.earned_at, {"E": 100, "D": 500}, reason)


func test_ranking_up_from_f_still_leads_to_e_and_rank_e_still_asks_for_rank_ds_lines_not_rank_cs() -> void:
	# A new game's hall with both rooms in use and a guild that meets rank E's lines.
	var hall := Hall.new(1_000)
	var building := Gold.new(1_000)
	assert_true(hall.restore("side_left", building, 1_000))
	assert_true(hall.restore("back_left", building, 1_001))
	assert_true(hall.convert_room("side_left", "bunk_room", building, 1_005))
	assert_true(hall.convert_room("back_left", "common_room", building, 1_007))
	var dispatch := Dispatch.new(1_000)
	dispatch.reputation = 15
	dispatch.gold = Gold.new(150)
	assert_true(dispatch.adventurers.parties.move("tobin", Parties.NEW_PARTY, dispatch))
	dispatch.story_done.append("sealed_gate")
	assert_true(hall.rank_up(dispatch, 1_020))
	assert_eq([hall.rank, dispatch.gold.amount], ["E", 0])
	# Still rank E's lines at rank E, not rank C's.
	dispatch.reputation = 150
	dispatch.gold.amount = 1_000
	dispatch.labyrinth.explored.assign({"floor_3": 100})
	assert_eq(hall.rank_up_refusal(dispatch, 1_020), "Form 3 parties of 3 first")


func test_the_reception_at_rank_d_lists_the_three_lines_and_that_rank_c_opens_elite_expeditions() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var rank_up := reception.get_node("Box/Buttons/RankUp") as Button
	var hall := _rank_d_hall()
	var dispatch := _ready_guild()
	dispatch.reputation = 120
	dispatch.labyrinth.explored["floor_3"] = 80
	dispatch.gold.amount = 300
	reception.show_guild(hall, dispatch, 3_000)
	assert_eq((reception.get_node("Box/Scroll/Columns/Needs/Section") as Label).text, "TO RANK C")
	assert_eq(_rows(reception, "Box/Scroll/Columns/Needs/List/Rows"), [
		["Reputation", "120 / 150"],
		["The Third Ring cleared", "80 / 100"],
		["1000 gold", "300 / 1000"],
	])
	assert_eq((reception.get_node("Box/Scroll/Columns/Opens/Section") as Label).text, "RANK C OPENS")
	assert_eq(_rows(reception, "Box/Scroll/Columns/Opens/List/Rows"), [["Elite expeditions in the labyrinth"]])
	assert_false(rank_up.visible)
	# Every line met.
	dispatch.reputation = 150
	dispatch.labyrinth.explored["floor_3"] = 100
	dispatch.gold.amount = 1_000
	reception.show_guild(hall, dispatch, 3_001)
	assert_eq(_rows(reception, "Box/Scroll/Columns/Needs/List/Rows"), [
		["Reputation", "150 / 150", "✓"],
		["The Third Ring cleared", "✓"],
		["1000 gold", "✓"],
	])
	assert_true(rank_up.visible)
	assert_eq(rank_up.text, "Rank up · 1000g")


func test_the_reception_at_rank_c_shows_only_its_rank_and_back() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := _rank_d_hall()
	var dispatch := _ready_guild()
	assert_true(hall.rank_up(dispatch, 3_000))
	reception.show_guild(hall, dispatch, 3_000)
	assert_eq((reception.get_node("Box/Scroll/Columns/Side/Card/Rank/Words/Name") as Label).text, "Rank C guild")
	assert_false(reception.get_node("Box/Scroll/Columns/Needs").visible)
	assert_false(reception.get_node("Box/Scroll/Columns/Opens").visible)
	assert_false(reception.get_node("Box/Buttons/RankUp").visible)
	assert_true(reception.get_node("Box/Buttons/Back").visible)


func test_rank_up_to_c_opens_once_rank_up_to_d_is_claimed_and_is_done_at_guild_rank_c_paying_150() -> void:
	var hall := _rank_d_hall()
	var dispatch := _ready_guild()
	var goals := Goals.new()
	# Every goal before Rank up to D claimed.
	for id: String in Goals.GOALS:
		if id not in ["rank_d", "rank_c"]:
			goals.claimed.append(id)
	assert_eq(goals.state("rank_c", dispatch, hall, dispatch.story_done, 3_000), Goals.State.LOCKED)
	assert_true(goals.claim("rank_d", dispatch, hall, dispatch.story_done, 3_000))
	assert_eq(goals.state("rank_c", dispatch, hall, dispatch.story_done, 3_000), Goals.State.OPEN)
	assert_true(goals.shown(dispatch, hall, dispatch.story_done, 3_000).has("rank_c"))
	assert_eq(Goals.GOALS["rank_c"]["name"], "Rank up to C")
	assert_eq(Goals.GOALS["rank_c"]["kind"], Goals.STORY)
	assert_true(hall.rank_up(dispatch, 3_000))
	assert_eq(goals.state("rank_c", dispatch, hall, dispatch.story_done, 3_000), Goals.State.DONE)
	var gold := dispatch.gold.amount
	var unlocked := goals.unlocked.duplicate()
	assert_true(goals.claim("rank_c", dispatch, hall, dispatch.story_done, 3_000))
	assert_eq(dispatch.gold.amount, gold + 150)
	assert_eq(goals.unlocked, unlocked)
