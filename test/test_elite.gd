extends GutTest

const SAVE_PATH: String = "user://test_elite_save.cfg"
const ELITES: PackedStringArray = ["elite_1", "elite_2", "elite_3"]
const PAIR: PackedStringArray = ["bram", "tobin"]
## The moment the guild reached rank C in most tests: inside period 1, so period 2 is its first.
const RANK_C_AT: int = 1_000

var _dispatch: Dispatch


func before_each() -> void:
	# A new game's Bram and Tobin in one party and Ilse, hired, in a party of her own, everyone rank D
	# so a rank C elite takes them, with room in the stash for all the loot.
	_dispatch = Dispatch.new(0)
	_dispatch.adventurers.add("ilse", Adventurers.STARTERS["ilse"], Adventurers.STARTING_STATS["ilse"], Adventurers.GROWTH["ilse"])
	assert_true(_dispatch.adventurers.parties.move("ilse", Parties.NEW_PARTY, _dispatch))
	for adventurer: String in _dispatch.adventurers.roster:
		_dispatch.adventurers.roster[adventurer]["rank"] = "D"
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


# Sends `party` on `quest` at `at` to end as `success` says; the outing as it left.
func _send(quest: String, party: PackedStringArray, success: bool, at: int) -> Dictionary:
	assert_true(_dispatch.send(quest, party, _seed(quest, party, success), at), quest)
	return _dispatch.outings[-1].duplicate(true)


# Leaves `adventurer` with 1 health at `at`, as if just home from a hard quest.
func _wound_to_1(adventurer: String, at: int) -> void:
	_dispatch.wounds[adventurer] = {"health": 1, "at": at}


# The elite open at `at` for a guild that reached rank C at `rank_c_at`, or "" for none.
func _open_at(dispatch: Dispatch, rank_c_at: int, at: int) -> String:
	var open := dispatch.open_elites(rank_c_at, at)
	assert_lte(open.size(), 1)
	return "" if open.is_empty() else open.keys()[0]


func test_before_rank_c_no_elite_ever_opens() -> void:
	for at: int in range(0, 50 * 720, 30):
		assert_eq(_dispatch.open_elites(-1, at), {} as Dictionary[String, int], str(at))
	# The same times from rank C on do open some.
	var opened := 0
	for at: int in range(0, 50 * 720, 30):
		opened += _dispatch.open_elites(0, at).size()
	assert_gt(opened, 0)


func test_from_rank_c_one_elite_opens_every_720_s_on_a_seeded_floor_for_240_s() -> void:
	# Period 1 (720–1439) started before rank C: nothing in it.
	for at: int in [720, 999, 1_000, 1_200, 1_439]:
		assert_eq(_open_at(_dispatch, RANK_C_AT, at), "", str(at))
	# From period 2 on, each opens at its start and closes 240 s later.
	for period: int in range(2, 12):
		var opens := period * 720
		var elite := _open_at(_dispatch, RANK_C_AT, opens)
		assert_true(elite in ELITES, str(period))
		assert_eq(_dispatch.open_elites(RANK_C_AT, opens + 239), {elite: opens + 240} as Dictionary[String, int], str(period))
		assert_eq(_open_at(_dispatch, RANK_C_AT, opens + 240), "", str(period))
		assert_eq(_open_at(_dispatch, RANK_C_AT, opens + 719), "", str(period))
	# Rank C reached exactly at a period's start opens that period.
	assert_ne(_open_at(_dispatch, 1_440, 1_440), "")
	# The floor is drawn per period from the saved seed: every floor comes up, and another guild with
	# the same seed gets the same, one with another seed not.
	var same := Dispatch.new(0)
	same.labyrinth.elite_seed = _dispatch.labyrinth.elite_seed
	var other := Dispatch.new(0)
	other.labyrinth.elite_seed = _dispatch.labyrinth.elite_seed + 1
	var seen := {}
	var differs := false
	for period: int in range(2, 60):
		var elite := _open_at(_dispatch, RANK_C_AT, period * 720)
		seen[elite] = true
		assert_eq(_open_at(same, RANK_C_AT, period * 720), elite, str(period))
		differs = differs or _open_at(other, RANK_C_AT, period * 720) != elite
	assert_eq(seen.size(), 3)
	assert_true(differs)


