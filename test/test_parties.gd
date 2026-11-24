extends GutTest

const SAVE_PATH: String = "user://test_parties_save.cfg"
const EVERYONE: Array[String] = ["bram", "ilse", "tobin", "maren"]
## Someone leaning Strength and Defence.
const WREN_STATS: Dictionary = {"strength": 4, "agility": 2, "perception": 2, "mind": 1, "spirit": 2, "defence": 8, "endurance": 3, "presence": 2, "luck": 1}


## A guild of all four starters, all in one party, at `at`.
func _guild(at: int) -> Dispatch:
	var dispatch := Dispatch.new(at)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	return dispatch


# Brings `id` into `dispatch`'s guild at `rank`, in the reserves.
func _add(dispatch: Dispatch, id: String, rank: String = "F") -> void:
	dispatch.adventurers.add(id, {"name": id.capitalize(), "rank": rank}, WREN_STATS, Adventurers.GROWTH["bram"])


# Each party's members, in the order the parties were made.
func _groups(parties: Parties) -> Array[PackedStringArray]:
	var groups: Array[PackedStringArray] = []
	for party: Dictionary in parties.parties:
		groups.append(party["members"].duplicate())
	return groups


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func test_a_new_game_starts_with_bram_and_tobin_together_in_one_party_and_nobody_in_reserve() -> void:
	var adventurers := Dispatch.new(1_000).adventurers
	assert_eq(_groups(adventurers.parties), [PackedStringArray(["bram", "tobin"])] as Array[PackedStringArray])
	assert_eq(adventurers.parties.reserves(adventurers.roster), PackedStringArray())


func test_a_party_has_an_id_a_name_and_its_members_and_an_adventurer_is_in_at_most_one() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	var first: String = parties.parties[0]["id"]
	assert_false(first.is_empty())
	assert_string_starts_with(parties.parties[0]["name"], "The ")
	assert_true(parties.move("ilse", Parties.NEW_PARTY, dispatch))
	var second := parties.party_of("ilse")
	assert_ne(second, first)
	assert_eq(_groups(parties), [PackedStringArray(["bram", "tobin", "maren"]), PackedStringArray(["ilse"])] as Array[PackedStringArray])
	# Moving back takes her out of the second, which goes with her.
	assert_true(parties.move("ilse", first, dispatch))
	assert_eq(parties.party_of("ilse"), first)
	assert_eq(_groups(parties), [PackedStringArray(["bram", "tobin", "maren", "ilse"])] as Array[PackedStringArray])


func test_anyone_in_no_party_is_a_reserve_listed_in_roster_order() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	assert_eq(parties.reserves(dispatch.adventurers.roster), PackedStringArray())
	assert_true(parties.move("tobin", Parties.RESERVES, dispatch))
	assert_true(parties.move("ilse", Parties.RESERVES, dispatch))
	assert_eq(parties.party_of("tobin"), Parties.RESERVES)
	assert_eq(parties.reserves(dispatch.adventurers.roster), PackedStringArray(["ilse", "tobin"]))
	assert_eq(_groups(parties), [PackedStringArray(["bram", "maren"])] as Array[PackedStringArray])
	# And back from the reserves into a party.
	assert_true(parties.move("tobin", parties.party_of("bram"), dispatch))
	assert_eq(parties.reserves(dispatch.adventurers.roster), PackedStringArray(["ilse"]))


func test_a_move_is_refused_with_nothing_changed_unless_the_mover_and_both_parties_are_home() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	var first := parties.party_of("bram")
	assert_true(parties.move("maren", Parties.NEW_PARTY, dispatch))
	var second := parties.party_of("maren")
	assert_true(parties.move("ilse", Parties.RESERVES, dispatch))
	assert_true(dispatch.send("rats", PackedStringArray(["bram"]), 1, 1_000))
	var before := _groups(parties)
	# Out themselves: no move at all.
	for to: String in [second, Parties.RESERVES, Parties.NEW_PARTY]:
		assert_eq(parties.move_refusal("bram", to, dispatch), "Out on a quest")
		assert_false(parties.move("bram", to, dispatch))
	# Tobin is home, but Bram, in the party he would leave, is out.
	for to: String in [second, Parties.RESERVES, Parties.NEW_PARTY]:
		assert_eq(parties.move_refusal("tobin", to, dispatch), "Bram is out on a quest")
		assert_false(parties.move("tobin", to, dispatch))
	# Ilse and Maren are home, but Bram, in the party they would join, is out.
	assert_eq(parties.move_refusal("ilse", first, dispatch), "Bram is out on a quest")
	assert_false(parties.move("ilse", first, dispatch))
	assert_false(parties.move("maren", first, dispatch))
	assert_eq(_groups(parties), before)
	assert_eq(parties.reserves(dispatch.adventurers.roster), PackedStringArray(["ilse"]))
	# Moves not touching Bram's party still go.
	assert_eq(parties.move_refusal("ilse", second, dispatch), "")
	assert_true(parties.move("ilse", second, dispatch))
	# Once Bram is back, his party can change again.
	dispatch.checkpoint(1_000 + int(Dispatch.QUESTS["rats"]["seconds"]))
	assert_true(parties.move("tobin", Parties.RESERVES, dispatch))


