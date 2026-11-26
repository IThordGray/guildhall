extends GutTest

const SAVE_PATH: String = "user://test_chapter_2_save.cfg"
const PAIR: PackedStringArray = ["bram", "tobin"]
const EVERYONE: PackedStringArray = ["bram", "ilse", "tobin", "maren"]
const KITCHEN: PackedStringArray = ["kitchen"]
const NONE: PackedInt64Array = []
## Chapter 1's story goals, all claimed by the time Rank up to E is.
const CHAPTER_1: Array[String] = ["first_quest", "first_restore", "first_room", "first_recruit", "second_party", "sealed_gate", "first_expedition"]

var _dispatch: Dispatch
var _goals: Goals
var _hall: Hall


func before_each() -> void:
	# A new game's Bram and Tobin, rich enough for anything, with chapter 1 claimed but Rank up to E.
	_dispatch = Dispatch.new(1_000)
	_dispatch.gold = Gold.new(1_000)
	_hall = Hall.new(1_000)
	_goals = Goals.new()
	_goals.claimed.append_array(CHAPTER_1)


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


func _state(id: String) -> Goals.State:
	return _goals.state(id, _dispatch, _hall, _dispatch.story_done, 1_000)


func _claim(id: String) -> bool:
	return _goals.claim(id, _dispatch, _hall, _dispatch.story_done, 1_000)


func _story_row() -> PackedStringArray:
	return _dispatch.open_story_quests(_goals.unlocked)


func test_the_cooks_debt_and_the_lost_survey_are_rank_e_story_quests_the_board_never_draws_and_the_four_starters_have_fair_odds_on() -> void:
	var guild := Dispatch.new(1_000)
	guild.adventurers = Adventurers.new(EVERYONE)
	var expected := {
		"cooks_debt": ["The cook's debt", "E", 20, 60, 40, 4],
		"lost_survey": ["The lost survey", "E", 30, 80, 55, 5],
	}
	for quest: String in expected:
		var info: Dictionary = Dispatch.QUESTS[quest]
		assert_eq([info["name"], info["rank"], info["seconds"], info["gold"], info["xp"], info["reputation"]], expected[quest], quest)
		assert_true(Dispatch.is_story(quest), quest)
		assert_eq(Board.draw_chance(quest, guild.adventurers, "E"), 0.0, quest)
		# Like every other rank E quest: fair together, poor for any two.
		assert_between(guild.success_chance(quest, EVERYONE), 45, 75, quest)
		for first: int in EVERYONE.size():
			for second: int in range(first + 1, EVERYONE.size()):
				var pair := PackedStringArray([EVERYONE[first], EVERYONE[second]])
				assert_lte(guild.success_chance(quest, pair), 40, "%s %s" % [quest, pair])
	assert_eq(Dispatch.QUESTS["lost_survey"]["challenges"], ["Navigation", "Traps", "Attrition"])
	# The board still draws its own quests.
	assert_gt(Board.draw_chance("wolves", guild.adventurers, "E"), 0.0)


func test_claiming_rank_up_to_e_opens_the_cooks_debt_whose_goal_pays_40_gold_and_unlocks_the_kitchen() -> void:
	_hall.rank = "E"
	assert_eq(_state("rank_e"), Goals.State.DONE)
	assert_eq(_story_row(), PackedStringArray())
	assert_eq(_state("cooks_debt"), Goals.State.LOCKED)
	assert_true(_claim("rank_e"))
	assert_eq(_story_row(), PackedStringArray(["cooks_debt"]))
	assert_eq(_state("cooks_debt"), Goals.State.OPEN)
	# A party home from it successfully.
	_dispatch.story_done.append("cooks_debt")
	assert_eq(_story_row(), PackedStringArray())
	assert_eq(_state("cooks_debt"), Goals.State.DONE)
	assert_false(_goals.is_unlocked("kitchen"))
	var gold := _dispatch.gold.amount
	assert_true(_claim("cooks_debt"))
	assert_eq(_dispatch.gold.amount, gold + 40)
	assert_true(_goals.is_unlocked("kitchen"))


