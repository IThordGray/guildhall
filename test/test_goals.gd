extends GutTest

const SAVE_PATH: String = "user://test_goals_save.cfg"
const NONE_DONE: PackedStringArray = []

var _goals: Goals
var _dispatch: Dispatch
var _hall: Hall


func before_each() -> void:
	_goals = Goals.new()
	# A new game's guild: Bram and Tobin in one party.
	_dispatch = Dispatch.new(1_000)
	_dispatch.gold = Gold.new(1_000)
	_hall = Hall.new(1_000)


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func _state(id: String, at: int, story_done: PackedStringArray = NONE_DONE) -> Goals.State:
	return _goals.state(id, _dispatch, _hall, story_done, at)


func _claim(id: String, at: int, story_done: PackedStringArray = NONE_DONE) -> bool:
	return _goals.claim(id, _dispatch, _hall, story_done, at)


func test_each_chapter_one_story_goal_opens_once_the_one_before_is_claimed_and_is_done_once_its_count_meets_the_target() -> void:
	assert_eq(_state("first_quest", 1_000), Goals.State.OPEN)
	assert_eq(_goals.progress("first_quest", _dispatch, _hall, NONE_DONE, 1_000), Vector2i(0, 1))
	for id: String in ["first_restore", "first_room", "first_recruit", "second_party", "sealed_gate", "rank_e"]:
		assert_eq(_state(id, 1_000), Goals.State.LOCKED, id)
	# A party home from the rats. A room restored already stays locked until the goal before is claimed.
	_dispatch.tries["rats"] = 1
	assert_true(_hall.restore("side_left", _dispatch.gold, 1_000))
	assert_eq(_state("first_quest", 1_000), Goals.State.DONE)
	assert_eq(_state("first_restore", 1_001), Goals.State.LOCKED)
	assert_true(_claim("first_quest", 1_000))
	# The restoration takes a second.
	assert_eq(_state("first_restore", 1_000), Goals.State.OPEN)
	assert_eq(_state("first_restore", 1_001), Goals.State.DONE)
	assert_true(_claim("first_restore", 1_001))
	# A Bunk room takes two seconds to convert.
	assert_eq(_state("first_room", 1_001), Goals.State.OPEN)
	assert_true(_hall.convert_room("side_left", "bunk_room", _dispatch.gold, 1_001))
	assert_eq(_state("first_room", 1_002), Goals.State.OPEN)
	assert_eq(_state("first_room", 1_003), Goals.State.DONE)
	assert_true(_claim("first_room", 1_003))
	assert_eq(_goals.progress("first_recruit", _dispatch, _hall, NONE_DONE, 1_003), Vector2i(2, 3))
	assert_eq(_state("first_recruit", 1_003), Goals.State.OPEN)
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	assert_eq(_state("first_recruit", 1_003), Goals.State.DONE)
	assert_true(_claim("first_recruit", 1_003))
	assert_eq(_state("second_party", 1_003), Goals.State.OPEN)
	assert_true(_dispatch.adventurers.parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	assert_eq(_state("second_party", 1_003), Goals.State.DONE)
	assert_true(_claim("second_party", 1_003))
	# The sealed gate is done only once its story quest is.
	assert_eq(_state("sealed_gate", 1_003), Goals.State.OPEN)
	assert_eq(_state("sealed_gate", 1_003, PackedStringArray(["sealed_gate"])), Goals.State.DONE)
	assert_true(_claim("sealed_gate", 1_003, PackedStringArray(["sealed_gate"])))
	assert_eq(_state("rank_e", 1_003), Goals.State.OPEN)
	_hall.rank = "E"
	assert_eq(_state("rank_e", 1_003), Goals.State.DONE)
	assert_true(_claim("rank_e", 1_003))
	assert_eq(_goals.claimed, PackedStringArray(["first_quest", "first_restore", "first_room", "first_recruit", "second_party", "sealed_gate", "rank_e"]))
	for id: String in _goals.claimed:
		assert_eq(_state(id, 1_003), Goals.State.CLAIMED, id)
	# The side goal, never claimed, held nothing back.
	assert_eq(_state("hand_quests", 1_003), Goals.State.OPEN)


func test_claiming_pays_records_the_claim_and_turns_on_its_unlock_and_a_refused_claim_changes_nothing() -> void:
	_dispatch.reputation = 5
	# Locked, then open but not done: refused.
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	assert_false(_claim("first_recruit", 1_000))
	assert_false(_claim("first_quest", 1_000))
	assert_eq([_dispatch.gold.amount, _dispatch.reputation, _goals.claimed, _goals.unlocked], [1_000, 5, PackedStringArray(), PackedStringArray()])
	_dispatch.tries["well"] = 2
	assert_true(_claim("first_quest", 1_000))
	assert_eq([_dispatch.gold.amount, _dispatch.reputation, _goals.claimed], [1_010, 5, PackedStringArray(["first_quest"])])
	# At most once.
	assert_false(_claim("first_quest", 1_000))
	assert_eq(_dispatch.gold.amount, 1_010)
	# Two parties unlock the sealed gate's story quest; the gate itself pays reputation too and
	# unlocks the labyrinth.
	_goals.claimed.append_array(["first_restore", "first_room", "first_recruit"])
	assert_true(_dispatch.adventurers.parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	assert_true(_claim("second_party", 1_000))
	assert_eq([_dispatch.gold.amount, _dispatch.reputation, _goals.unlocked], [1_030, 5, PackedStringArray(["sealed_gate"])])
	assert_true(_claim("sealed_gate", 1_000, PackedStringArray(["sealed_gate"])))
	assert_eq([_dispatch.gold.amount, _dispatch.reputation, _goals.unlocked], [1_060, 8, PackedStringArray(["sealed_gate", "labyrinth"])])


func test_hand_sends_that_come_home_count_and_auto_sends_do_not_and_ten_make_hand_quests_done_whose_claim_unlocks_auto() -> void:
	_dispatch.adventurers = Adventurers.new(PackedStringArray(["bram", "tobin", "ilse", "maren"]))
	var parties := _dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	assert_true(parties.move("maren", parties.party_of("ilse"), _dispatch))
	_dispatch.adventurers.gear.stash_cap = 1_000
	# Ilse and Maren go by themselves on the town well whenever it is on the board.
	parties.set_auto(parties.party_of("ilse"), true)
	var board := Board.new()
	board.reception_slots = 1
	board.slots = PackedStringArray(["well"])
	board.refill_at.resize(1)
	board.filled_at.resize(1)
	board.filled_at.fill(1_000)
	board.checked_at = 1_000
	var by_hand := PackedStringArray(["bram", "tobin"])
	for sent: int in 10:
		var at := 1_000 + 100 * sent
		Auto.checkpoint(_dispatch, board, at, PackedInt64Array())
		_goals.count_home(_dispatch)
		assert_eq(_goals.hand_quests, sent)
		assert_eq(_state("hand_quests", at), Goals.State.OPEN)
		assert_true(_dispatch.send("rats", by_hand, sent, at))
		_goals.sent_by_hand(_dispatch.outings.back())
		# Out, not home yet.
		_goals.count_home(_dispatch)
		assert_eq(_goals.hand_quests, sent)
	Auto.checkpoint(_dispatch, board, 2_000, PackedInt64Array())
	_goals.count_home(_dispatch)
	assert_eq(_goals.hand_quests, 10)
	# The Auto party came home from quests too, uncounted.
	assert_gt(_dispatch.tries["well"], 0)
	assert_eq(_state("hand_quests", 2_000), Goals.State.DONE)
	assert_false(_goals.is_unlocked(Goals.AUTO))
	var gold := _dispatch.gold.amount
	assert_true(_claim("hand_quests", 2_000))
	assert_true(_goals.is_unlocked(Goals.AUTO))
	assert_eq(_dispatch.gold.amount, gold + 20)


func test_goals_survive_save_and_load() -> void:
	_goals.claimed = PackedStringArray(["first_quest", "hand_quests"])
	_goals.unlocked = PackedStringArray(["auto"])
	_goals.hand_quests = 12
	_goals.out_by_hand = PackedStringArray(["party_1@1500"])
	var file := ConfigFile.new()
	_goals.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Goals.load_or_start(SAVE_PATH)
	assert_eq(loaded.claimed, PackedStringArray(["first_quest", "hand_quests"]))
	assert_eq(loaded.unlocked, PackedStringArray(["auto"]))
	assert_eq(loaded.hand_quests, 12)
	assert_eq(loaded.out_by_hand, PackedStringArray(["party_1@1500"]))
	# The outing noted still counts once it is home.
	loaded.count_home(_dispatch)
	assert_eq(loaded.hand_quests, 13)


func test_a_save_without_goals_has_auto_unlocked_and_the_goals_it_already_meets_are_claimable_and_a_new_game_has_auto_locked() -> void:
	# A guild that has quested and restored a room before goals.
	_dispatch.tries["rats"] = 4
	_hall.restored.append("side_left")
	var file := ConfigFile.new()
	_dispatch.write(file)
	_hall.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	_goals = Goals.load_or_start(SAVE_PATH)
	assert_true(_goals.is_unlocked(Goals.AUTO))
	assert_eq(_goals.claimed, PackedStringArray())
	assert_eq(_state("first_quest", 1_000), Goals.State.DONE)
	assert_true(_claim("first_quest", 1_000))
	assert_eq(_state("first_restore", 1_000), Goals.State.DONE)
	assert_eq(_state("first_room", 1_000), Goals.State.LOCKED)
	# A new game: no save at all.
	DirAccess.remove_absolute(SAVE_PATH)
	var fresh := Goals.load_or_start(SAVE_PATH)
	assert_false(fresh.is_unlocked(Goals.AUTO))
	assert_eq(fresh.claimed, PackedStringArray())
	assert_eq(fresh.hand_quests, 0)
