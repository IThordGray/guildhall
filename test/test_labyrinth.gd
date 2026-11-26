extends GutTest

const SAVE_PATH: String = "user://test_labyrinth_save.cfg"
const FLOORS: PackedStringArray = ["floor_1", "floor_2", "floor_3"]
const PAIR: PackedStringArray = ["bram", "tobin"]
const UNLOCKED: PackedStringArray = ["auto", "sealed_gate", "labyrinth"]

var _dispatch: Dispatch


func before_each() -> void:
	# A new game's Bram and Tobin in one party and Ilse, hired, in a party of her own, everyone rank E
	# so every floor takes them, with room in the stash for all the loot.
	_dispatch = Dispatch.new(1_000)
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	assert_true(_dispatch.adventurers.parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	for adventurer: String in _dispatch.adventurers.roster:
		_dispatch.adventurers.roster[adventurer]["rank"] = "E"
	_dispatch.adventurers.gear.stash_cap = 1_000


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


# A seed with which `party` ends `quest` as `success` says and brings loot, sent from the guild as it
# is, a lucky break counted as sending would.
func _seed(quest: String, party: PackedStringArray, success: bool) -> int:
	var luck := _dispatch.party_stat(party, "luck")
	var rank: String = Dispatch.QUESTS[quest]["rank"]
	for roll_seed: int in 10_000:
		var lucky: bool = Outcome.lucky_break(roll_seed, luck) and _dispatch.challenge_chances(quest, party).min() < Outcome.EVEN_CHANCE
		if Outcome.roll(roll_seed, _dispatch.success_chance(quest, party, lucky), 0, party).success == success and not Gear.loot(roll_seed, rank, luck).is_empty():
			return roll_seed
	fail_test("no seed found")
	return -1


# Sends `party` on `quest` at `at` to end as `success` says and brings it home.
func _go(quest: String, party: PackedStringArray, success: bool, at: int) -> void:
	assert_true(_dispatch.send(quest, party, _seed(quest, party, success), at))
	_dispatch.checkpoint(at + int(Dispatch.QUESTS[quest]["seconds"]))


func test_with_the_labyrinth_unlocked_only_floor_1_is_open_and_each_floor_after_opens_once_the_one_above_is_half_explored() -> void:
	# Without the unlock none is, however far explored.
	assert_eq(_dispatch.open_floors(PackedStringArray(["auto", "sealed_gate"])), PackedStringArray())
	assert_eq(_dispatch.open_floors(UNLOCKED), PackedStringArray(["floor_1"]))
	_dispatch.labyrinth.explored["floor_1"] = 45
	assert_eq(_dispatch.open_floors(UNLOCKED), PackedStringArray(["floor_1"]))
	_dispatch.labyrinth.explored["floor_1"] = 50
	assert_eq(_dispatch.open_floors(UNLOCKED), PackedStringArray(["floor_1", "floor_2"]))
	_dispatch.labyrinth.explored["floor_2"] = 49
	assert_eq(_dispatch.open_floors(UNLOCKED), PackedStringArray(["floor_1", "floor_2"]))
	_dispatch.labyrinth.explored["floor_2"] = 50
	assert_eq(_dispatch.open_floors(UNLOCKED), PackedStringArray(FLOORS))
	assert_eq(_dispatch.open_floors(PackedStringArray(["auto"])), PackedStringArray())
	# A floor opens from the one above it only while that one is open itself.
	_dispatch.labyrinth.explored["floor_1"] = 0
	assert_eq(_dispatch.open_floors(UNLOCKED), PackedStringArray(["floor_1"]))


func test_the_floors_are_the_galleries_the_drowned_stair_and_the_third_ring_each_with_its_material() -> void:
	var seen := []
	for quest: String in FLOORS:
		var info: Dictionary = Dispatch.QUESTS[quest]
		seen.append([info["name"], info["rank"], info["seconds"], info["gold"], info["xp"], info["challenges"], Labyrinth.FLOORS[quest]["material"], Labyrinth.FLOORS[quest]["clear_bonus"]])
		assert_true(Dispatch.is_floor(quest), quest)
		assert_false(Dispatch.is_story(quest), quest)
	assert_eq(seen, [
		["The Galleries", "E", 60, 45, 32, ["Traps", "Navigation", "Attrition"], "Glowmoss", 60],
		["The Drowned Stair", "E", 90, 60, 45, ["Curse", "Navigation", "Attrition"], "Riverglass", 100],
		["The Third Ring", "D", 120, 130, 85, ["Brute force", "Traps", "Curse"], "Bone silver", 200],
	])
	assert_false(Dispatch.is_floor("rats"))
	assert_false(Dispatch.is_floor("sealed_gate"))
	# Unlike a story quest, a floor's last challenge is unknown until a party has tried it.
	assert_eq(_dispatch.unknown_challenges("floor_1"), PackedStringArray(["Attrition"]))


func test_a_second_party_sent_to_a_floor_already_being_explored_is_refused_with_nothing_changed() -> void:
	assert_true(_dispatch.send("floor_1", PAIR, 1, 1_000))
	var outings := _dispatch.outings.duplicate(true)
	assert_eq(_dispatch.party_refusal("floor_1", ["ilse"], 1_001), "A party is out on it")
	assert_false(_dispatch.send("floor_1", ["ilse"], 1, 1_001))
	assert_eq(_dispatch.outings, outings)
	assert_eq(_dispatch.quest_of("ilse"), "")
	# Another floor, or a board quest, still takes her.
	assert_eq(_dispatch.party_refusal("floor_2", ["ilse"], 1_001), "")
	assert_eq(_dispatch.party_refusal("rats", ["ilse"], 1_001), "")


func test_a_floor_can_be_explored_again_and_again_after_a_success() -> void:
	_go("floor_1", PAIR, true, 1_000)
	assert_eq(_dispatch.party_refusal("floor_1", ["ilse"], 1_100), "")
	_go("floor_1", ["ilse"], true, 1_100)
	_go("floor_1", PAIR, true, 1_200)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_1"), 60)


func test_a_success_on_a_floor_explores_20_percent_brings_3_of_its_material_and_pays_as_any_quest() -> void:
	var gold := _dispatch.gold.amount
	var stash := _dispatch.adventurers.gear.stash.size()
	var roll_seed := _seed("floor_1", PAIR, true)
	assert_true(_dispatch.send("floor_1", PAIR, roll_seed, 1_000))
	var outing: Dictionary = _dispatch.outings[0].duplicate(true)
	_dispatch.checkpoint(1_059)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_1"), 0)
	_dispatch.checkpoint(1_060)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_1"), 20)
	assert_eq(_dispatch.labyrinth.materials, {"Glowmoss": 3})
	assert_eq(_dispatch.gold.amount - gold, 45)
	# 32 XP shared by two.
	assert_eq([_dispatch.adventurers.xp["bram"], _dispatch.adventurers.xp["tobin"]], [16, 16])
	assert_eq(_dispatch.reputation, 2)
	assert_eq(_dispatch.tries["floor_1"], 1)
	assert_eq(_dispatch.unknown_challenges("floor_1"), PackedStringArray())
	assert_eq(_dispatch.adventurers.gear.stash.size() - stash, 1)
	var damage: Dictionary = Outcome.roll(roll_seed, outing["chance"], Outcome.MOST_DAMAGE["E"], PAIR, outing["spirit"], outing["luck"]).damage
	for adventurer: String in PAIR:
		assert_eq(_dispatch.health(adventurer, 1_060), maxi(1, int(outing["health"][adventurer]) - int(damage[adventurer])), adventurer)
	# The floor above the next is still closed until this one is half explored.
	assert_eq(_dispatch.open_floors(UNLOCKED), PackedStringArray(["floor_1"]))


func test_a_failure_on_a_floor_explores_5_percent_brings_1_of_its_material_and_pays_as_any_quest() -> void:
	_dispatch.reputation = 5
	var gold := _dispatch.gold.amount
	var stash := _dispatch.adventurers.gear.stash.size()
	_go("floor_2", PAIR, false, 1_000)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_2"), 5)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_1"), 0)
	assert_eq(_dispatch.labyrinth.materials, {"Riverglass": 1})
	assert_eq(_dispatch.gold.amount - gold, 0)
	# A quarter of 45 is 11, shared by two.
	assert_eq([_dispatch.adventurers.xp["bram"], _dispatch.adventurers.xp["tobin"]], [5, 5])
	assert_eq(_dispatch.reputation, 4)
	assert_eq(_dispatch.tries["floor_2"], 1)
	assert_eq(_dispatch.adventurers.gear.stash.size() - stash, 1)