func test_reading_once_after_an_absence_gives_the_same_windows_as_watching() -> void:
	# Watching: a check every 10 s, a party sent on the elite of period 4 as it opens, the game saved
	# then.
	var file := ConfigFile.new()
	var watched := {}
	for at: int in range(0, 10 * 720, 10):
		_dispatch.checkpoint(at)
		if at == 4 * 720:
			_send(_open_at(_dispatch, RANK_C_AT, at), PAIR, true, at)
			_dispatch.write(file)
		watched[at] = _dispatch.open_elites(RANK_C_AT, at)
	# Away: that save read once at each later time, with nothing in between.
	assert_eq(file.save(SAVE_PATH), OK)
	var opened := 0
	for at: int in range(4 * 720, 10 * 720, 10):
		var away := Dispatch.load_or_start(SAVE_PATH, 4 * 720)
		assert_eq(away.open_elites(RANK_C_AT, at), watched[at], str(at))
		opened += watched[at].size()
	assert_gt(opened, 0)


func test_a_sent_elite_is_gone_for_its_period_and_the_next_period_opens_its_own() -> void:
	var opens := 3 * 720
	var elite := _open_at(_dispatch, RANK_C_AT, opens + 100)
	assert_ne(elite, "")
	_send(elite, PAIR, true, opens + 100)
	for at: int in [opens + 100, opens + 239, opens + 400, opens + 719]:
		assert_eq(_open_at(_dispatch, RANK_C_AT, at), "", str(at))
	assert_ne(_open_at(_dispatch, RANK_C_AT, opens + 720), "")


func test_a_clock_set_back_never_reopens_a_closed_or_taken_elite_window() -> void:
	# Period 3's window closed unused; the clock read later, then set back into it.
	var opens := 3 * 720
	assert_ne(_open_at(_dispatch, RANK_C_AT, opens + 10), "")
	_dispatch.checkpoint(opens + 300)
	assert_eq(_open_at(_dispatch, RANK_C_AT, opens + 10), "")
	# Period 4's elite taken, then period 5's window passed: setting the clock back into period 4's or
	# period 5's window opens neither.
	var next := 4 * 720
	_send(_open_at(_dispatch, RANK_C_AT, next), PAIR, true, next)
	_dispatch.checkpoint(5 * 720 + 300)
	for at: int in [next, next + 100, 5 * 720, 5 * 720 + 100]:
		assert_eq(_open_at(_dispatch, RANK_C_AT, at), "", str(at))
	# Time going on still opens the next.
	assert_ne(_open_at(_dispatch, RANK_C_AT, 6 * 720), "")


func test_a_second_party_is_refused_while_one_is_out_on_an_elite() -> void:
	var opens := 3 * 720
	var elite := _open_at(_dispatch, RANK_C_AT, opens)
	_send(elite, PAIR, true, opens)
	var outings := _dispatch.outings.duplicate(true)
	assert_eq(_dispatch.party_refusal(elite, ["ilse"], opens + 1), "A party is out on it")
	assert_false(_dispatch.send(elite, ["ilse"], 1, opens + 1))
	assert_eq(_dispatch.outings, outings)
	# Another elite, or a board quest, still takes her.
	var another: String = Array(ELITES).filter(func(e: String) -> bool: return e != elite)[0]
	assert_eq(_dispatch.party_refusal(another, ["ilse"], opens + 1), "")
	assert_eq(_dispatch.party_refusal("rats", ["ilse"], opens + 1), "")