func test_clear_the_galleries_opens_after_the_first_expedition_is_done_at_floor_1_fully_explored_and_opens_the_lost_survey_whose_goal_pays_50_gold() -> void:
	_goals.claimed.remove_at(_goals.claimed.find("first_expedition"))
	assert_eq(_state("clear_floor_1"), Goals.State.LOCKED)
	_dispatch.tries["floor_1"] = 1
	assert_true(_claim("first_expedition"))
	assert_eq(_state("clear_floor_1"), Goals.State.OPEN)
	_dispatch.labyrinth.explored["floor_1"] = 80
	assert_eq(_goals.progress("clear_floor_1", _dispatch, _hall, _dispatch.story_done, 1_000), Vector2i(80, 100))
	assert_eq(_state("clear_floor_1"), Goals.State.OPEN)
	_dispatch.labyrinth.explored["floor_1"] = 100
	assert_eq(_state("clear_floor_1"), Goals.State.DONE)
	assert_eq(_state("lost_survey"), Goals.State.LOCKED)
	var gold := _dispatch.gold.amount
	assert_true(_claim("clear_floor_1"))
	assert_eq(_dispatch.gold.amount, gold + 40)
	assert_eq(_story_row(), PackedStringArray(["lost_survey"]))
	assert_eq(_state("lost_survey"), Goals.State.OPEN)
	_dispatch.story_done.append("lost_survey")
	assert_eq(_state("lost_survey"), Goals.State.DONE)
	assert_true(_claim("lost_survey"))
	assert_eq(_dispatch.gold.amount, gold + 90)


func test_rank_up_to_d_opens_once_both_chapter_2_story_goals_are_claimed_and_is_done_at_guild_rank_d() -> void:
	_goals.claimed.append_array(["rank_e", "clear_floor_1"])
	_hall.rank = "E"
	_dispatch.story_done.append_array(["cooks_debt", "lost_survey"])
	assert_eq(_state("rank_d"), Goals.State.LOCKED)
	assert_true(_claim("cooks_debt"))
	assert_eq(_state("rank_d"), Goals.State.LOCKED)
	assert_true(_claim("lost_survey"))
	assert_eq(_state("rank_d"), Goals.State.OPEN)
	assert_true(_goals.shown(_dispatch, _hall, _dispatch.story_done, 1_000).has("rank_d"))
	_hall.rank = "D"
	assert_eq(_state("rank_d"), Goals.State.DONE)
	var gold := _dispatch.gold.amount
	assert_true(_claim("rank_d"))
	assert_eq(_dispatch.gold.amount, gold + 100)


func test_an_old_save_that_claimed_rank_up_to_e_gets_the_cooks_debt_on_load() -> void:
	var file := ConfigFile.new()
	file.set_value("goals", "claimed", PackedStringArray(CHAPTER_1 + ["rank_e"]))
	file.set_value("goals", "unlocked", PackedStringArray(["sealed_gate", "labyrinth"]))
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Goals.load_or_start(SAVE_PATH)
	assert_eq(loaded.unlocked, PackedStringArray(["sealed_gate", "labyrinth", "cooks_debt"]))
	assert_eq(_dispatch.open_story_quests(loaded.unlocked), PackedStringArray(["sealed_gate", "cooks_debt"]))
	# One that hasn't claimed it yet doesn't.
	file.set_value("goals", "claimed", PackedStringArray(CHAPTER_1))
	assert_eq(file.save(SAVE_PATH), OK)
	assert_eq(Goals.load_or_start(SAVE_PATH).unlocked, PackedStringArray(["sealed_gate", "labyrinth"]))


func test_the_goals_card_names_every_unlock_and_the_chapter_2_ones_sensibly() -> void:
	for id: String in Goals.GOALS:
		var unlock: String = Goals.GOALS[id]["unlocks"]
		if not unlock.is_empty():
			assert_has(GoalsCard.UNLOCK_NAMES, unlock, id)
	assert_eq([GoalsCard.UNLOCK_NAMES["cooks_debt"], GoalsCard.UNLOCK_NAMES["kitchen"], GoalsCard.UNLOCK_NAMES["lost_survey"]], ["The cook's debt", "Kitchen", "The lost survey"])


