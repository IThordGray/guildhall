extends GutTest

const Fixtures := preload("res://test/fixtures.gd")

const SAVE_PATH: String = "user://test_promotion_save.cfg"
const START: int = 1_000_000
const NO_HALLS: PackedInt64Array = []
const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]


## A guild of all four starters, as one saved before guild ranks has, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_promotion_to_e_takes_level_3_and_5_rank_e_successes_and_to_d_level_6_and_5_rank_d_successes_and_costs_nothing() -> void:
	var dispatch := _guild(START)
	var adventurers := dispatch.adventurers
	adventurers.levels["bram"] = 2
	adventurers.add_successes("bram", "E", 5)
	assert_false(adventurers.can_promote("bram", false))
	assert_false(adventurers.promote("bram", false))
	adventurers.levels["bram"] = 3
	# Earning it promotes nobody: an adventurer can stay F at any level.
	assert_eq(adventurers.roster["bram"]["rank"], "F")
	assert_true(adventurers.can_promote("bram", false))
	# A guild with no gold promotes all the same, and keeps its gold.
	assert_eq(dispatch.gold.amount, 0)
	assert_true(adventurers.promote("bram", false))
	assert_eq(adventurers.roster["bram"]["rank"], "E")
	assert_eq(dispatch.gold.amount, 0)
	adventurers.levels["bram"] = 6
	adventurers.add_successes("bram", "D", 4)
	assert_false(adventurers.can_promote("bram", false))
	adventurers.levels["bram"] = 5
	adventurers.add_successes("bram", "D", 1)
	assert_false(adventurers.can_promote("bram", false))
	adventurers.levels["bram"] = 6
	assert_true(adventurers.promote("bram", false))
	assert_eq(adventurers.roster["bram"]["rank"], "D")
	assert_eq(dispatch.gold.amount, 0)
	# The others are untouched.
	assert_eq(adventurers.roster["ilse"]["rank"], "F")


func test_a_promotion_is_refused_with_nothing_changed_short_of_the_level_or_the_next_ranks_successes_or_out_on_a_quest() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	# [level, successes by rank, out on a quest]. Lower-rank successes never count toward E.
	var cases := [
		[2, {"E": 5}, false],
		[3, {"E": 4, "F": 20}, false],
		[3, {"E": 5}, true],
	]
	var stats: Dictionary = adventurers.stats["bram"].duplicate()
	for case: Array in cases:
		adventurers.levels["bram"] = case[0]
		adventurers.successes["bram"] = case[1].duplicate()
		assert_false(adventurers.can_promote("bram", case[2]), str(case))
		assert_false(adventurers.promote("bram", case[2]), str(case))
		assert_eq(adventurers.roster["bram"]["rank"], "F", str(case))
		assert_eq(adventurers.stats["bram"], stats, str(case))
		assert_eq(adventurers.history["bram"], [], str(case))
	# The same adventurer, home, at the level and with the successes, is promoted.
	assert_true(adventurers.promote("bram", false))


func test_no_promotion_goes_past_d() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.next_rank("bram"), "E")
	adventurers.roster["bram"]["rank"] = "D"
	adventurers.levels["bram"] = 99
	adventurers.add_successes("bram", "D", 50)
	adventurers.add_successes("bram", "C", 50)
	assert_eq(adventurers.next_rank("bram"), "")
	assert_false(adventurers.can_promote("bram", false))
	assert_false(adventurers.promote("bram", false))
	assert_eq(adventurers.roster["bram"]["rank"], "D")


func test_promotion_is_earned_at_the_level_and_successes_the_next_rank_needs_and_never_at_the_highest_rank() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.add_successes("bram", "E", 5)
	adventurers.add_successes("bram", "D", 5)
	adventurers.levels["bram"] = 2
	assert_false(adventurers.can_promote("bram", false))
	adventurers.levels["bram"] = 3
	assert_true(adventurers.can_promote("bram", false))
	adventurers.roster["bram"]["rank"] = "E"
	adventurers.levels["bram"] = 5
	assert_false(adventurers.can_promote("bram", false))
	adventurers.levels["bram"] = 6
	assert_true(adventurers.can_promote("bram", false))
	adventurers.roster["bram"]["rank"] = "D"
	adventurers.levels["bram"] = 99
	assert_false(adventurers.can_promote("bram", false))