func test_each_elite_is_a_rank_c_150_s_quest_on_its_floor_paying_3_times_its_gold_and_twice_its_xp_with_every_challenge_known() -> void:
	var seen := []
	for elite: String in ELITES:
		var info: Dictionary = Dispatch.QUESTS[elite]
		seen.append([info["elite"], info["rank"], info["seconds"], info["gold"], info["xp"], info["difficulty"], info["challenges"]])
		assert_true(Dispatch.is_elite(elite), elite)
		assert_false(Dispatch.is_floor(elite), elite)
		assert_false(Dispatch.is_story(elite), elite)
		assert_eq(_dispatch.unknown_challenges(elite), PackedStringArray(), elite)
	assert_eq(seen, [
		["floor_1", "C", 150, 135, 64, 105, ["Traps", "Navigation", "Attrition"]],
		["floor_2", "C", 150, 180, 90, 105, ["Curse", "Navigation", "Attrition"]],
		["floor_3", "C", 150, 390, 170, 105, ["Brute force", "Traps", "Curse"]],
	])
	for quest: String in ["rats", "floor_1", "sealed_gate"]:
		assert_false(Dispatch.is_elite(quest), quest)
	# A floor's last challenge starts unknown; its elite's doesn't.
	assert_eq(_dispatch.unknown_challenges("floor_1"), PackedStringArray(["Attrition"]))


func test_a_successful_elite_pays_its_gold_xp_rank_c_reputation_loot_and_3_of_its_floors_material_and_explores_nothing() -> void:
	var gold := _dispatch.gold.amount
	var stash := _dispatch.adventurers.gear.stash.size()
	_send("elite_2", PAIR, true, 2_000)
	_dispatch.checkpoint(2_149)
	assert_eq(_dispatch.labyrinth.materials, {})
	_dispatch.checkpoint(2_150)
	assert_eq(_dispatch.gold.amount - gold, 180)
	# 90 XP shared by two.
	assert_eq([_dispatch.adventurers.xp["bram"], _dispatch.adventurers.xp["tobin"]], [45, 45])
	assert_eq(_dispatch.reputation, 4)
	assert_eq(_dispatch.adventurers.gear.stash.size() - stash, 1)
	assert_eq(_dispatch.tries["elite_2"], 1)
	assert_eq(_dispatch.labyrinth.materials, {"Riverglass": 3})
	assert_eq(_dispatch.labyrinth.explored, {})
	assert_eq(_dispatch.adventurers.successes["bram"].get("C", 0), 1)


func test_a_failed_elite_brings_no_gold_or_material_and_explores_nothing() -> void:
	_dispatch.reputation = 5
	var gold := _dispatch.gold.amount
	_send("elite_1", PAIR, false, 2_000)
	_dispatch.checkpoint(2_150)
	assert_eq(_dispatch.gold.amount - gold, 0)
	assert_eq(_dispatch.reputation, 4)
	assert_eq(_dispatch.labyrinth.materials, {})
	assert_eq(_dispatch.labyrinth.explored, {})
	assert_eq(_dispatch.tries["elite_1"], 1)


func test_on_a_failed_elite_a_member_brought_to_0_health_dies_gone_from_roster_and_party_gear_to_the_stash_and_recorded_in_fallen() -> void:
	# Tobin, far tougher, outlives what a failure deals; Bram, at 1 health, can't.
	_dispatch.adventurers.levels["tobin"] = 40
	_wound_to_1("bram", 2_000)
	var worn: Array = _dispatch.adventurers.gear.worn["bram"].values()
	assert_false(worn.is_empty())
	var party_id := _dispatch.adventurers.parties.party_of("bram")
	var outing := _send("elite_1", PAIR, false, 2_000)
	_dispatch.checkpoint(2_150)
	assert_false(_dispatch.adventurers.roster.has("bram"))
	assert_true(_dispatch.adventurers.roster.has("tobin"))
	assert_eq(_dispatch.adventurers.parties.party(party_id)["members"], PackedStringArray(["tobin"]))
	for item: String in worn:
		assert_true(item in _dispatch.adventurers.gear.stash, item)
	assert_eq(_dispatch.fallen, [{"name": "Bram", "quest": "elite_1", "at": 2_150}] as Array[Dictionary])
	assert_false(_dispatch.wounds.has("bram"))
	# Tobin comes home hurt but alive, as from any quest.
	var damage: Dictionary = Outcome.roll(outing["seed"], outing["chance"], Outcome.MOST_DAMAGE["C"], PAIR, outing["spirit"], outing["luck"]).damage
	assert_eq(_dispatch.health("tobin", 2_150), int(outing["health"]["tobin"]) - int(damage["tobin"]))
	assert_lt(_dispatch.health("tobin", 2_150), _dispatch.adventurers.max_health("tobin"))


