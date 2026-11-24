extends GutTest

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


func test_promotion_to_e_takes_level_3_and_150_gold_and_to_d_level_6_and_400_gold() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	var gold := Gold.new(150)
	adventurers.levels["bram"] = 2
	assert_eq(adventurers.promotion_refusal("bram", gold, false), "Needs level 3")
	assert_false(adventurers.promote("bram", gold, false))
	adventurers.levels["bram"] = 3
	# Reaching the level promotes nobody: an adventurer can stay F at any level.
	assert_eq(adventurers.roster["bram"]["rank"], "F")
	assert_eq(adventurers.promotion_refusal("bram", gold, false), "")
	assert_true(adventurers.promote("bram", gold, false))
	assert_eq(adventurers.roster["bram"]["rank"], "E")
	assert_eq(gold.amount, 0)
	gold = Gold.new(400)
	adventurers.levels["bram"] = 5
	assert_eq(adventurers.promotion_refusal("bram", gold, false), "Needs level 6")
	adventurers.levels["bram"] = 6
	assert_true(adventurers.promote("bram", gold, false))
	assert_eq(adventurers.roster["bram"]["rank"], "D")
	assert_eq(gold.amount, 0)
	# The others are untouched.
	assert_eq(adventurers.roster["ilse"]["rank"], "F")


func test_a_refused_promotion_says_why_and_changes_neither_gold_nor_rank() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.levels["bram"] = 3
	var cases := [
		[2, 500, false, "Needs level 3"],
		[3, 149, false, "Not enough gold"],
		[3, 500, true, "Out on a quest"],
	]
	for case: Array in cases:
		adventurers.levels["bram"] = case[0]
		var gold := Gold.new(case[1])
		assert_eq(adventurers.promotion_refusal("bram", gold, case[2]), case[3], str(case))
		assert_false(adventurers.promote("bram", gold, case[2]), str(case))
		assert_eq(gold.amount, case[1], str(case))
		assert_eq(adventurers.roster["bram"]["rank"], "F", str(case))
	# The same adventurer, home, at the level and with the gold, is promoted.
	assert_true(adventurers.promote("bram", Gold.new(150), false))


func test_no_promotion_goes_past_d() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	assert_eq(adventurers.next_rank("bram"), "E")
	adventurers.roster["bram"]["rank"] = "D"
	adventurers.levels["bram"] = 99
	var gold := Gold.new(99_999)
	assert_eq(adventurers.next_rank("bram"), "")
	assert_eq(adventurers.promotion_refusal("bram", gold, false), "Highest rank")
	assert_false(adventurers.promote("bram", gold, false))
	assert_eq(adventurers.roster["bram"]["rank"], "D")
	assert_eq(gold.amount, 99_999)


func test_the_promotion_level_is_reached_at_the_level_the_next_rank_needs_and_never_at_the_highest_rank() -> void:
	var adventurers := Adventurers.new(EVERYONE)
	adventurers.levels["bram"] = 2
	assert_false(adventurers.reached_promotion_level("bram"))
	adventurers.levels["bram"] = 3
	assert_true(adventurers.reached_promotion_level("bram"))
	adventurers.roster["bram"]["rank"] = "E"
	adventurers.levels["bram"] = 5
	assert_false(adventurers.reached_promotion_level("bram"))
	adventurers.levels["bram"] = 6
	assert_true(adventurers.reached_promotion_level("bram"))
	adventurers.roster["bram"]["rank"] = "D"
	adventurers.levels["bram"] = 99
	assert_false(adventurers.reached_promotion_level("bram"))


func test_a_promoted_adventurer_can_join_a_rank_d_quest_and_keeps_the_rank_through_save_and_load() -> void:
	var dispatch := _guild(START)
	var gold := Gold.new(150)
	dispatch.adventurers.levels["bram"] = 3
	assert_eq(dispatch.party_refusal("maze", ["bram"], START), "Bram's rank is too low")
	assert_true(dispatch.adventurers.promote("bram", gold, false))
	assert_eq(dispatch.party_refusal("maze", ["bram"], START), "")
	var file := ConfigFile.new()
	dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, START)
	assert_eq(loaded.adventurers.roster["bram"]["rank"], "E")
	assert_eq(loaded.adventurers.roster["ilse"]["rank"], "F")
	assert_true(loaded.send("maze", ["bram"], 1, START))


func test_a_slot_due_before_a_promotion_fills_at_the_old_rank_and_later_refills_can_draw_rank_d() -> void:
	# A rank-E guild weighs rank D quests, so only the adventurers' ranks keep them off its board.
	const GUILD: String = "E"
	var gold := Gold.new(0)
	var dispatch := _guild(START)
	dispatch.adventurers.levels["maren"] = 3
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, START, NO_HALLS, -1, GUILD)
	# The goblin camp (E) is sent from slot 1, which comes due 60 seconds later.
	var sent_at := START + 9
	assert_eq(board.slots[1], "goblins")
	assert_true(board.send(dispatch, "goblins", ["bram"], 1, sent_at, NO_HALLS, -1, -1, GUILD))
	var promoted_at := START + 1_000
	# Promoting first would let the slot due before it draw a rank D quest, so this case separates
	# the two orders.
	var wrong := Board.new()
	wrong.reception_slots = 3
	wrong.refill(_guild(START), START, NO_HALLS, -1, GUILD)
	var wrong_dispatch := _guild(START)
	assert_true(wrong.send(wrong_dispatch, "goblins", ["bram"], 1, sent_at, NO_HALLS, -1, -1, GUILD))
	wrong_dispatch.adventurers.roster["maren"]["rank"] = "E"
	wrong.refill(wrong_dispatch, promoted_at, NO_HALLS, -1, GUILD)
	assert_eq(Dispatch.QUESTS[wrong.slots[1]]["rank"], "D")
	# As main does it: the board is brought up to the moment, then the promotion.
	dispatch.checkpoint(promoted_at)
	board.refill(dispatch, promoted_at, NO_HALLS, -1, GUILD)
	assert_true(dispatch.adventurers.promote("maren", Gold.new(150), false))
	board.refill(dispatch, promoted_at + 1, NO_HALLS, -1, GUILD)
	assert_ne(board.slots[1], "")
	assert_ne(Dispatch.QUESTS[board.slots[1]]["rank"], "D")
	# Refills after the promotion draw rank D quests too.
	var ranks := {}
	var now := promoted_at
	for i: int in 30:
		now += 3_600
		assert_true(board.send(dispatch, board.slots[i % 3], ["maren"], 1, now, NO_HALLS, -1, -1, GUILD), str(i))
		now += 3_600
		dispatch.checkpoint(now)
		while not dispatch.waiting_loot.is_empty(): dispatch.let_loot_go(0)
		board.refill(dispatch, now, NO_HALLS, -1, GUILD)
		for quest: String in board.slots:
			ranks[Dispatch.QUESTS[quest]["rank"]] = true
	assert_true(ranks.has("D"))