## A rank-F hall at 1_000 with its side room restored and empty by 1_001, paid from `gold`.
func _hall_with_empty_room(gold: Gold) -> Hall:
	var hall := Hall.new(1_000)
	assert_true(hall.restore("side_left", gold, 1_000))
	hall.checkpoint(1_001)
	return hall


func test_the_kitchen_cant_be_built_until_unlocked_then_builds_and_upgrades_like_any_room() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room(gold)
	assert_eq(Hall.ROOM_TYPES["kitchen"]["name"], "Kitchen")
	assert_eq(Hall.ROOM_TYPES["kitchen"]["blurb"], "+10% XP from quests")
	assert_eq(hall.convert_refusal("side_left", "kitchen", gold, 1_001), "Not unlocked yet")
	assert_false(hall.convert_room("side_left", "kitchen", gold, 1_001))
	assert_eq(hall.convert_refusal("side_left", "kitchen", gold, 1_001, PackedStringArray(["labyrinth"])), "Not unlocked yet")
	assert_eq([gold.amount, hall.building, hall.state("side_left", 1_001)], [940, "", Hall.State.RESTORED])
	# Another type needs no unlock.
	assert_eq(hall.convert_refusal("side_left", "tavern", gold, 1_001), "")
	assert_eq(hall.convert_refusal("side_left", "kitchen", gold, 1_001, KITCHEN), "")
	assert_true(hall.convert_room("side_left", "kitchen", gold, 1_001, KITCHEN))
	assert_eq(gold.amount, 880)
	assert_eq(hall.state("side_left", 1_002), Hall.State.CONVERTING)
	assert_eq(hall.state("side_left", 1_003), Hall.State.CONVERTED)
	hall.checkpoint(1_003)
	assert_eq(hall.upgrade_refusal("side_left", gold, 1_003), "Guild rank E")
	hall.rank = "E"
	assert_true(hall.upgrade("side_left", gold, 1_003))
	assert_eq([gold.amount, hall.seconds_left(1_003)], [760, 4])
	hall.checkpoint(1_007)
	assert_eq(hall.next_upgrade("side_left", 1_007)["blurb"], "+10% XP")
	assert_eq(hall.upgrade_refusal("side_left", gold, 1_007), "Guild rank D")
	hall.rank = "D"
	assert_true(hall.upgrade("side_left", gold, 1_007))
	assert_eq([gold.amount, hall.seconds_left(1_007)], [460, 10])
	hall.checkpoint(1_017)
	assert_eq(hall.tier("side_left", 1_017), 3)
	assert_eq(hall.tier_times("kitchen"), PackedInt64Array([1_003, 1_007, 1_017]))
	# Built once only.
	gold.amount = 1_000
	assert_true(hall.restore("back_left", gold, 1_017))
	hall.checkpoint(1_100)
	assert_eq(hall.convert_refusal("back_left", "kitchen", gold, 1_100, KITCHEN), "Already built")


func test_the_convert_panel_shows_the_kitchen_only_once_unlocked() -> void:
	var gold := Gold.new(1_000)
	var hall := _hall_with_empty_room(gold)
	var panel := (load("res://screens/convert_panel.tscn") as PackedScene).instantiate() as ConvertPanel
	add_child_autofree(panel)
	panel.show_hall(hall, "side_left", gold, 1_001)
	assert_false(panel._choices["kitchen"].visible)
	assert_false(panel._reasons["kitchen"].visible)
	assert_true(panel._choices["tavern"].visible)
	panel.show_hall(hall, "side_left", gold, 1_001, KITCHEN)
	assert_true(panel._choices["kitchen"].visible)
	assert_false(panel._choices["kitchen"].disabled)
	assert_true(panel._choices["tavern"].visible)


