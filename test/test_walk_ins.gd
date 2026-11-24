extends GutTest

const Fixtures := preload("res://test/fixtures.gd")

const SAVE_PATH: String = "user://test_walk_ins_save.cfg"
## Unix seconds the guild in these tests starts at.
const START: int = 1_000_000

var _dispatch: Dispatch
var _recruits: Recruits


func before_each() -> void:
	_dispatch = Dispatch.new(START)
	_recruits = Recruits.new()
	_recruits.refill(_dispatch.adventurers, START)


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## Walk-ins first refilled at START, as a new game's are.
func _walk_ins() -> WalkIns:
	var walk_ins := WalkIns.new()
	walk_ins.refill(_dispatch.adventurers, _recruits, START)
	return walk_ins


## Walk-ins whose first walk-in has just arrived and waits.
func _waiting() -> WalkIns:
	var walk_ins := _walk_ins()
	walk_ins.refill(_dispatch.adventurers, _recruits, walk_ins.next_at)
	assert_false(walk_ins.walk_in.is_empty())
	return walk_ins


func test_a_new_games_first_walk_in_arrives_one_gap_after_it_starts_and_nobody_before() -> void:
	var walk_ins := _walk_ins()
	assert_true(walk_ins.walk_in.is_empty())
	assert_between(walk_ins.next_at - START, 180, 420)
	var due := walk_ins.next_at
	walk_ins.refill(_dispatch.adventurers, _recruits, due - 1)
	assert_true(walk_ins.walk_in.is_empty())
	walk_ins.refill(_dispatch.adventurers, _recruits, due)
	assert_false(walk_ins.walk_in.is_empty())
	assert_eq(walk_ins.arrived_at, due)


func test_every_later_walk_in_arrives_20_to_28_hours_after_the_one_before_about_a_day_on_average() -> void:
	var walk_ins := _waiting()
	var gaps: Array[int] = []
	var last := walk_ins.arrived_at
	for arrival: int in 300:
		walk_ins.refill(_dispatch.adventurers, _recruits, walk_ins.next_at)
		gaps.append(walk_ins.arrived_at - last)
		last = walk_ins.arrived_at
	var total := 0
	for gap: int in gaps:
		assert_between(gap, 20 * 3600, 28 * 3600)
		total += gap
	assert_between(total / float(gaps.size()), 23.0 * 3600, 25.0 * 3600)
	# Random, not one fixed gap: some come within 21 hours and some after 27.
	assert_true(gaps.any(func(gap: int) -> bool: return gap < 21 * 3600))
	assert_true(gaps.any(func(gap: int) -> bool: return gap > 27 * 3600))


func test_one_refill_after_an_absence_gives_the_same_walk_in_as_refilling_every_second() -> void:
	var watched := _walk_ins()
	var away := _walk_ins()
	var arrivals := 0
	# Four days: the first walk-in and the daily ones after.
	var back := START + 4 * 86_400
	for second: int in range(START + 1, back + 1):
		var before := watched.arrived_at
		watched.refill(_dispatch.adventurers, _recruits, second)
		if watched.arrived_at != before:
			arrivals += 1
	away.refill(_dispatch.adventurers, _recruits, back)
	# Several came and went while away.
	assert_gt(arrivals, 3)
	assert_eq(away.walk_in, watched.walk_in)
	assert_eq(away.arrived_at, watched.arrived_at)
	assert_eq(away.next_at, watched.next_at)


func test_a_walk_in_waits_until_the_next_arrives_and_is_then_replaced_by_them() -> void:
	var walk_ins := _waiting()
	var first := walk_ins.walk_in.duplicate(true)
	var next := walk_ins.next_at
	walk_ins.refill(_dispatch.adventurers, _recruits, next - 1)
	assert_eq(walk_ins.walk_in, first)
	walk_ins.refill(_dispatch.adventurers, _recruits, next)
	assert_false(walk_ins.walk_in.is_empty())
	assert_ne(walk_ins.walk_in, first)
	assert_eq(walk_ins.arrived_at, next)


func test_turning_a_walk_in_away_removes_them_at_once_and_the_next_still_comes_at_its_own_time() -> void:
	var walk_ins := _waiting()
	var next := walk_ins.next_at
	walk_ins.turn_away()
	assert_true(walk_ins.walk_in.is_empty())
	walk_ins.refill(_dispatch.adventurers, _recruits, next - 1)
	assert_true(walk_ins.walk_in.is_empty())
	assert_eq(walk_ins.next_at, next)
	walk_ins.refill(_dispatch.adventurers, _recruits, next)
	assert_false(walk_ins.walk_in.is_empty())


func test_a_clock_set_back_never_undoes_an_arrival() -> void:
	var walk_ins := _waiting()
	var waiting := walk_ins.walk_in.duplicate(true)
	var next := walk_ins.next_at
	walk_ins.refill(_dispatch.adventurers, _recruits, START)
	assert_eq(walk_ins.walk_in, waiting)
	assert_eq(walk_ins.next_at, next)


