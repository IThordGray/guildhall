extends GutTest

const SAVE_PATH: String = "user://test_rank_d_save.cfg"
## The five ground-floor rooms of a rank-E hall that can take a job.
const ROOMS: PackedStringArray = ["back_left", "back_right", "side_left", "side_right", "front_right"]
const ROOM_TYPES: PackedStringArray = ["bunk_room", "common_room", "storeroom", "infirmary", "quest_hall"]

## The screens are put on a layer above GUT's own output window, with Touch as main.tscn has it.
var _layer: CanvasLayer


func before_each() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child_autofree(_layer)
	_layer.add_child(Touch.new())


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


# A hall that reached rank E at 1_000 with 100 gold earned by then, its five rooms in use at tier 2:
# hall level 10.
func _rank_e_hall() -> Hall:
	var hall := Hall.new(1_000)
	hall.layout = Hall.NEW_LAYOUT_E
	hall.rank = "E"
	hall.ranked_at.assign({"E": 1_000})
	hall.earned_at.assign({"E": 100})
	for index: int in ROOMS.size():
		hall.restored.append(ROOMS[index])
		hall.converted[ROOMS[index]] = {"type": ROOM_TYPES[index], "done_at": 1_000, "upgraded_at": [1_000]}
	return hall


# A guild that meets every other line of rank D: 60 reputation, three parties of three, 500 gold
# earned in all (400 since rank E), the floors explored 100, 50 and 30 (60 on average), both chapter-2
# story quests done and 500 gold held.
func _ready_guild() -> Dispatch:
	var dispatch := Dispatch.new(1_000)
	dispatch.reputation = 60
	dispatch.gold = Gold.new(500)
	dispatch.gold.earned = 500
	dispatch.adventurers.parties.parties.clear()
	for party: int in 3:
		var members := PackedStringArray()
		for member: int in 3:
			members.append("adventurer_%d_%d" % [party, member])
		dispatch.adventurers.parties.parties.append({"id": "party_%d" % party, "name": "", "members": members})
	dispatch.labyrinth.explored.assign({"floor_1": 100, "floor_2": 50, "floor_3": 30})
	dispatch.story_done = PackedStringArray(["cooks_debt", "lost_survey"])
	return dispatch


func _screen(path: String) -> Control:
	var screen := (load(path) as PackedScene).instantiate() as Control
	_layer.add_child(screen)
	return screen


func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click.xformed_by(get_viewport().get_final_transform()))
		Input.flush_buffered_events()


# Each checklist row as the texts of its visible labels, then "✓" when it shows the tick.
func _needs(reception: Reception) -> Array:
	var rows := []
	for row: Node in reception.get_node("Box/Scroll/Columns/Needs/List/Rows").get_children():
		var shown := []
		for part: Node in row.find_children("*", "Label", true, false):
			if (part as Label).is_visible_in_tree():
				shown.append((part as Label).text)
		if row.find_child("Tick", true, false) != null:
			shown.append("✓")
		rows.append(shown)
	return rows


func test_at_rank_e_with_all_nine_met_rank_up_pays_500_and_the_guild_is_rank_d_with_the_rank_up_recorded() -> void:
	var hall := _rank_e_hall()
	var dispatch := _ready_guild()
	assert_eq(hall.rank_up_refusal(dispatch, 2_000), "")
	assert_true(hall.rank_up(dispatch, 2_000))
	assert_eq(dispatch.gold.amount, 0)
	assert_eq(hall.rank, "D")
	assert_eq(hall.ranked_at, {"E": 1_000, "D": 2_000})
	assert_eq(hall.earned_at, {"E": 100, "D": 500})
	# Rank D grows no new rooms.
	assert_eq(hall.layout, Hall.NEW_LAYOUT_E)
	assert_eq(dispatch.reputation, 60)
	# Rank D's own lines apply from now on.
	assert_eq(hall.rank_up_refusal(dispatch, 2_000), "Need 90 more reputation")


