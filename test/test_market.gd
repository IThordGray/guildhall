extends GutTest

const SAVE_PATH: String = "user://test_market_save.cfg"
## Chapter 1's story goals, all claimed by the time Rank up to E is.
const CHAPTER_1: Array[String] = ["first_quest", "first_restore", "first_room", "first_recruit", "second_party", "sealed_gate", "first_expedition"]
## Game seconds at the start of a stock period.
const START: int = 1_000 * Market.STOCK_SECONDS


func after_each() -> void:
	DirAccess.remove_absolute(SAVE_PATH)


## A Market whose stocks are drawn from seed 7.
func _market() -> Market:
	var market := Market.new()
	market.stock_seed = 7
	return market


## A game second, in one of the 100 periods from START on, whose stock holds both a Standard and a
## Fine item.
func _mixed_time(market: Market) -> int:
	for period: int in 100:
		var at := START + period * Market.STOCK_SECONDS
		var qualities := []
		for item: String in market.stock(at):
			qualities.append(Gear.ITEMS[item]["quality"])
		if "Standard" in qualities and "Fine" in qualities:
			return at
	fail_test("No stock of 100 holds both a Standard and a Fine item")
	return START


## The slot of the stock at `at` holding an item of `quality`.
func _slot_of(market: Market, quality: String, at: int) -> int:
	var items := market.stock(at)
	for slot: int in items.size():
		if Gear.ITEMS[items[slot]]["quality"] == quality:
			return slot
	return -1


func test_with_rank_up_to_e_claimed_the_town_is_unlocked_for_new_claims_and_old_saves_alike_and_before_it_is_not() -> void:
	var dispatch := Dispatch.new(1_000)
	var hall := Hall.new(1_000)
	var goals := Goals.new()
	goals.claimed.append_array(CHAPTER_1)
	hall.rank = "E"
	assert_false(goals.is_unlocked(Market.UNLOCK))
	assert_true(goals.claim("rank_e", dispatch, hall, dispatch.story_done, 1_000))
	assert_true(goals.is_unlocked(Market.UNLOCK))
	assert_true(goals.is_unlocked("cooks_debt"))
	assert_eq(GoalsCard.UNLOCK_NAMES[Market.UNLOCK], "The town")
	# A save that claimed it before it opened the town gets the town on load.
	var file := ConfigFile.new()
	file.set_value("goals", "claimed", PackedStringArray(CHAPTER_1 + ["rank_e"]))
	file.set_value("goals", "unlocked", PackedStringArray(["sealed_gate", "labyrinth", "cooks_debt"]))
	assert_eq(file.save(SAVE_PATH), OK)
	assert_true(Goals.load_or_start(SAVE_PATH).is_unlocked(Market.UNLOCK))
	# One that hasn't claimed it doesn't, though it keeps what it has.
	file.set_value("goals", "claimed", PackedStringArray(CHAPTER_1))
	file.set_value("goals", "unlocked", PackedStringArray(["sealed_gate", "labyrinth"]))
	assert_eq(file.save(SAVE_PATH), OK)
	var before := Goals.load_or_start(SAVE_PATH)
	assert_false(before.is_unlocked(Market.UNLOCK))
	assert_true(before.is_unlocked("labyrinth"))


func test_the_stock_is_four_standard_or_fine_items_the_same_read_once_after_an_absence_or_every_second_new_each_period_and_kept_through_save_and_load() -> void:
	var watched := _market()
	var away := _market()
	var first := away.stock(START)
	assert_eq(first.size(), 4)
	for item: String in first:
		assert_true(Gear.ITEMS[item]["quality"] in ["Standard", "Fine"], item)
	var later := START + 3 * Market.STOCK_SECONDS + 100
	for at: int in range(START, later + 1):
		watched.stock(at)
	assert_eq(away.stock(later), watched.stock(later))
	# Each period's stock is its own.
	assert_ne(away.stock(later), first)
	var next := _market()
	var this_period := next.stock(later)
	assert_ne(next.stock(later + Market.STOCK_SECONDS), this_period)
	# The same period's stock after the save is loaded, with what was sold.
	away.sold.append(2)
	var file := ConfigFile.new()
	away.write(file)
	assert_eq(file.save(SAVE_PATH), OK)
	var loaded := Market.load_or_start(SAVE_PATH)
	assert_eq(loaded.stock(later), away.stock(later))
	assert_true(loaded.is_sold(2, later))
	assert_false(loaded.is_sold(1, later))
	# A save from before the town starts a fresh Market, nothing sold.
	var older := ConfigFile.new()
	older.set_value("gold", "saved", 5)
	assert_eq(older.save(SAVE_PATH), OK)
	assert_eq(Market.load_or_start(SAVE_PATH).sold, PackedInt32Array())


