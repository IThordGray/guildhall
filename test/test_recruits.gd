extends GutTest

const SAVE_PATH: String = "user://test_recruits_save.cfg"
## Unix seconds the candidates in these tests first arrive at.
const START: int = 1_000_000
## The stat each class grows in most.
const MAIN_STAT: Dictionary[String, String] = {"Swordsman": "might", "Mage": "mind", "Scout": "agility", "Healer": "mind", "Shield bearer": "grit"}


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## Candidates first filled at START for `adventurers`.
func _recruits(adventurers: Adventurers) -> Recruits:
	var recruits := Recruits.new()
	recruits.refill(adventurers, START)
	return recruits


func _names(adventurers: Adventurers) -> Array[String]:
	var names: Array[String] = []
	for who: Dictionary in adventurers.roster.values():
		names.append(who["name"])
	return names


## Hires from `slot` with plenty of gold and beds, at `at`.
func _hire(recruits: Recruits, slot: int, adventurers: Adventurers, at: int) -> void:
	assert_true(recruits.hire(slot, adventurers, Gold.new(1_000), Hall.MAX_ROSTER, at))


func test_a_new_guild_and_a_save_from_before_candidates_both_start_with_two_candidates() -> void:
	var recruits := _recruits(Adventurers.new())
	assert_eq(recruits.candidates.size(), 2)
	for candidate: Dictionary in recruits.candidates:
		assert_false(candidate.is_empty())
		assert_eq(candidate["who"]["rank"], "F")
		assert_has(Challenges.COVERS.keys(), candidate["who"]["class"])

	var file := ConfigFile.new()
	Gold.new(50).write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Recruits.load_or_start(SAVE_PATH)
	loaded.refill(Adventurers.new(), START)
	assert_eq(loaded.candidates, recruits.candidates)


func test_a_hire_costs_100_gold_adds_the_candidate_last_at_level_1_and_empties_the_slot() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	var hired := recruits.candidates[1]
	var gold := Gold.new(130)
	assert_true(recruits.hire(1, adventurers, gold, 6, START + 10))
	assert_eq(gold.amount, 30)
	var id: String = adventurers.roster.keys()[4]
	assert_eq(adventurers.roster[id]["name"], hired["who"]["name"])
	assert_eq(adventurers.roster[id]["class"], hired["who"]["class"])
	assert_eq(adventurers.levels[id], 1)
	assert_eq(adventurers.gear.worn[id], {})
	assert_true(recruits.candidates[1].is_empty())
	assert_false(recruits.candidates[0].is_empty())


func test_an_emptied_slot_refills_exactly_1800_seconds_after_the_hire_and_not_before() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START + 100)
	assert_eq(recruits.seconds_to_refill(0, START + 100), 1_800)
	recruits.refill(adventurers, START + 1_899)
	assert_true(recruits.candidates[0].is_empty())
	assert_eq(recruits.seconds_to_refill(0, START + 1_899), 1)
	recruits.refill(adventurers, START + 1_900)
	assert_false(recruits.candidates[0].is_empty())


func test_each_slot_counts_down_on_its_own() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START)
	_hire(recruits, 1, adventurers, START + 600)
	recruits.refill(adventurers, START + 1_800)
	assert_false(recruits.candidates[0].is_empty())
	assert_true(recruits.candidates[1].is_empty())
	assert_eq(recruits.seconds_to_refill(1, START + 1_800), 600)
	recruits.refill(adventurers, START + 2_400)
	assert_false(recruits.candidates[1].is_empty())


func test_one_refill_after_an_absence_gives_the_same_candidates_as_refilling_every_second() -> void:
	var watched_guild := Adventurers.new()
	var watched := _recruits(watched_guild)
	var away_guild := Adventurers.new()
	var away := _recruits(away_guild)
	# Hires at the same moments; the watched slots are refilled every second between them.
	for hire: Vector2i in [Vector2i(START + 5, 0), Vector2i(START + 700, 1), Vector2i(START + 2_000, 0)]:
		for at: int in range(watched.checked_at, hire.x):
			watched.refill(watched_guild, at)
		_hire(watched, hire.y, watched_guild, hire.x)
		_hire(away, hire.y, away_guild, hire.x)
	for at: int in range(watched.checked_at, START + 6_000):
		watched.refill(watched_guild, at)
	watched.refill(watched_guild, START + 6_000)
	away.refill(away_guild, START + 6_000)
	assert_eq(away.candidates, watched.candidates)
	assert_eq(away.refill_at, watched.refill_at)
	assert_eq(_names(away_guild), _names(watched_guild))
	assert_false(away.candidates[0].is_empty())
	assert_false(away.candidates[1].is_empty())