func test_at_rank_e_with_any_one_line_unmet_ranking_up_is_refused_with_that_lines_reason_and_nothing_changes() -> void:
	var cases: Array = [
		["Need 1 more reputation", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.reputation = 59],
		["Form 3 parties of 3 first", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.adventurers.parties.parties[2]["members"].remove_at(0)],
		["Hall level 10 first", func(hall: Hall, _dispatch: Dispatch) -> void: hall.converted["front_right"].erase("upgraded_at")],
		["Earn 1 more gold first", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.gold.earned = 499],
		# 179 explored in all, 59 on average.
		["Explore the labyrinth further first", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.labyrinth.explored["floor_3"] = 29],
		# Still 60 on average.
		["Clear The Galleries first", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.labyrinth.explored.assign({"floor_1": 99, "floor_2": 51, "floor_3": 30})],
		["Finish The cook's debt first", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.story_done = PackedStringArray(["lost_survey"])],
		["Finish The lost survey first", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.story_done = PackedStringArray(["cooks_debt"])],
		["Need 1 more gold", func(_hall: Hall, dispatch: Dispatch) -> void: dispatch.gold.amount = 499],
	]
	for unmet: Array in cases:
		var reason: String = unmet[0]
		var hall := _rank_e_hall()
		var dispatch := _ready_guild()
		(unmet[1] as Callable).call(hall, dispatch)
		var held := dispatch.gold.amount
		assert_eq(hall.rank_up_refusal(dispatch, 2_000), reason)
		assert_false(hall.rank_up(dispatch, 2_000), reason)
		assert_eq(dispatch.gold.amount, held, reason)
		assert_eq(hall.rank, "E", reason)
		assert_eq(hall.ranked_at, {"E": 1_000}, reason)
		assert_eq(hall.earned_at, {"E": 100}, reason)
		assert_eq(hall.rank_up_checklist(dispatch, 2_000).filter(func(line: Dictionary) -> bool: return not line["met"]).size(), 1, reason)


func test_the_rank_e_checklist_has_its_nine_lines_in_order_each_with_what_it_has_needs_and_whether_it_is_met() -> void:
	var hall := _rank_e_hall()
	hall.converted["front_right"].erase("upgraded_at")
	var dispatch := _ready_guild()
	dispatch.reputation = 45
	dispatch.adventurers.parties.parties[0]["members"].remove_at(0)
	dispatch.gold.earned = 350
	dispatch.story_done = PackedStringArray(["cooks_debt"])
	dispatch.gold.amount = 300
	assert_eq(hall.rank_up_checklist(dispatch, 2_000), [
		{"what": "reputation", "has": 45, "needs": 60, "met": false},
		{"what": "parties", "size": 3, "has": 2, "needs": 3, "met": false},
		{"what": "hall_level", "has": 9, "needs": 10, "met": false},
		{"what": "earned", "has": 250, "needs": 400, "met": false},
		{"what": "explored", "has": 60, "needs": 60, "met": true},
		{"what": "cleared", "floor": "floor_1", "has": 100, "needs": 100, "met": true},
		{"what": "story", "quest": "cooks_debt", "has": 1, "needs": 1, "met": true},
		{"what": "story", "quest": "lost_survey", "has": 0, "needs": 1, "met": false},
		{"what": "gold", "has": 300, "needs": 500, "met": false},
	])


func test_the_hall_level_counts_a_conversion_or_an_upgrade_under_way_only_once_it_has_finished() -> void:
	var hall := _rank_e_hall()
	hall.converted.erase("front_right")
	var dispatch := _ready_guild()
	var gold := Gold.new(1_000)
	# A Tavern: converted in 2 seconds, upgraded to tier 2 in 4.
	assert_true(hall.convert_room("front_right", "tavern", gold, 2_000))
	assert_eq(hall.rank_up_checklist(dispatch, 2_001)[2]["has"], 8)
	assert_eq(hall.rank_up_checklist(dispatch, 2_002)[2]["has"], 9)
	hall.checkpoint(2_002)
	assert_true(hall.upgrade("front_right", gold, 2_002))
	assert_eq(hall.rank_up_refusal(dispatch, 2_005), "Hall level 10 first")
	assert_eq(hall.rank_up_refusal(dispatch, 2_006), "")


