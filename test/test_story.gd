extends GutTest

const SAVE_PATH: String = "user://test_story_save.cfg"
const GATE: String = "sealed_gate"
const PAIR: PackedStringArray = ["bram", "tobin"]
const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]

var _dispatch: Dispatch
var _goals: Goals
var _hall: Hall


func before_each() -> void:
	# A new game's Bram and Tobin in one party and Ilse, hired, in a party of her own, with every
	# story goal before "Form a second party" claimed.
	_dispatch = Dispatch.new(1_000)
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	assert_true(_dispatch.adventurers.parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	_hall = Hall.new(1_000)
	_goals = Goals.new()
	_goals.claimed.append_array(["first_quest", "first_restore", "first_room", "first_recruit"])


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func _open() -> PackedStringArray:
	return _dispatch.open_story_quests(_goals.unlocked)


func _claim_second_party() -> void:
	assert_true(_goals.claim("second_party", _dispatch, _hall, _dispatch.story_done, 1_000))


# A seed with which `party` ends The sealed gate as `success` says, sent from the guild as it is, a
# lucky break counted as sending would.
func _seed(party: PackedStringArray, success: bool) -> int:
	var luck := _dispatch.party_stat(party, "luck")
	for roll_seed: int in 10_000:
		var lucky: bool = Outcome.lucky_break(roll_seed, luck) and _dispatch.challenge_chances(GATE, party).min() < Outcome.EVEN_CHANCE
		if Outcome.roll(roll_seed, _dispatch.success_chance(GATE, party, lucky), 0, party).success == success:
			return roll_seed
	fail_test("no seed found")
	return -1


func test_the_sealed_gate_is_a_rank_f_story_quest_of_curse_and_traps_taking_10_seconds_for_30_gold_and_15_xp() -> void:
	var gate: Dictionary = Dispatch.QUESTS[GATE]
	assert_eq([gate["name"], gate["rank"], gate["challenges"], gate["seconds"], gate["gold"], gate["xp"]], ["The sealed gate", "F", ["Curse", "Traps"], 10, 30, 15])
	assert_true(Dispatch.is_story(GATE))
	assert_false(Dispatch.is_story("rats"))


func test_the_board_never_draws_the_sealed_gate() -> void:
	assert_eq(Board.draw_chance(GATE, _dispatch.adventurers, "F"), 0.0)
	# The quests the board does draw share every draw between them.
	var total := 0.0
	for quest: String in Dispatch.QUESTS:
		total += Board.draw_chance(quest, _dispatch.adventurers, "F")
	assert_almost_eq(total, 1.0, 0.0001)
	var drawn := {}
	var board := Board.new()
	for at: int in range(1_000, 40_000, 15):
		board.refill(_dispatch, at, PackedInt64Array())
		for quest: String in board.slots:
			drawn[quest] = true
	assert_false(drawn.has(GATE))
	# Every rank F quest on the board came up, and the gate is rank F.
	for quest: String in ["rats", "well", "letters", "spiders", "cartographer", "mouth", "moonherbs"]:
		assert_true(drawn.has(quest), quest)


func test_every_challenge_of_the_sealed_gate_is_known_and_its_range_is_10_either_side_of_its_chance() -> void:
	assert_eq(_dispatch.unknown_challenges(GATE), PackedStringArray())
	# A board quest with two challenges starts with its last unknown.
	assert_eq(_dispatch.unknown_challenges("mouth"), PackedStringArray(["Navigation"]))
	var chance := _dispatch.success_chance(GATE, PAIR)
	assert_eq(_dispatch.chance_range(GATE, PAIR), Vector2i(chance - 10, chance + 10))


func test_the_sealed_gate_opens_once_form_a_second_party_is_claimed_and_not_before() -> void:
	assert_eq(_open(), PackedStringArray())
	_claim_second_party()
	assert_eq(_open(), PackedStringArray([GATE]))


func test_a_party_goes_on_the_sealed_gate_without_a_board_slot_and_no_party_can_go_while_it_is_out() -> void:
	_claim_second_party()
	var board := Board.new()
	board.refill(_dispatch, 1_000, PackedInt64Array())
	var slots := board.slots.duplicate()
	assert_true(_dispatch.send(GATE, PAIR, 1, 1_000))
	board.refill(_dispatch, 1_000, PackedInt64Array())
	assert_eq(board.slots, slots)
	# Still open while out, but nobody else can go on it.
	assert_eq(_open(), PackedStringArray([GATE]))
	assert_eq(_dispatch.party_refusal(GATE, ["ilse"], 1_001), "A party is out on it")
	assert_false(_dispatch.send(GATE, ["ilse"], 1, 1_001))
	assert_eq(_dispatch.outings.size(), 1)
	# Ilse can still go on a board quest.
	assert_eq(_dispatch.party_refusal("rats", ["ilse"], 1_001), "")


func test_auto_never_sends_a_party_on_the_sealed_gate_exact_or_averaged() -> void:
	_claim_second_party()
	var parties := _dispatch.adventurers.parties
	for party: Dictionary in parties.parties:
		parties.set_auto(party["id"], true)
		parties.set_mode(party["id"], Parties.BOLD)
	# Room for all the loot, so no party stops on loot waiting.
	_dispatch.adventurers.gear.stash_cap = 1_000
	var board := Board.new()
	# An hour played out exactly.
	Auto.checkpoint(_dispatch, board, 4_600, PackedInt64Array())
	var tried := 0
	for count: int in _dispatch.tries.values():
		tried += count
	assert_gt(tried, 0)
	assert_false(_dispatch.tries.has(GATE))
	# Ten hours more, most of them averaged.
	Auto.checkpoint(_dispatch, board, 4_600 + 36_000, PackedInt64Array())
	var tried_after := 0
	for count: int in _dispatch.tries.values():
		tried_after += count
	assert_gt(tried_after, tried)
	assert_false(_dispatch.tries.has(GATE))


func test_a_success_on_the_sealed_gate_pays_30_gold_and_15_xp_adds_3_reputation_and_marks_it_and_its_goal_done() -> void:
	_claim_second_party()
	var gold := _dispatch.gold.amount
	assert_eq(_goals.state("sealed_gate", _dispatch, _hall, _dispatch.story_done, 1_000), Goals.State.OPEN)
	assert_true(_dispatch.send(GATE, PAIR, _seed(PAIR, true), 1_000))
	_dispatch.checkpoint(1_009)
	assert_eq(_dispatch.story_done, PackedStringArray())
	_dispatch.checkpoint(1_010)
	assert_eq(_dispatch.gold.amount - gold, 30)
	assert_eq([_dispatch.adventurers.xp["bram"], _dispatch.adventurers.xp["tobin"]], [7, 7])
	assert_eq(_dispatch.reputation, 3)
	assert_eq(_dispatch.story_done, PackedStringArray([GATE]))
	assert_eq(_open(), PackedStringArray())
	assert_eq(_goals.state("sealed_gate", _dispatch, _hall, _dispatch.story_done, 1_010), Goals.State.DONE)
	assert_eq(_dispatch.party_refusal(GATE, ["ilse"], 1_010), "Already done")


func test_a_failure_on_the_sealed_gate_pays_no_gold_a_quarter_of_the_xp_takes_1_reputation_and_leaves_it_open() -> void:
	_claim_second_party()
	_dispatch.reputation = 5
	var gold := _dispatch.gold.amount
	assert_true(_dispatch.send(GATE, PAIR, _seed(PAIR, false), 1_000))
	_dispatch.checkpoint(1_010)
	assert_eq(_dispatch.gold.amount - gold, 0)
	# A quarter of 15 is 3, shared by two.
	assert_eq([_dispatch.adventurers.xp["bram"], _dispatch.adventurers.xp["tobin"]], [1, 1])
	assert_eq(_dispatch.reputation, 4)
	assert_eq(_dispatch.story_done, PackedStringArray())
	assert_eq(_open(), PackedStringArray([GATE]))
	assert_eq(_goals.state("sealed_gate", _dispatch, _hall, _dispatch.story_done, 1_010), Goals.State.OPEN)
	assert_true(_dispatch.send(GATE, ["ilse"], 1, 1_010))


func test_the_story_quests_done_survive_save_and_load_and_a_save_from_before_story_quests_has_none() -> void:
	_dispatch.story_done.append(GATE)
	var file := ConfigFile.new()
	_dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	assert_eq(Dispatch.load_or_start(SAVE_PATH, 1_000).story_done, PackedStringArray([GATE]))
	file.erase_section_key("dispatch", "story_done")
	assert_eq(file.save(SAVE_PATH), OK)
	var old := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_eq(old.story_done, PackedStringArray())
	assert_eq(old.adventurers.roster.keys(), ["bram", "tobin", "ilse"])


func test_bram_and_tobin_at_level_1_in_their_starting_gear_have_55_to_65_percent_and_four_at_levels_2_to_3_more() -> void:
	var pair := Dispatch.new(1_000).success_chance(GATE, PAIR)
	assert_between(pair, 55, 65)
	var four := Dispatch.new(1_000)
	four.adventurers = Adventurers.new(EVERYONE)
	var levels := {"bram": 3, "ilse": 2, "tobin": 3, "maren": 2}
	for adventurer: String in levels:
		while four.adventurers.levels[adventurer] < levels[adventurer]:
			four.adventurers.gain_xp(adventurer, four.adventurers.xp_needed(adventurer))
			four.adventurers.level_up(adventurer)
	assert_gt(four.success_chance(GATE, EVERYONE), pair)