func test_moving_into_a_full_party_of_four_is_refused_with_nothing_changed() -> void:
	var dispatch := _guild(1_000)
	_add(dispatch, "wren")
	var parties := dispatch.adventurers.parties
	var full := parties.party_of("bram")
	assert_ne(parties.party_of("wren"), full)
	var before := _groups(parties)
	assert_eq(parties.move_refusal("wren", full, dispatch), "Party full")
	assert_false(parties.move("wren", full, dispatch))
	assert_eq(_groups(parties), before)
	# With a place free, she fits.
	assert_true(parties.move("maren", Parties.RESERVES, dispatch))
	assert_true(parties.move("wren", full, dispatch))
	assert_eq(parties.party(full)["members"], PackedStringArray(["bram", "ilse", "tobin", "wren"]))


func test_moving_to_where_they_already_are_is_refused() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	assert_eq(parties.move_refusal("bram", parties.party_of("bram"), dispatch), "Already there")
	assert_true(parties.move("bram", Parties.RESERVES, dispatch))
	assert_eq(parties.move_refusal("bram", Parties.RESERVES, dispatch), "Already there")


func test_a_party_whose_last_member_leaves_disappears() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, dispatch))
	var hers := parties.party_of("ilse")
	assert_eq(parties.parties.size(), 2)
	assert_true(parties.move("ilse", Parties.RESERVES, dispatch))
	assert_eq(parties.parties.size(), 1)
	assert_true(parties.party(hers).is_empty())
	# A party with someone left in it stays.
	assert_true(parties.move("bram", Parties.RESERVES, dispatch))
	assert_eq(_groups(parties), [PackedStringArray(["tobin", "maren"])] as Array[PackedStringArray])


func test_a_party_whose_last_member_is_dismissed_disappears_and_one_with_others_left_keeps_them() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, dispatch))
	assert_true(dispatch.dismiss("ilse"))
	assert_eq(_groups(parties), [PackedStringArray(["bram", "tobin", "maren"])] as Array[PackedStringArray])
	assert_true(dispatch.dismiss("tobin"))
	assert_eq(_groups(parties), [PackedStringArray(["bram", "maren"])] as Array[PackedStringArray])


func test_someone_swapped_out_for_a_walk_in_leaves_their_party_and_the_walk_in_joins_the_reserves() -> void:
	var dispatch := Dispatch.new(1_000_000)
	var recruits := Recruits.new()
	recruits.refill(dispatch.adventurers, 1_000_000)
	var walk_ins := WalkIns.new()
	walk_ins.refill(dispatch.adventurers, recruits, 1_000_000)
	walk_ins.refill(dispatch.adventurers, recruits, walk_ins.next_at)
	var id := "walk_in_%d" % walk_ins.arrived_at
	assert_true(walk_ins.swap("bram", dispatch, 2))
	var parties := dispatch.adventurers.parties
	assert_eq(_groups(parties), [PackedStringArray(["tobin"])] as Array[PackedStringArray])
	assert_eq(parties.reserves(dispatch.adventurers.roster), PackedStringArray([id]))


func test_a_partys_rank_is_its_members_ranks_averaged_and_rounded_down() -> void:
	var dispatch := Dispatch.new(1_000)
	dispatch.adventurers = Adventurers.new(PackedStringArray())
	_add(dispatch, "cara", "C")
	_add(dispatch, "edda", "E")
	_add(dispatch, "finn", "F")
	for adventurer: String in ["cara", "edda", "finn"]:
		dispatch.adventurers.parties.place(adventurer)
	var parties := dispatch.adventurers.parties
	var roster := dispatch.adventurers.roster
	var party := parties.party_of("cara")
	# C + E + F: (3 + 1 + 0) ÷ 3 is 1⅓, so E.
	assert_eq(parties.rank(party, roster), "E")
	# E + F: ½, rounded down to F, not up to E.
	assert_true(parties.move("cara", Parties.RESERVES, dispatch))
	assert_eq(parties.rank(party, roster), "F")
	# C alone is C; C + E is D.
	assert_true(parties.move("cara", Parties.NEW_PARTY, dispatch))
	var hers := parties.party_of("cara")
	assert_eq(parties.rank(hers, roster), "C")
	assert_true(parties.move("edda", hers, dispatch))
	assert_eq(parties.rank(hers, roster), "D")