func test_explored_caps_at_100_and_a_floors_clear_bonus_is_paid_once_when_it_first_reaches_100() -> void:
	_dispatch.labyrinth.explored["floor_1"] = 90
	var gold := _dispatch.gold.amount
	_go("floor_1", PAIR, true, 1_000)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_1"), 100)
	assert_eq(_dispatch.gold.amount - gold, 45 + 60)
	gold = _dispatch.gold.amount
	_go("floor_1", PAIR, true, 1_100)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_1"), 100)
	assert_eq(_dispatch.gold.amount - gold, 45)
	assert_eq(_dispatch.labyrinth.materials, {"Glowmoss": 6})
	# A failure that reaches 100% pays the bonus too.
	_dispatch.labyrinth.explored["floor_2"] = 95
	gold = _dispatch.gold.amount
	_go("floor_2", ["ilse"], false, 1_200)
	assert_eq(_dispatch.labyrinth.explored_percent("floor_2"), 100)
	assert_eq(_dispatch.gold.amount - gold, 100)


func test_no_board_fill_draw_chance_or_auto_send_ever_picks_a_floor() -> void:
	for quest: String in FLOORS:
		assert_eq(Board.draw_chance(quest, _dispatch.adventurers, "E"), 0.0, quest)
	# The quests the board does draw share every draw between them.
	var total := 0.0
	for quest: String in Dispatch.QUESTS:
		total += Board.draw_chance(quest, _dispatch.adventurers, "E")
	assert_almost_eq(total, 1.0, 0.0001)
	var drawn := {}
	var board := Board.new()
	for at: int in range(1_000, 40_000, 15):
		board.refill(_dispatch, at, PackedInt64Array(), -1, "E")
		for quest: String in board.slots:
			drawn[quest] = true
	for quest: String in FLOORS:
		assert_false(drawn.has(quest), quest)
	# Every rank E and D board quest came up, and the floors are rank E and D.
	for quest: String in ["wolves", "sealed_door", "lurker", "crypt", "pilgrims", "goblins", "maze", "chapel", "minotaur", "envoy", "vault"]:
		assert_true(drawn.has(quest), quest)
	var parties := _dispatch.adventurers.parties
	for party: Dictionary in parties.parties:
		parties.set_auto(party["id"], true)
		parties.set_mode(party["id"], Parties.BOLD)
	board = Board.new()
	# An hour played out exactly.
	Auto.checkpoint(_dispatch, board, 4_600, PackedInt64Array(), -1, -1, "E")
	var tried := 0
	for count: int in _dispatch.tries.values():
		tried += count
	assert_gt(tried, 0)
	# Ten hours more, most of them averaged.
	Auto.checkpoint(_dispatch, board, 4_600 + 36_000, PackedInt64Array(), -1, -1, "E")
	var tried_after := 0
	for count: int in _dispatch.tries.values():
		tried_after += count
	assert_gt(tried_after, tried)
	for quest: String in FLOORS:
		assert_false(_dispatch.tries.has(quest), quest)
	assert_eq(_dispatch.labyrinth.explored, {})