func test_a_clock_set_back_neither_undoes_a_refill_nor_restarts_a_countdown() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 0, adventurers, START)
	_hire(recruits, 1, adventurers, START + 1_000)
	recruits.refill(adventurers, START + 1_800)
	var refilled := recruits.candidates[0]
	assert_false(refilled.is_empty())

	recruits.refill(adventurers, START)
	assert_eq(recruits.candidates[0], refilled)
	assert_true(recruits.candidates[1].is_empty())
	assert_eq(recruits.seconds_to_refill(1, START), 1_000)
	recruits.refill(adventurers, START + 2_800)
	assert_false(recruits.candidates[1].is_empty())


func test_candidates_and_countdowns_survive_save_and_load() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	_hire(recruits, 1, adventurers, START + 50)
	var file := ConfigFile.new()
	recruits.write(file)
	adventurers.write(file)
	assert_eq(file.save(SAVE_PATH), OK)

	var loaded := Recruits.load_or_start(SAVE_PATH)
	var loaded_guild := Adventurers.load_or_start(SAVE_PATH)
	assert_eq(loaded.candidates, recruits.candidates)
	assert_eq(loaded.refill_at, recruits.refill_at)
	assert_eq(loaded.checked_at, START + 50)
	assert_eq(loaded.seconds_to_refill(1, START + 50), 1_800)
	loaded.refill(loaded_guild, START + 1_850)
	recruits.refill(adventurers, START + 1_850)
	assert_false(loaded.candidates[1].is_empty())
	assert_eq(loaded.candidates, recruits.candidates)


func test_the_same_slot_and_time_always_bring_the_same_candidate_whatever_the_global_generator() -> void:
	seed(1)
	var first := _recruits(Adventurers.new())
	seed(2)
	randi()
	var second := _recruits(Adventurers.new())
	assert_eq(second.candidates, first.candidates)
	var later := Recruits.new()
	later.refill(Adventurers.new(), START + 1)
	assert_ne(later.candidates, first.candidates)


func test_a_candidate_is_never_named_after_anyone_in_the_guild_or_the_other_candidate() -> void:
	var only_free := Recruits.NAMES[7]
	var taken := Recruits.NAMES.duplicate()
	taken.remove_at(7)
	for at: int in 20:
		assert_eq(Recruits.candidate_for(0, START + at, taken)["who"]["name"], only_free)

	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	# Hires fill the guild with recruits, each named apart from everyone already in it.
	for at: int in range(START, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS, Recruits.CANDIDATE_REFILL_SECONDS):
		recruits.refill(adventurers, at)
		assert_ne(recruits.candidates[0]["who"]["name"], recruits.candidates[1]["who"]["name"])
		for candidate: Dictionary in recruits.candidates:
			assert_does_not_have(_names(adventurers), candidate["who"]["name"])
		_hire(recruits, 0, adventurers, at)
	assert_eq(adventurers.roster.size(), 8)


func test_two_stats_show_before_a_hire_and_all_four_are_known_after() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	var candidate := recruits.candidates[0]
	var line := Recruits.stats_line(candidate)
	assert_eq(line.count("?"), 2, line)
	assert_eq(line.split(" · ").size(), 4, line)
	for stat: String in candidate["shown"]:
		assert_string_contains(line, "%s %d" % [Adventurers.STATS[stat], candidate["stats"][stat]])
	assert_eq(Array(candidate["shown"]).size(), 2)

	_hire(recruits, 0, adventurers, START)
	var id: String = adventurers.roster.keys()[4]
	for stat: String in Adventurers.STATS:
		assert_eq(adventurers.stat_total(id, stat), candidate["stats"][stat], stat)