func test_a_new_hire_and_an_accepted_walk_in_join_the_reserves() -> void:
	var dispatch := Dispatch.new(1_000_000)
	var adventurers := dispatch.adventurers
	var recruits := Recruits.new()
	recruits.refill(adventurers, 1_000_000)
	assert_true(recruits.hire(0, adventurers, Gold.new(1_000), 10, 1_000_000))
	var hired: String = adventurers.roster.keys()[2]
	assert_eq(adventurers.parties.party_of(hired), Parties.RESERVES)
	var walk_ins := WalkIns.new()
	walk_ins.refill(adventurers, recruits, 1_000_000)
	walk_ins.refill(adventurers, recruits, walk_ins.next_at)
	assert_true(walk_ins.accept(adventurers, 10))
	var accepted: String = adventurers.roster.keys()[3]
	assert_eq(adventurers.parties.reserves(adventurers.roster), PackedStringArray([hired, accepted]))
	# The starters' party is as it was.
	assert_eq(_groups(adventurers.parties), [PackedStringArray(["bram", "tobin"])] as Array[PackedStringArray])


func test_a_save_from_before_parties_puts_everyone_into_parties_of_up_to_four_in_roster_order() -> void:
	var dispatch := _guild(1_000)
	_add(dispatch, "wren")
	_add(dispatch, "joss")
	var file := ConfigFile.new()
	dispatch.write(file)
	file.erase_section("parties")
	file.save(SAVE_PATH)
	var loaded := Adventurers.load_or_start(SAVE_PATH).parties
	assert_eq(_groups(loaded), [PackedStringArray(["bram", "ilse", "tobin", "maren"]), PackedStringArray(["wren", "joss"])] as Array[PackedStringArray])
	for party: Dictionary in loaded.parties:
		assert_eq(party["name"], Parties.name_of(party["seed"]))
	assert_ne(loaded.parties[0]["id"], loaded.parties[1]["id"])


func test_todays_four_from_a_save_before_parties_play_as_one_party() -> void:
	var file := ConfigFile.new()
	_guild(1_000).write(file)
	file.erase_section("parties")
	file.save(SAVE_PATH)
	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_000)
	assert_eq(_groups(loaded.adventurers.parties), [PackedStringArray(EVERYONE)] as Array[PackedStringArray])
	assert_eq(loaded.party_refusal("letters", PackedStringArray(EVERYONE), 1_000), "")


func test_parties_their_names_and_who_is_in_reserve_survive_save_and_load() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	assert_true(parties.move("ilse", Parties.NEW_PARTY, dispatch))
	assert_true(parties.move("tobin", Parties.RESERVES, dispatch))
	parties.rename(parties.party_of("ilse"), "Ilse's Lot")
	parties.reroll(parties.party_of("bram"))
	var file := ConfigFile.new()
	dispatch.write(file)
	file.save(SAVE_PATH)
	var loaded := Dispatch.load_or_start(SAVE_PATH, 1_000).adventurers
	assert_eq(loaded.parties.parties, parties.parties)
	assert_eq(loaded.parties.party(loaded.parties.party_of("ilse"))["name"], "Ilse's Lot")
	assert_eq(loaded.parties.reserves(loaded.roster), PackedStringArray(["tobin"]))
	# The next new party still gets an id never used.
	assert_true(loaded.parties.move("maren", Parties.NEW_PARTY, Dispatch.load_or_start(SAVE_PATH, 1_000)))
	var ids := PackedStringArray()
	for party: Dictionary in loaded.parties.parties:
		assert_does_not_have(ids, party["id"])
		ids.append(party["id"])


func test_a_reserve_cant_go_on_a_quest_not_in_a_party_and_can_once_back_in_one() -> void:
	var dispatch := _guild(1_000)
	var parties := dispatch.adventurers.parties
	assert_true(parties.move("tobin", Parties.RESERVES, dispatch))
	assert_eq(dispatch.party_refusal("letters", PackedStringArray(["tobin"]), 1_000), "Not in a party")
	assert_eq(dispatch.party_refusal("letters", PackedStringArray(["bram", "tobin"]), 1_000), "Not in a party")
	assert_false(dispatch.send("letters", PackedStringArray(["bram", "tobin"]), 1, 1_000))
	assert_true(dispatch.outings.is_empty())
	# Bram, in a party, still goes.
	assert_eq(dispatch.party_refusal("letters", PackedStringArray(["bram"]), 1_000), "")
	assert_true(parties.move("tobin", Parties.NEW_PARTY, dispatch))
	assert_true(dispatch.send("letters", PackedStringArray(["tobin"]), 1, 1_000))