func test_a_promoted_adventurer_can_join_a_rank_d_quest_and_keeps_the_rank_through_save_and_load() -> void:
	var dispatch := _guild(START)
	dispatch.adventurers.levels["bram"] = 3
	dispatch.adventurers.add_successes("bram", "E", 5)
	Fixtures.party(dispatch, ["bram"])
	assert_eq(dispatch.party_refusal("maze", ["bram"], START), "Party rank too low")
	assert_true(dispatch.adventurers.promote("bram", false))
	assert_eq(dispatch.party_refusal("maze", ["bram"], START), "")
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, START)
	assert_eq(loaded.adventurers.roster["bram"]["rank"], "E")
	assert_eq(loaded.adventurers.roster["ilse"]["rank"], "F")
	assert_true(loaded.send("maze", ["bram"], 1, START))


func test_a_slot_due_before_a_promotion_fills_at_the_old_rank_and_later_refills_can_draw_rank_d() -> void:
	# A rank-E guild weighs rank D quests, so only the parties' ranks keep them off its board.
	const GUILD: String = "E"
	var gold := Gold.new(0)
	var dispatch := _guild(START)
	dispatch.adventurers.levels["maren"] = 3
	# Each a party of their own, so Maren's promotion is her party's.
	Fixtures.party(dispatch, ["bram"])
	Fixtures.party(dispatch, ["maren"])
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, START, NO_HALLS, -1, GUILD)
	# The goblin camp (E) is sent from slot 1, which comes due 60 seconds later.
	var sent_at := START + 9
	assert_eq(board.slots[1], "goblins")
	assert_true(board.send(dispatch, "goblins", ["bram"], 1, sent_at, NO_HALLS, -1, -1, GUILD))
	# Promoted a second after that slot refilled, before any other slot refills.
	var promoted_at := START + 70
	# Promoting first would let the slot due before it draw a rank D quest, so this case separates
	# the two orders.
	var wrong := Board.new()
	wrong.reception_slots = 3
	wrong.refill(_guild(START), START, NO_HALLS, -1, GUILD)
	var wrong_dispatch := _guild(START)
	Fixtures.party(wrong_dispatch, ["bram"])
	Fixtures.party(wrong_dispatch, ["maren"])
	assert_true(wrong.send(wrong_dispatch, "goblins", ["bram"], 1, sent_at, NO_HALLS, -1, -1, GUILD))
	wrong_dispatch.adventurers.roster["maren"]["rank"] = "E"
	wrong.refill(wrong_dispatch, promoted_at, NO_HALLS, -1, GUILD)
	assert_eq(Dispatch.QUESTS[wrong.slots[1]]["rank"], "D")
	# As main does it: the board is brought up to the moment, then the promotion.
	dispatch.checkpoint(promoted_at)
	board.refill(dispatch, promoted_at, NO_HALLS, -1, GUILD)
	dispatch.adventurers.add_successes("maren", "E", 5)
	assert_true(dispatch.adventurers.promote("maren", false))
	board.refill(dispatch, promoted_at + 1, NO_HALLS, -1, GUILD)
	assert_ne(board.slots[1], "")
	assert_ne(Dispatch.QUESTS[board.slots[1]]["rank"], "D")
	# Refills after the promotion draw rank D quests too.
	var ranks := {}
	var now := promoted_at
	for i: int in 30:
		# The first filled slot from slot i % 3 on, once one is: every slot can be between its quest
		# leaving and its refill at once.
		now += 3_600
		board.refill(dispatch, now, NO_HALLS, -1, GUILD)
		while board.filled() == 0:
			now += 1
			board.refill(dispatch, now, NO_HALLS, -1, GUILD)
		var sent := ""
		for k: int in 3:
			if sent == "":
				sent = board.slots[(i + k) % 3]
		assert_true(board.send(dispatch, sent, ["maren"], 1, now, NO_HALLS, -1, -1, GUILD), str(i))
		now += 3_600
		dispatch.checkpoint(now)
		while not dispatch.waiting_loot.is_empty(): dispatch.let_loot_go(0)
		board.refill(dispatch, now, NO_HALLS, -1, GUILD)
		for quest: String in board.slots:
			if quest != "":
				ranks[Dispatch.QUESTS[quest]["rank"]] = true
	assert_true(ranks.has("D"))


# Sends `members`, a party, on `quest` at `at` and brings them home, succeeding when `success`;
# the unix seconds they are back.
func _quest(dispatch: Dispatch, quest: String, members: PackedStringArray, success: bool, at: int) -> int:
	dispatch.injured_until.clear()
	assert_true(dispatch.send(quest, members, 1, at), quest)
	dispatch.outings[-1]["chance"] = 100 if success else 0
	var back := dispatch.back_at(dispatch.outings[-1])
	dispatch.checkpoint(back)
	return back