func test_gold_earned_counts_rewards_clear_bonuses_goal_claims_tavern_collections_and_autos_settle_but_never_selling() -> void:
	var dispatch := Dispatch.new(1_000)
	var gold := Gold.new(100)
	dispatch.gold = gold
	# The gold a game starts with is not earned.
	assert_eq(gold.earned, 0)
	# A quest's reward, from a seed it succeeds with.
	var pair := PackedStringArray(["bram", "tobin"])
	var roll_seed := 0
	while not Outcome.roll(roll_seed, dispatch.success_chance("well", pair), 0, pair).success:
		roll_seed += 1
	assert_true(dispatch.send("well", pair, roll_seed, 1_000))
	dispatch.checkpoint(1_003)
	assert_gt(gold.amount, 100)
	assert_eq(gold.earned, gold.amount - 100)
	# A floor's clear bonus.
	dispatch.labyrinth.explored["floor_1"] = 90
	var before := [gold.amount, gold.earned]
	dispatch.labyrinth.bring_home("floor_1", true, gold)
	assert_eq([gold.amount, gold.earned], [before[0] + 60, before[1] + 60])
	# A goal claim: the first quest home.
	var hall := Hall.new(1_000)
	before = [gold.amount, gold.earned]
	assert_true(Goals.new().claim("first_quest", dispatch, hall, dispatch.story_done, 1_003))
	assert_eq([gold.amount, gold.earned], [before[0] + 10, before[1] + 10])
	# A Tavern's collection: a minute at 20 gold a minute.
	hall.restored.append("side_left")
	hall.converted["side_left"] = {"type": "tavern", "done_at": 1_000}
	before = [gold.amount, gold.earned]
	assert_eq(hall.collect("side_left", gold, 1_060), 20)
	assert_eq([gold.amount, gold.earned], [before[0] + 20, before[1] + 20])
	# Selling from the stash adds to the gold held but is not earned.
	dispatch.adventurers.gear.stash.append("night_cloak")
	before = [gold.amount, gold.earned]
	assert_true(dispatch.adventurers.gear.sell("night_cloak", gold))
	assert_gt(gold.amount, before[0])
	assert_eq(gold.earned, before[1])
	# Auto's averaged settle of a long absence, then the hours played out.
	var parties := dispatch.adventurers.parties
	parties.set_auto(parties.party_of("bram"), true)
	dispatch.adventurers.gear.stash_cap = 1_000
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, 1_003, PackedInt64Array())
	before = [gold.amount, gold.earned]
	Auto.checkpoint(dispatch, board, 1_003 + Auto.REPLAY_SECONDS + 3_600, PackedInt64Array())
	assert_gt(gold.amount, before[0])
	assert_eq(gold.earned - before[1], gold.amount - before[0])


func test_a_reward_unpaid_in_a_save_from_before_counts_as_gold_earned_once_paid() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 100)
	file.set_value("dispatch", "debriefs", [{"quest": "goblins", "returned_at": 900, "success": true, "party": PackedStringArray(["bram", "ilse"]), "damage": {"bram": 9, "ilse": 12}, "injured": {}, "gold": 42, "xp": 15, "revealed": PackedStringArray(), "loot": PackedStringArray(), "paid": false, "xp_given": true}])
	file.set_value("dispatch", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)
	var dispatch := Dispatch.load_or_start(SAVE_PATH, 1_000)
	dispatch.gold = Gold.load_or_start(SAVE_PATH)
	dispatch.checkpoint(1_000)
	assert_eq([dispatch.gold.amount, dispatch.gold.earned], [142, 42])


func test_gold_earned_since_rank_e_counts_from_ranking_up_and_survives_save_and_load() -> void:
	# A rank-F hall with both rooms in use, ranked up by a guild that has earned 120 gold so far.
	var hall := Hall.new(1_000)
	var building := Gold.new(1_000)
	assert_true(hall.restore("side_left", building, 1_000))
	assert_true(hall.restore("back_left", building, 1_001))
	assert_true(hall.convert_room("side_left", "bunk_room", building, 1_005))
	assert_true(hall.convert_room("back_left", "common_room", building, 1_007))
	var dispatch := Dispatch.new(1_000)
	dispatch.reputation = 15
	dispatch.gold = Gold.new(200)
	dispatch.gold.earned = 120
	assert_true(dispatch.adventurers.parties.move("tobin", Parties.NEW_PARTY, dispatch))
	dispatch.story_done.append("sealed_gate")
	assert_true(hall.rank_up(dispatch, 1_020))
	assert_eq(hall.earned_at, {"E": 120})
	dispatch.gold.earn(300)
	assert_eq(hall.rank_up_checklist(dispatch, 1_030)[3], {"what": "earned", "has": 300, "needs": 400, "met": false})
	var file := ConfigFile.new()
	dispatch.gold.write(file)
	hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded_hall := Hall.load_or_start(SAVE_PATH, 1_030)
	var loaded_gold := Gold.load_or_start(SAVE_PATH)
	assert_eq(loaded_gold.earned, 420)
	assert_eq(loaded_hall.earned_at, {"E": 120})
	dispatch.gold = loaded_gold
	assert_eq(loaded_hall.rank_up_checklist(dispatch, 1_030)[3]["has"], 300)
	assert_eq(loaded_hall.rank_up_refusal(dispatch, 1_030), "Need 45 more reputation")