func test_a_clock_set_back_neither_brings_back_an_older_stock_nor_unsells_an_item() -> void:
	var market := _market()
	var gold := Gold.new(1_000)
	var gear := Gear.new()
	var older := market.stock(START)
	var now := START + Market.STOCK_SECONDS
	var current := market.stock(now)
	assert_ne(current, older)
	assert_true(market.buy(0, gold, gear, now))
	var back := START + 10
	assert_eq(market.stock(back), current)
	assert_true(market.is_sold(0, back))
	assert_eq(market.buy_refusal(0, gold, gear, back), "Sold")
	# The next period still comes at its time.
	assert_false(market.is_sold(0, now + Market.STOCK_SECONDS))


func test_buying_pays_12_for_standard_and_60_for_fine_stows_the_item_and_marks_it_sold_for_that_period() -> void:
	var market := _market()
	var at := _mixed_time(market)
	var gold := Gold.new(1_000)
	var gear := Gear.new()
	var standard := _slot_of(market, "Standard", at)
	var fine := _slot_of(market, "Fine", at)
	assert_eq(market.buy_refusal(standard, gold, gear, at), "")
	assert_true(market.buy(standard, gold, gear, at))
	assert_eq([gold.amount, gold.earned], [988, 0])
	assert_true(market.buy(fine, gold, gear, at + 1))
	assert_eq(gold.amount, 928)
	assert_eq(gear.stash, PackedStringArray([market.stock(at)[standard], market.stock(at)[fine]]))
	assert_true(market.is_sold(standard, at + 2))
	assert_true(market.is_sold(fine, at + 2))
	for slot: int in Market.STOCK_SIZE:
		assert_eq(market.is_sold(slot, at + 2), slot in [standard, fine], str(slot))
	# Sold until the next period, which has nothing sold.
	var next := at - at % Market.STOCK_SECONDS + Market.STOCK_SECONDS
	assert_true(market.is_sold(standard, next - 1))
	assert_false(market.is_sold(standard, next))
	assert_false(market.is_sold(fine, next))


func test_each_refusal_to_buy_changes_nothing() -> void:
	var market := _market()
	var at := _mixed_time(market)
	var standard := _slot_of(market, "Standard", at)
	var fine := _slot_of(market, "Fine", at)
	var gear := Gear.new()
	# Gold short.
	var poor := Gold.new(50)
	assert_eq(market.buy_refusal(fine, poor, gear, at), "Need 10 more gold")
	assert_false(market.buy(fine, poor, gear, at))
	assert_eq([poor.amount, gear.stash, market.is_sold(fine, at)], [50, PackedStringArray(), false])
	# Stash full.
	var gold := Gold.new(1_000)
	gear.stash = PackedStringArray(["belt"])
	gear.stash_cap = 1
	assert_eq(market.buy_refusal(standard, gold, gear, at), "Stash full")
	assert_false(market.buy(standard, gold, gear, at))
	assert_eq([gold.amount, gear.stash, market.is_sold(standard, at)], [1_000, PackedStringArray(["belt"]), false])
	# Already sold this period.
	gear.stash_cap = 10
	assert_true(market.buy(standard, gold, gear, at))
	var paid := gold.amount
	assert_eq(market.buy_refusal(standard, gold, gear, at), "Sold")
	assert_false(market.buy(standard, gold, gear, at))
	assert_eq([gold.amount, gear.stash.size()], [paid, 2])


func test_selling_all_of_a_material_pays_count_times_its_price_leaves_none_and_is_not_gold_earned() -> void:
	var market := _market()
	var labyrinth := Labyrinth.new()
	labyrinth.materials.assign({"Glowmoss": 5, "Riverglass": 2, "Bone silver": 3})
	var gold := Gold.new(100)
	assert_true(market.sell_all("Glowmoss", labyrinth, gold))
	assert_eq([gold.amount, gold.earned], [120, 0])
	assert_eq(labyrinth.materials, {"Glowmoss": 0, "Riverglass": 2, "Bone silver": 3})
	assert_true(market.sell_all("Riverglass", labyrinth, gold))
	assert_true(market.sell_all("Bone silver", labyrinth, gold))
	assert_eq([gold.amount, gold.earned], [162, 0])
	assert_eq(labyrinth.materials, {"Glowmoss": 0, "Riverglass": 0, "Bone silver": 0})


func test_selling_a_material_the_guild_has_none_of_is_refused_with_nothing_changed() -> void:
	var market := _market()
	var labyrinth := Labyrinth.new()
	labyrinth.materials.assign({"Glowmoss": 0, "Riverglass": 4})
	var gold := Gold.new(100)
	assert_false(market.sell_all("Glowmoss", labyrinth, gold))
	assert_false(market.sell_all("Bone silver", labyrinth, gold))
	assert_eq(gold.amount, 100)
	assert_eq(labyrinth.materials, {"Glowmoss": 0, "Riverglass": 4})