func test_a_successful_return_counts_one_quest_of_its_rank_for_each_member_and_a_failure_counts_none() -> void:
	var dispatch := _guild(START)
	dispatch.adventurers.gear.stash_cap = 100
	var party := Fixtures.party(dispatch, ["bram", "tobin"])
	var at := _quest(dispatch, "goblins", party, true, START)
	at = _quest(dispatch, "goblins", party, false, at)
	at = _quest(dispatch, "rats", party, true, at)
	_quest(dispatch, "well", party, true, at)
	for member: String in party:
		assert_eq(dispatch.adventurers.successes[member], {"E": 1, "F": 2}, member)
	# Only those who went count it.
	assert_eq(dispatch.adventurers.successes["ilse"], {})


func test_a_long_absence_counts_each_members_expected_successes_by_rank_rounded_down() -> void:
	var dispatch := Dispatch.new(START)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	var parties := dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, dispatch))
	assert_true(parties.move("maren", parties.party_of("ilse"), dispatch))
	parties.set_auto(parties.party_of("ilse"), true)
	# Ilse and Maren on Safe take only the rank F town well, a true 95%. With room for one item, the
	# second, in cycle 7, waits and stops them: 7 × 0.95 = 6.65 successes each, 6 counted.
	dispatch.adventurers.gear.stash_cap = 1
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, START, PackedInt64Array(), -1, "F")
	Auto.checkpoint(dispatch, board, START + 52_050 + Auto.REPLAY_SECONDS, PackedInt64Array())
	assert_eq(dispatch.tries, {"well": 7})
	for member: String in ["ilse", "maren"]:
		assert_eq(dispatch.adventurers.successes[member], {"F": 6}, member)
	# Bram and Tobin, Auto off, stayed home.
	assert_eq(dispatch.adventurers.successes["bram"], {})


func test_success_counts_survive_save_and_load_and_a_save_without_them_loads_with_none() -> void:
	var dispatch := _guild(START)
	dispatch.adventurers.add_successes("bram", "E", 3)
	dispatch.adventurers.add_successes("bram", "F", 7)
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, START)
	assert_eq(loaded.adventurers.successes["bram"], {"E": 3, "F": 7})
	assert_eq(loaded.adventurers.successes["ilse"], {})
	file.erase_section_key("adventurers", "successes")
	assert_eq(file.save(SAVE_PATH), OK)
	loaded = Dispatch.load_or_start(SAVE_PATH, START)
	for adventurer: String in EVERYONE:
		assert_eq(loaded.adventurers.successes[adventurer], {}, adventurer)
	# Counting from none on.
	loaded.adventurers.add_successes("bram", "E", 1)
	assert_eq(loaded.adventurers.successes["bram"], {"E": 1})


func test_a_dismissed_adventurers_count_goes_with_them() -> void:
	var dispatch := _guild(START)
	dispatch.adventurers.add_successes("ilse", "E", 5)
	dispatch.adventurers.add_successes("bram", "E", 2)
	assert_true(dispatch.dismiss("ilse"))
	assert_false(dispatch.adventurers.successes.has("ilse"))
	assert_eq(dispatch.adventurers.successes["bram"], {"E": 2})


func test_a_promotion_raises_each_stat_behind_the_title_it_had_by_1_and_records_it() -> void:
	var adventurers := Adventurers.new(PackedStringArray())
	var low := {}
	for stat: String in Adventurers.STATS:
		low[stat] = 2
	# Wren's Strength and Agility make her a Duellist; Ash's Strength and Mind are no pair, so his
	# title, a Brawler's, is his Strength's alone.
	var wren := low.merged({"strength": 8, "agility": 7, "mind": 6}, true)
	var ash := low.merged({"strength": 8, "mind": 7}, true)
	adventurers.add("wren", {"name": "Wren", "rank": "F"}, wren, low)
	adventurers.add("ash", {"name": "Ash", "rank": "F"}, ash, low)
	for adventurer: String in ["wren", "ash"]:
		adventurers.levels[adventurer] = 3
		adventurers.add_successes(adventurer, "E", 5)
		assert_true(adventurers.promote(adventurer, false), adventurer)
	assert_eq(adventurers.stats["wren"], low.merged({"strength": 9, "agility": 8, "mind": 6}, true))
	assert_eq(adventurers.history["wren"], [{"rank": "E", "gains": {"strength": 1, "agility": 1}}])
	assert_eq(adventurers.stats["ash"], low.merged({"strength": 9, "mind": 7}, true))
	assert_eq(adventurers.history["ash"], [{"rank": "E", "gains": {"strength": 1}}])