func test_a_failed_elite_that_kills_a_whole_party_leaves_the_party_gone_and_gear_that_finds_the_stash_full_is_lost() -> void:
	_wound_to_1("ilse", 2_000)
	var party_id := _dispatch.adventurers.parties.party_of("ilse")
	var gear := _dispatch.adventurers.gear
	gear.worn["ilse"] = {"weapon": "oak_staff", "head": "pointed_hat"}
	gear.stash_cap = gear.stash.size() + 1
	var stash := gear.stash.size()
	_send("elite_3", ["ilse"], false, 2_000)
	_dispatch.checkpoint(2_150)
	assert_false(_dispatch.adventurers.roster.has("ilse"))
	assert_eq(_dispatch.adventurers.parties.party(party_id), {})
	assert_eq(_dispatch.adventurers.parties.parties.size(), 1)
	# One item fits, her head's, first in slot order; the rest are lost, and the loot waits for room.
	assert_eq(gear.stash.size() - stash, 1)
	assert_eq(gear.stash[-1], "pointed_hat")
	assert_eq(_dispatch.waiting_loot.size(), 1)
	assert_eq(_dispatch.fallen.size(), 1)
	assert_eq(_dispatch.fallen[0]["name"], "Ilse")
	# The rest of the guild goes on.
	assert_eq(_dispatch.adventurers.roster.keys(), ["bram", "tobin"])


func test_a_successful_elite_never_kills() -> void:
	_wound_to_1("bram", 2_000)
	# A seed with which the pair succeeds and Bram, at 1 health, still takes damage.
	var luck := _dispatch.party_stat(PAIR, "luck")
	var spirit := _dispatch.party_stat(PAIR, "spirit")
	var hurt_seed := -1
	for roll_seed: int in 10_000:
		var lucky: bool = Outcome.lucky_break(roll_seed, luck) and _dispatch.challenge_chances("elite_1", PAIR).min() < Outcome.EVEN_CHANCE
		var outcome := Outcome.roll(roll_seed, _dispatch.success_chance("elite_1", PAIR, lucky), Outcome.MOST_DAMAGE["C"], PAIR, spirit, luck)
		if outcome.success and int(outcome.damage["bram"]) >= 1:
			hurt_seed = roll_seed
			break
	assert_ne(hurt_seed, -1)
	assert_true(_dispatch.send("elite_1", PAIR, hurt_seed, 2_000))
	_dispatch.checkpoint(2_150)
	assert_eq(_dispatch.tries["elite_1"], 1)
	assert_eq(_dispatch.reputation, 4)
	assert_true(_dispatch.adventurers.roster.has("bram"))
	assert_eq(_dispatch.health("bram", 2_150), 1)
	assert_eq(_dispatch.fallen, [] as Array[Dictionary])