func test_an_old_save_already_at_rank_e_counts_gold_earned_from_0() -> void:
	var file := ConfigFile.new()
	file.set_value("gold", "saved", 700)
	file.set_value("hall", "layout", Hall.NEW_LAYOUT_E)
	file.set_value("hall", "rank", "E")
	file.set_value("hall", "ranked_at", {"E": 900})
	file.set_value("hall", "checked_at", 1_000)
	assert_eq(file.save(SAVE_PATH), OK)
	var hall := Hall.load_or_start(SAVE_PATH, 1_000)
	var dispatch := Dispatch.new(1_000)
	dispatch.gold = Gold.load_or_start(SAVE_PATH)
	assert_eq(dispatch.gold.amount, 700)
	assert_eq(hall.rank_up_checklist(dispatch, 1_000)[3]["has"], 0)
	dispatch.gold.earn(50)
	assert_eq(hall.rank_up_checklist(dispatch, 1_000)[3]["has"], 50)
	# One whose gold earned was counted, but with no record of it at rank E, counts all of it.
	file.set_value("gold", "earned", 250)
	assert_eq(file.save(SAVE_PATH), OK)
	dispatch.gold = Gold.load_or_start(SAVE_PATH)
	assert_eq(Hall.load_or_start(SAVE_PATH, 1_000).rank_up_checklist(dispatch, 1_000)[3]["has"], 250)


func test_the_reception_at_rank_e_lists_the_nine_lines_with_has_needs_and_ticks_and_rebuilds_as_they_change() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var rank_up := reception.get_node("Box/Buttons/RankUp") as Button
	var hall := _rank_e_hall()
	hall.converted["front_right"].erase("upgraded_at")
	var dispatch := _ready_guild()
	dispatch.reputation = 45
	dispatch.adventurers.parties.parties[0]["members"].remove_at(0)
	dispatch.gold.earned = 350
	dispatch.story_done = PackedStringArray(["cooks_debt"])
	dispatch.gold.amount = 300
	reception.show_guild(hall, dispatch, 2_000)
	assert_eq((reception.get_node("Box/Scroll/Columns/Needs/Section") as Label).text, "TO RANK D")
	assert_eq(_needs(reception), [
		["Reputation", "45 / 60"],
		["3 parties of 3", "2 / 3"],
		["Hall level 10", "9 / 10"],
		["400 gold earned", "250 / 400"],
		["Labyrinth 60% explored", "✓"],
		["The Galleries cleared", "✓"],
		["The cook's debt", "✓"],
		["The lost survey", "not done"],
		["500 gold", "300 / 500"],
	])
	assert_false(rank_up.visible)
	# Every line met.
	hall.converted["front_right"]["upgraded_at"] = [1_000]
	dispatch.reputation = 60
	dispatch.adventurers.parties.parties[0]["members"].append("adventurer_0_0")
	dispatch.gold.earned = 500
	dispatch.story_done.append("lost_survey")
	dispatch.gold.amount = 500
	reception.show_guild(hall, dispatch, 2_001)
	assert_eq(_needs(reception), [
		["Reputation", "60 / 60", "✓"],
		["3 parties of 3", "✓"],
		["Hall level 10", "✓"],
		["400 gold earned", "✓"],
		["Labyrinth 60% explored", "✓"],
		["The Galleries cleared", "✓"],
		["The cook's debt", "✓"],
		["The lost survey", "✓"],
		["500 gold", "✓"],
	])
	assert_true(rank_up.visible)
	assert_eq(rank_up.text, "Rank up · 500g")


func test_tapping_rank_up_at_rank_e_ranks_the_guild_up_to_d_and_the_reception_then_shows_rank_d_and_what_rank_c_needs() -> void:
	var reception := _screen("res://screens/reception.tscn") as Reception
	var hall := _rank_e_hall()
	var dispatch := _ready_guild()
	# As main.gd does once the player confirms.
	reception.rank_up_pressed.connect(func() -> void:
		hall.rank_up(dispatch, 2_000)
		reception.show_guild(hall, dispatch, 2_000))
	reception.show_guild(hall, dispatch, 2_000)
	await wait_process_frames(1)
	_tap((reception.get_node("Box/Buttons/RankUp") as Button).get_global_rect().get_center())
	await wait_process_frames(1)
	assert_eq(hall.rank, "D")
	assert_eq(dispatch.gold.amount, 0)
	assert_eq((reception.get_node("Box/Scroll/Columns/Side/Card/Rank/Words/Name") as Label).text, "Rank D guild")
	assert_eq((reception.get_node("Box/Scroll/Columns/Needs/Section") as Label).text, "TO RANK C")
	assert_false(reception.get_node("Box/Buttons/RankUp").visible)
	assert_true(reception.get_node("Box/Buttons/Back").visible)