func test_every_walk_in_is_rank_f_wears_a_standard_weapon_and_arrives_at_level_1_to_3_mostly_1() -> void:
	var levels := {1: 0, 2: 0, 3: 0}
	for arrival: int in 400:
		var at := START + arrival * 300
		var walk_in := WalkIns.walk_in_for(at, PackedStringArray())
		assert_eq(walk_in["who"]["rank"], "F")
		var weapon: String = walk_in["worn"].get("weapon", "")
		assert_ne(weapon, "")
		if weapon != "":
			assert_eq(Gear.ITEMS[weapon]["quality"], "Standard")
		var level: int = walk_in["level"]
		assert_has(levels, level)
		levels[level] = levels.get(level, 0) + 1
		# A level 2 or 3 walk-in is who they would be at level 1, grown by a level-up's gains a level.
		var at_level_1 := Recruits.candidate_for(WalkIns.SLOT, at, PackedStringArray())
		var grown := 0
		for stat: String in Adventurers.STATS:
			assert_true(walk_in["stats"][stat] >= at_level_1["stats"][stat])
			grown += walk_in["stats"][stat] - at_level_1["stats"][stat]
		if level == 1:
			assert_eq(grown, 0)
		else:
			assert_gt(grown, 0)
	assert_gt(levels[1], 200)
	# Now and then someone stronger.
	assert_gt(levels[2], 0)
	assert_gt(levels[3], 0)
	assert_gt(levels[2], levels[3])


func test_a_walk_in_is_never_named_after_anyone_in_the_guild_or_a_candidate() -> void:
	var walk_ins := _walk_ins()
	_dispatch.adventurers.roster["bram"]["name"] = "Aldric"
	var names_seen := {}
	for arrival: int in 200:
		walk_ins.refill(_dispatch.adventurers, _recruits, walk_ins.next_at)
		var name: String = walk_ins.walk_in["who"]["name"]
		names_seen[name] = true
		assert_ne(name, "Aldric")
		assert_ne(name, "Tobin")
		assert_ne(name, _recruits.candidates[0]["who"]["name"])
	# Names do vary, so the ones never seen are kept out, not missed by chance.
	assert_gt(names_seen.size(), 20)


func test_a_candidate_is_never_named_after_the_walk_in_waiting() -> void:
	var walk_ins := _waiting()
	var waiting := walk_ins.waiting_name()
	var adventurers := _dispatch.adventurers
	var gold := Gold.new(1_000_000)
	var names_seen := {}
	var now := walk_ins.arrived_at
	# Hire after hire, each slot refilling with a new candidate while the walk-in waits.
	for hire: int in 200:
		_recruits.refill(adventurers, now, PackedInt64Array(), waiting)
		var name: String = _recruits.candidates[0]["who"]["name"]
		names_seen[name] = true
		assert_ne(name, waiting)
		assert_true(_recruits.hire(0, adventurers, gold, 1_000, now, PackedInt64Array(), waiting))
		adventurers.roster.erase(adventurers.roster.keys()[-1])
		now += Recruits.CANDIDATE_REFILL_SECONDS
	# Names do vary, so the walk-in's is kept out, not missed by chance.
	assert_gt(names_seen.size(), 20)
	# Without a walk-in waiting, their name comes up.
	var drawn := {}
	for slot: int in 300:
		drawn[Recruits.candidate_for(slot, START, PackedStringArray())["who"]["name"]] = true
	assert_has(drawn, waiting)


# Free: accepting takes no gold at all.
func test_accepting_a_walk_in_is_free_and_brings_them_in_at_their_level_in_their_weapon() -> void:
	var walk_ins := _waiting()
	var walk_in := walk_ins.walk_in.duplicate(true)
	var id := "walk_in_%d" % walk_ins.arrived_at
	assert_true(walk_ins.accept(_dispatch.adventurers, 3))
	var adventurers := _dispatch.adventurers
	assert_eq(adventurers.roster.keys(), ["bram", "tobin", id])
	assert_eq(adventurers.roster[id]["name"], walk_in["who"]["name"])
	assert_eq(adventurers.levels[id], walk_in["level"])
	assert_eq(adventurers.stats[id], walk_in["stats"])
	assert_eq(adventurers.gear.worn[id], walk_in["worn"])
	assert_eq(adventurers.xp[id], 0)
	assert_true(walk_ins.walk_in.is_empty())


func test_accepting_is_refused_with_nothing_changed_while_every_bed_is_taken() -> void:
	var walk_ins := _waiting()
	var walk_in := walk_ins.walk_in.duplicate(true)
	assert_false(walk_ins.accept(_dispatch.adventurers, 2))
	assert_eq(_dispatch.adventurers.roster.keys(), ["bram", "tobin"])
	assert_eq(walk_ins.walk_in, walk_in)
	assert_eq(Recruits.bed_refusal(_dispatch.adventurers, 2), "No free bed")
	assert_true(walk_ins.accept(_dispatch.adventurers, 3))