func test_no_other_quest_ever_kills_even_failed_with_1_health() -> void:
	var checked := 0
	for quest: String in Dispatch.QUESTS:
		if Dispatch.is_elite(quest):
			continue
		before_each()
		_wound_to_1("ilse", 2_000)
		_send(quest, ["ilse"], false, 2_000)
		_dispatch.checkpoint(2_000 + int(Dispatch.QUESTS[quest]["seconds"]))
		assert_true(_dispatch.adventurers.roster.has("ilse"), quest)
		assert_eq(_dispatch.health("ilse", 2_000 + int(Dispatch.QUESTS[quest]["seconds"])), 1, quest)
		assert_eq(_dispatch.fallen, [] as Array[Dictionary], quest)
		checked += 1
	assert_eq(checked, Dispatch.QUESTS.size() - 3)


func test_no_board_fill_draw_chance_or_auto_send_ever_picks_an_elite() -> void:
	for guild_rank: String in ["D", "C"]:
		for elite: String in ELITES:
			assert_eq(Board.draw_chance(elite, _dispatch.adventurers, guild_rank), 0.0, elite)
	# A rank D guild draws rank C board quests, and nothing else of rank C.
	assert_gt(Board.draw_chance("wyrm", _dispatch.adventurers, "D"), 0.0)
	var drawn := {}
	var board := Board.new()
	for at: int in range(1_000, 40_000, 15):
		board.refill(_dispatch, at, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "D")
		for quest: String in board.slots:
			drawn[quest] = true
	for elite: String in ELITES:
		assert_false(drawn.has(elite), elite)
	for quest: String in ["wyrm", "witch", "deeproad", "heirs", "lich", "giants"]:
		assert_true(drawn.has(quest), quest)
	# Strong enough that Auto takes rank C quests: still no elite.
	for adventurer: String in _dispatch.adventurers.roster:
		for stat: String in Adventurers.STATS:
			_dispatch.adventurers.stats[adventurer][stat] = 60
	var parties := _dispatch.adventurers.parties
	for party: Dictionary in parties.parties:
		parties.set_auto(party["id"], true)
		parties.set_mode(party["id"], Parties.BOLD)
	board = Board.new()
	Auto.checkpoint(_dispatch, board, 4_600, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "D")
	Auto.checkpoint(_dispatch, board, 4_600 + 36_000, PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), PackedInt64Array(), "D")
	var tried_c := 0
	for quest: String in ["wyrm", "witch", "deeproad", "heirs", "lich", "giants"]:
		tried_c += int(_dispatch.tries.get(quest, 0))
	assert_gt(tried_c, 0)
	for elite: String in ELITES:
		assert_false(_dispatch.tries.has(elite), elite)


func test_taken_windows_and_fallen_survive_save_and_load_and_an_older_save_has_none() -> void:
	var opens := 3 * 720
	var elite := _open_at(_dispatch, RANK_C_AT, opens)
	_dispatch.adventurers.levels["tobin"] = 40
	_wound_to_1("bram", opens)
	_send(elite, PAIR, false, opens)
	_dispatch.checkpoint(opens + 150)
	assert_eq(_dispatch.fallen.size(), 1)
	var file := ConfigFile.new()
	_dispatch.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Dispatch.load_or_start(SAVE_PATH, opens + 150)
	assert_eq(loaded.fallen, _dispatch.fallen)
	assert_eq(loaded.labyrinth.elite_taken, 3)
	assert_eq(_open_at(loaded, RANK_C_AT, opens + 200), "")
	# The same seed: later periods open the same elites.
	for period: int in range(4, 20):
		assert_eq(_open_at(loaded, RANK_C_AT, period * 720), _open_at(_dispatch, RANK_C_AT, period * 720), str(period))
	file.set_value("labyrinth", "elite_taken", null)
	file.set_value("dispatch", "fallen", null)
	assert_eq(file.save(SAVE_PATH), OK)
	var old := Dispatch.load_or_start(SAVE_PATH, opens + 150)
	assert_eq(old.fallen, [] as Array[Dictionary])
	assert_eq(old.labyrinth.elite_taken, -1)
	assert_eq(_open_at(old, RANK_C_AT, opens + 200), elite)