## The XP Bram gains when he and Tobin come home from `quest` at 1_000 plus its length, as
## `success` says, to a Kitchen that reached its tiers at `kitchen_tiers`.
func _xp_home(quest: String, success: bool, kitchen_tiers: PackedInt64Array) -> int:
	var dispatch := Dispatch.new(1_000)
	dispatch.kitchen_tiers = kitchen_tiers
	assert_true(dispatch.send(quest, PAIR, 1, 1_000))
	dispatch.outings[0]["chance"] = 100 if success else 0
	var before: int = dispatch.adventurers.xp["bram"]
	dispatch.checkpoint(1_000 + int(Dispatch.QUESTS[quest]["seconds"]))
	assert_true(dispatch.outings.is_empty(), quest)
	return dispatch.adventurers.xp["bram"] - before


func test_a_party_home_with_a_kitchen_gains_10_20_30_percent_more_quest_xp_by_its_tier_at_the_return() -> void:
	# The lost survey's 55 XP between two, raised before it is split and rounded down: a success
	# 27, 30, 33 and 35 each by tier, none first; a failure's quarter, 13, gives 6, 7, 7 and 8.
	var back := 1_030
	for tiers: Array in [[NONE, 27, 6], [PackedInt64Array([back]), 30, 7], [PackedInt64Array([back, back]), 33, 7], [PackedInt64Array([back, back, back]), 35, 8]]:
		assert_eq(_xp_home("lost_survey", true, tiers[0]), tiers[1], str(tiers[0]))
		assert_eq(_xp_home("lost_survey", false, tiers[0]), tiers[2], str(tiers[0]))
	# A tier reached a second after the return doesn't count; tiers reached earlier do.
	assert_eq(_xp_home("lost_survey", true, PackedInt64Array([900, back + 1])), 30)
	# Floors too: The Galleries' 32 XP is 16 each without one, 20 with a tier-3 Kitchen.
	assert_eq(_xp_home("floor_1", true, NONE), 16)
	assert_eq(_xp_home("floor_1", true, PackedInt64Array([900, 900, 900])), 20)


## A guild of the four starters in one party on Auto, Bold, at guild rank E, with room in the stash
## for anything, whose questing over ten days from 1_000 is settled by averages, its Kitchen
## reaching its tiers at `kitchen_tiers`: [Bram's XP gained, the gold earned].
func _ten_days_averaged(kitchen_tiers: PackedInt64Array) -> Array[int]:
	var dispatch := Dispatch.new(1_000)
	dispatch.adventurers = Adventurers.new(EVERYONE)
	dispatch.gold = Gold.new(0)
	dispatch.kitchen_tiers = kitchen_tiers
	var parties := dispatch.adventurers.parties
	var party := parties.party_of("bram")
	assert_eq(parties.party(party)["members"].size(), 4)
	parties.set_auto(party, true)
	parties.set_mode(party, Parties.BOLD)
	dispatch.adventurers.gear.stash_cap = 100_000
	var board := Board.new()
	board.reception_slots = 3
	board.refill(dispatch, 1_000, NONE, NONE, NONE, "E")
	var before: int = dispatch.adventurers.xp["bram"]
	Auto.checkpoint(dispatch, board, 1_000 + 10 * 86_400, NONE, NONE, NONE, NONE, "E")
	return [dispatch.adventurers.xp["bram"] - before, dispatch.gold.amount]


func test_autos_averaged_settle_counts_the_kitchens_xp_by_the_tier_in_force() -> void:
	var without := _ten_days_averaged(NONE)
	var tier_3 := _ten_days_averaged(PackedInt64Array([1_000, 1_000, 1_000]))
	var halfway := _ten_days_averaged(PackedInt64Array([1_000 + 5 * 86_400, 1_000 + 5 * 86_400, 1_000 + 5 * 86_400]))
	assert_gt(without[0], 0)
	assert_gt(tier_3[0], without[0])
	assert_between(halfway[0], without[0] + 1, tier_3[0] - 1)
	# Half the time at tier 3: about halfway between.
	assert_almost_eq(float(halfway[0]), (without[0] + tier_3[0]) / 2.0, (tier_3[0] - without[0]) * 0.05)
	# A Kitchen adds XP, nothing else.
	assert_eq(tier_3[1], without[1])
	assert_eq(halfway[1], without[1])