func test_a_reserve_still_trains_changes_gear_levels_up_is_promoted_and_can_be_dismissed() -> void:
	var dispatch := _guild(1_000)
	var adventurers := dispatch.adventurers
	assert_true(adventurers.parties.move("tobin", Parties.RESERVES, dispatch))
	assert_true(adventurers.parties.move("ilse", Parties.RESERVES, dispatch))
	assert_true(dispatch.train("tobin", 1, 1_000))
	assert_eq(dispatch.stop_training("tobin", 1_060), 10)
	assert_true(dispatch.take_off("tobin", "head"))
	assert_true(dispatch.wear("tobin", 0))
	assert_eq(adventurers.gear.worn["tobin"]["head"], "scouts_hood")
	adventurers.gain_xp("tobin", 100)
	assert_false(adventurers.level_up("tobin").is_empty())
	assert_false(adventurers.level_up("tobin").is_empty())
	assert_eq(adventurers.levels["tobin"], 3)
	assert_true(adventurers.promote("tobin", Gold.new(1_000), false))
	assert_eq(adventurers.roster["tobin"]["rank"], "E")
	assert_true(dispatch.dismiss("ilse"))
	assert_false(adventurers.roster.has("ilse"))


func test_a_partys_first_name_is_the_adjective_and_noun_its_saved_seed_draws() -> void:
	var parties := Adventurers.new(EVERYONE).parties
	var party := parties.parties[0]
	assert_eq(party["name"], Parties.name_of(party["seed"]))
	var words: PackedStringArray = Parties.name_of(party["seed"]).split(" ")
	assert_eq(words.size(), 3)
	assert_eq(words[0], "The")
	assert_has(Parties.ADJECTIVES, words[1])
	assert_has(Parties.NOUNS, words[2])
	# One seed always draws one name, and seeds draw names from across both lists.
	var drawn := {}
	for name_seed: int in 400:
		assert_eq(Parties.name_of(name_seed), Parties.name_of(name_seed))
		drawn[Parties.name_of(name_seed)] = true
	assert_gt(drawn.size(), 150)


func test_each_word_list_holds_about_twenty_different_words() -> void:
	for words: PackedStringArray in [Parties.ADJECTIVES, Parties.NOUNS]:
		assert_between(words.size(), 18, 22)
		var unique := {}
		for word: String in words:
			unique[word] = true
		assert_eq(unique.size(), words.size())


func test_the_dice_rolls_a_new_drawn_name_never_the_one_it_had_replacing_a_typed_one() -> void:
	var parties := Adventurers.new(EVERYONE).parties
	var id: String = parties.parties[0]["id"]
	for roll: int in 50:
		var before: String = parties.party(id)["name"]
		parties.reroll(id)
		var after: String = parties.party(id)["name"]
		assert_ne(after, before)
		assert_eq(after, Parties.name_of(parties.party(id)["seed"]))
	parties.rename(id, "Bram's Lot")
	parties.reroll(id)
	assert_ne(parties.party(id)["name"], "Bram's Lot")
	assert_eq(parties.party(id)["name"], Parties.name_of(parties.party(id)["seed"]))


func test_a_typed_name_replaces_the_partys_name_without_the_spaces_around_it() -> void:
	var parties := Adventurers.new(EVERYONE).parties
	var id: String = parties.parties[0]["id"]
	parties.rename(id, "  Bram's Lot ")
	assert_eq(parties.party(id)["name"], "Bram's Lot")
	parties.rename(id, "The Night Shift")
	assert_eq(parties.party(id)["name"], "The Night Shift")


func test_an_empty_or_blank_typed_name_keeps_the_name_the_party_had() -> void:
	var parties := Adventurers.new(EVERYONE).parties
	var id: String = parties.parties[0]["id"]
	parties.rename(id, "Bram's Lot")
	for blank: String in ["", "   ", "\t \n"]:
		parties.rename(id, blank)
		assert_eq(parties.party(id)["name"], "Bram's Lot")


func test_a_typed_name_keeps_at_most_twenty_four_characters() -> void:
	var parties := Adventurers.new(EVERYONE).parties
	var id: String = parties.parties[0]["id"]
	parties.rename(id, "The Extremely Long Party Name Indeed")
	assert_eq(parties.party(id)["name"], "The Extremely Long Party")
	parties.rename(id, "ABCDEFGHIJKLMNOPQRSTUVWX")
	assert_eq(parties.party(id)["name"], "ABCDEFGHIJKLMNOPQRSTUVWX")