func test_explored_the_clear_bonus_paid_and_materials_survive_save_and_load_and_an_older_save_has_none() -> void:
	_dispatch.labyrinth.explored["floor_1"] = 100
	_dispatch.labyrinth.explored["floor_2"] = 35
	_dispatch.labyrinth.materials["Glowmoss"] = 7
	_dispatch.labyrinth.materials["Riverglass"] = 2
	var file := ConfigFile.new()
	_dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_eq(loaded.labyrinth.explored, {"floor_1": 100, "floor_2": 35})
	assert_eq(loaded.labyrinth.materials, {"Glowmoss": 7, "Riverglass": 2})
	assert_eq(loaded.open_floors(UNLOCKED), PackedStringArray(["floor_1", "floor_2"]))
	# floor_1's clear bonus was paid before saving: going on it again pays only its gold.
	_dispatch = loaded
	_dispatch.adventurers.gear.stash_cap = 1_000
	var gold := _dispatch.gold.amount
	_go("floor_1", PAIR, true, 1_000)
	assert_eq(_dispatch.gold.amount - gold, 45)
	file.erase_section("labyrinth")
	assert_eq(file.save(SAVE_PATH), OK)
	var old := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_eq(old.labyrinth.explored, {})
	assert_eq(old.labyrinth.materials, {})
	assert_eq(old.open_floors(UNLOCKED), PackedStringArray(["floor_1"]))
	assert_eq(old.adventurers.roster.keys(), ["bram", "tobin", "ilse"])