# The Adventurer screen, in the tree, showing `adventurer` of `dispatch`.
func _sheet(dispatch: Dispatch, adventurer: String) -> Adventurer:
	var sheet := (load("res://screens/adventurer.tscn") as PackedScene).instantiate() as Adventurer
	add_child_autofree(sheet)
	sheet.show_adventurer(adventurer, dispatch, Gold.new(0), 0, START)
	return sheet


func test_promote_shows_only_once_earned_and_home_and_changes_only_when_the_adventurer_is_shown_again() -> void:
	var dispatch := _guild(START)
	var adventurers := dispatch.adventurers
	adventurers.levels["bram"] = 3
	adventurers.add_successes("bram", "E", 4)
	var sheet := _sheet(dispatch, "bram")
	var promote := sheet.get_node("Box/Scroll/Content/Card/Header/Row/Words/Actions/Promote") as Button
	var dismiss := sheet.get_node("Box/Scroll/Content/Card/Header/Row/Words/Actions/Dismiss") as Button
	assert_false(promote.visible)
	assert_true(dismiss.visible)
	adventurers.add_successes("bram", "E", 1)
	# Nothing is read per frame: frames pass and Promote stays as it was shown.
	await wait_process_frames(2)
	assert_false(promote.visible)
	sheet.show_adventurer("bram", dispatch, Gold.new(0), 0, START)
	assert_true(promote.visible)
	assert_eq(promote.text, "Promote to E")
	# Out on a quest it hides, and shows again once home.
	Fixtures.party(dispatch, ["bram"])
	assert_true(dispatch.send("rats", ["bram"], 1, START))
	sheet.show_adventurer("bram", dispatch, Gold.new(0), 0, START)
	assert_false(promote.visible)
	assert_eq((sheet.get_node("Box/Scroll/Content/Card/Header/Row/Words/NameLine/Name") as Label).text, "Bram")
	dispatch.checkpoint(START + 60)
	sheet.show_adventurer("bram", dispatch, Gold.new(0), 0, START + 60)
	assert_true(promote.visible)


func test_promoting_lights_the_stats_it_raised_and_the_note_under_them_says_so() -> void:
	var dispatch := _guild(START)
	var adventurers := dispatch.adventurers
	adventurers.levels["bram"] = 3
	adventurers.add_successes("bram", "E", 5)
	# A level-up as a save from before promotions were recorded holds it.
	adventurers.history["bram"].append({"level": 3, "gains": {"strength": 1, "agility": 0}})
	var sheet := _sheet(dispatch, "bram")
	# As main.gd does it.
	sheet.promote_pressed.connect(func(adventurer: String) -> void:
		adventurers.promote(adventurer, false)
		sheet.show_adventurer(adventurer, dispatch, Gold.new(0), 0, START))
	var promote := sheet.get_node("Box/Scroll/Content/Card/Header/Row/Words/Actions/Promote") as Button
	var note := sheet.get_node("Box/Scroll/Content/Card/Stats/Rows/LastLevelUp") as Label
	var grid := sheet.get_node("Box/Scroll/Content/Card/Stats/Rows/Grid")
	assert_eq(note.text, "Level 3 · Strength +1")
	assert_eq(_lit(grid), [])
	var strength: int = adventurers.stats["bram"]["strength"]
	promote.pressed.emit()
	# Bram is a Fighter: Strength and Defence.
	assert_eq(adventurers.roster["bram"]["rank"], "E")
	assert_eq(adventurers.stats["bram"]["strength"], strength + 1)
	assert_eq(note.text, "Promoted to E · Strength +1 · Defence +1")
	assert_eq(_lit(grid), ["strength", "defence"])
	# Rank D is not earned yet.
	assert_false(promote.visible)


# The stats whose chips in `grid` are lit, in STATS order.
func _lit(grid: Node) -> Array[String]:
	var lit: Array[String] = []
	var stats := Adventurers.STATS.keys()
	for index: int in stats.size():
		if String((grid.get_child(index) as Control).theme_type_variation).ends_with("Changed"):
			lit.append(stats[index])
	return lit