func test_about_one_in_ten_candidates_is_a_late_bloomer_weaker_but_growing_far_faster_in_their_main_stat() -> void:
	var bloomers := 0
	var bloomer_stats := 0
	var other_stats := 0
	for at: int in 2_000:
		var candidate := Recruits.candidate_for(at % 2, START + at, PackedStringArray())
		var main := MAIN_STAT[candidate["who"]["class"]]
		var total := 0
		for stat: String in Adventurers.STATS:
			total += int(candidate["stats"][stat])
		if candidate["growth"][main] >= 0.9:
			bloomers += 1
			bloomer_stats += total
		else:
			assert_lt(float(candidate["growth"][main]), 0.7, candidate["who"]["class"])
			other_stats += total
	assert_between(bloomers, 140, 260)
	assert_lt(bloomer_stats / float(bloomers), other_stats / float(2_000 - bloomers) - 2.0)


func test_a_hire_is_refused_with_nothing_changed_when_gold_is_short_or_every_bed_is_taken() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	var before := recruits.candidates.duplicate(true)
	var short := Gold.new(99)
	assert_eq(Recruits.refusal(adventurers, short, 6), "Not enough gold")
	assert_false(recruits.hire(0, adventurers, short, 6, START))
	var full := Gold.new(500)
	assert_eq(Recruits.refusal(adventurers, full, 4), "No free bed — convert a Bunk room")
	assert_false(recruits.hire(0, adventurers, full, 4, START))
	assert_eq(short.amount, 99)
	assert_eq(full.amount, 500)
	assert_eq(adventurers.roster.size(), 4)
	assert_eq(recruits.candidates, before)
	# With the gold and a bed, the same hire goes through.
	assert_eq(Recruits.refusal(adventurers, Gold.new(100), 5), "")
	assert_true(recruits.hire(0, adventurers, full, 5, START))
	assert_eq(adventurers.roster.size(), 5)


func test_with_every_bed_taken_a_bunk_room_is_suggested_only_below_the_most_beds_there_can_be() -> void:
	var adventurers := Adventurers.new()
	var recruits := _recruits(adventurers)
	var gold := Gold.new(1_000)
	for at: int in range(START, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS, Recruits.CANDIDATE_REFILL_SECONDS):
		_hire(recruits, 0, adventurers, at)
	assert_eq(adventurers.roster.size(), 8)
	recruits.refill(adventurers, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS)
	assert_eq(Recruits.refusal(adventurers, gold, 8), "No free bed")
	assert_false(recruits.hire(0, adventurers, gold, 8, START + 4 * Recruits.CANDIDATE_REFILL_SECONDS))
	assert_eq(adventurers.roster.size(), 8)
	assert_eq(gold.amount, 1_000)
	assert_eq(Recruits.refusal(Adventurers.new(), gold, 4), "No free bed — convert a Bunk room")
	assert_eq(Recruits.refusal(Adventurers.new(), gold, 6), "")


func test_a_hired_shield_bearer_can_be_sent_on_a_quest_and_covers_protect() -> void:
	var dispatch := Dispatch.new(START)
	var recruits := Recruits.new()
	var at := START
	recruits.refill(dispatch.adventurers, at)
	while recruits.candidates[0]["who"]["class"] != "Shield bearer":
		at += 1
		recruits = Recruits.new()
		recruits.refill(dispatch.adventurers, at)
	assert_true(recruits.hire(0, dispatch.adventurers, Gold.new(100), 5, at))
	var id: String = dispatch.adventurers.roster.keys()[4]
	var party := PackedStringArray([id])
	assert_eq(Challenges.covered_by("Protect", party, dispatch.adventurers.roster), party)
	assert_eq(Challenges.covered_by("Protect", PackedStringArray(["bram", "ilse", "tobin", "maren"]), dispatch.adventurers.roster), PackedStringArray())
	assert_eq(dispatch.party_refusal("letters", party, at), "")
	assert_true(dispatch.send("letters", party, 7, Gold.new(0), at))
	assert_eq(dispatch.quest_of(id), "letters")