func test_a_swap_dismisses_the_chosen_one_and_brings_the_walk_in_into_their_bed() -> void:
	var walk_ins := _waiting()
	var id := "walk_in_%d" % walk_ins.arrived_at
	assert_true(walk_ins.swap("bram", _dispatch, 2))
	var adventurers := _dispatch.adventurers
	assert_eq(adventurers.roster.keys(), ["tobin", id])
	assert_false(adventurers.stats.has("bram"))
	# Bram's gear stays with the guild.
	assert_has(adventurers.gear.stash, "short_sword")
	assert_true(walk_ins.walk_in.is_empty())


func test_a_swap_is_refused_with_nothing_changed_when_the_chosen_one_cannot_be_dismissed() -> void:
	var walk_ins := _waiting()
	var walk_in := walk_ins.walk_in.duplicate(true)
	var at := walk_ins.arrived_at
	assert_true(_dispatch.send("rats", Fixtures.party(_dispatch, PackedStringArray(["bram"])), 1, at))
	assert_false(walk_ins.swap("bram", _dispatch, 2))
	assert_eq(_dispatch.adventurers.roster.keys(), ["bram", "tobin"])
	assert_eq(_dispatch.adventurers.gear.worn["bram"], Gear.STARTER_GEAR["bram"])
	assert_eq(walk_ins.walk_in, walk_in)
	# Tobin, at home, can go in Bram's stead.
	assert_true(walk_ins.swap("tobin", _dispatch, 2))
	assert_eq(_dispatch.adventurers.roster.size(), 2)
	assert_false(_dispatch.adventurers.roster.has("tobin"))


func test_the_walk_in_and_when_they_and_the_next_arrive_survive_save_and_load() -> void:
	var walk_ins := _waiting()
	var file := ConfigFile.new()
	walk_ins.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := WalkIns.load_or_start(SAVE_PATH)
	assert_eq(loaded.walk_in, walk_ins.walk_in)
	assert_eq(loaded.arrived_at, walk_ins.arrived_at)
	assert_eq(loaded.next_at, walk_ins.next_at)
	# The next arrives when it would have without the reload.
	var next := walk_ins.next_at
	walk_ins.refill(_dispatch.adventurers, _recruits, next)
	loaded.refill(_dispatch.adventurers, _recruits, next)
	assert_eq(loaded.walk_in, walk_ins.walk_in)
	# Once accepted, they join as the walk-in they were.
	assert_true(loaded.accept(_dispatch.adventurers, 3))
	assert_eq(_dispatch.adventurers.roster.size(), 3)


func test_a_save_from_before_walk_ins_loads_with_nobody_waiting_and_nothing_lost_the_first_one_gap_after_it_loads() -> void:
	var file := ConfigFile.new()
	_dispatch.write(file)
	_recruits.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded_at := START + 50_000
	var loaded_dispatch := Dispatch.load_or_start(SAVE_PATH, loaded_at)
	var loaded_recruits := Recruits.load_or_start(SAVE_PATH)
	var walk_ins := WalkIns.load_or_start(SAVE_PATH)
	assert_true(walk_ins.walk_in.is_empty())
	walk_ins.refill(loaded_dispatch.adventurers, loaded_recruits, loaded_at)
	assert_true(walk_ins.walk_in.is_empty())
	assert_between(walk_ins.next_at - loaded_at, 180, 420)
	assert_eq(loaded_dispatch.adventurers.roster, _dispatch.adventurers.roster)
	assert_eq(loaded_dispatch.adventurers.gear.worn, _dispatch.adventurers.gear.worn)
	assert_eq(loaded_recruits.candidates, _recruits.candidates)
	walk_ins.refill(loaded_dispatch.adventurers, loaded_recruits, walk_ins.next_at)
	assert_false(walk_ins.walk_in.is_empty())


func test_a_save_from_before_daily_walk_ins_keeps_its_next_arrival_and_every_one_after_it_is_daily() -> void:
	# The build before saved the next arrival a few minutes after the last.
	var file := ConfigFile.new()
	file.set_value("walk_ins", "walk_in", {})
	file.set_value("walk_ins", "arrived_at", START)
	file.set_value("walk_ins", "next_at", START + 300)
	file.set_value("walk_ins", "checked_at", START + 10)
	assert_eq(file.save(SAVE_PATH), OK)
	var walk_ins := WalkIns.load_or_start(SAVE_PATH)
	walk_ins.refill(_dispatch.adventurers, _recruits, START + 299)
	assert_true(walk_ins.walk_in.is_empty())
	assert_eq(walk_ins.next_at, START + 300)
	walk_ins.refill(_dispatch.adventurers, _recruits, START + 300)
	assert_false(walk_ins.walk_in.is_empty())
	assert_eq(walk_ins.arrived_at, START + 300)
	for arrival: int in 20:
		var last := walk_ins.arrived_at
		assert_between(walk_ins.next_at - last, 20 * 3600, 28 * 3600)
		walk_ins.refill(_dispatch.adventurers, _recruits, walk_ins.next_at)
		assert_ne(walk_ins.arrived_at, last)
