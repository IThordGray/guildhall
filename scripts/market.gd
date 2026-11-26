class_name Market
extends RefCounted

## The town's Market: a few items of gear for sale, a new stock every STOCK_SECONDS, and a buyer for
## labyrinth materials. Each period's stock is drawn from a saved seed and the period alone, so
## being away gives the same stock as watching. Buying and selling here are spending and selling,
## never gold earned. Numbers are stand-ins.

## What Goals unlocks to open the town.
const UNLOCK: String = "town"
## How many items the Market offers at once.
const STOCK_SIZE: int = 4
## How long one stock is offered: a day at the game's stand-in speed.
const STOCK_SECONDS: int = 2880
## How likely each item offered is of each quality, in whole percent. The Market sells no Legendary.
const QUALITY_PERCENT: Dictionary[String, int] = {"Standard": 75, "Fine": 25}
## An item costs this many times what it sells for from the stash (Gear.price).
const PRICE_TIMES_SELL: int = 4
## The gold each unit of a labyrinth material sells for, by its name (Labyrinth.FLOORS).
const MATERIAL_GOLD: Dictionary[String, int] = {"Glowmoss": 4, "Riverglass": 6, "Bone silver": 10}

## What each period's stock is drawn from, with the period, never the global generator.
var stock_seed: int = randi()
## The latest period the Market has seen: game seconds divided by STOCK_SECONDS, rounded down.
var period: int = 0
## The slots of `period`'s stock already bought.
var sold: PackedInt32Array = PackedInt32Array()


## The items offered at `now`, STOCK_SIZE of them by slot, sold ones included.
func stock(now: int) -> PackedStringArray:
	_catch_up(now)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["market", stock_seed, period])
	var items := PackedStringArray()
	for slot: int in STOCK_SIZE:
		var roll := rng.randi_range(1, 100)
		var quality := ""
		for each: String in QUALITY_PERCENT:
			quality = each
			roll -= QUALITY_PERCENT[each]
			if roll <= 0:
				break
		var choices := Gear.of_quality(quality)
		items.append(choices[rng.randi_range(0, choices.size() - 1)])
	return items


## Whether slot `slot` of the stock at `now` is already bought.
func is_sold(slot: int, now: int) -> bool:
	_catch_up(now)
	return slot in sold


## The gold `item` costs at the Market.
static func price(item: String) -> int:
	return PRICE_TIMES_SELL * Gear.price(item)


## Why slot `slot` of the stock at `now` can't be bought with `gold` into `gear`'s stash, in words
## for the player; "" when it can.
func buy_refusal(slot: int, gold: Gold, gear: Gear, now: int) -> String:
	if is_sold(slot, now):
		return "Sold"
	var cost := price(stock(now)[slot])
	if gold.amount < cost:
		return "Need %d more gold" % (cost - gold.amount)
	if gear.stash.size() >= gear.stash_cap:
		return "Stash full"
	return ""


## Buys slot `slot` of the stock at `now`: pays its price from `gold`, puts the item in `gear`'s
## stash and marks the slot sold until the next period; false, with nothing changed, when
## buy_refusal gives a reason.
func buy(slot: int, gold: Gold, gear: Gear, now: int) -> bool:
	if not buy_refusal(slot, gold, gear, now).is_empty():
		return false
	var item := stock(now)[slot]
	gold.spend(price(item))
	gear.stow(item)
	sold.append(slot)
	return true


## Sells all of `labyrinth`'s `material` for MATERIAL_GOLD each into `gold`, as selling, not
## income; false, with nothing changed, when there is none.
func sell_all(material: String, labyrinth: Labyrinth, gold: Gold) -> bool:
	var count := int(labyrinth.materials.get(material, 0))
	if count <= 0:
		return false
	gold.amount += count * MATERIAL_GOLD[material]
	labyrinth.materials[material] = 0
	return true


# Moves to the period of `now`, read as no earlier than the latest the Market has seen, so a clock
# set back never brings back an older stock or a sold item. A new period has nothing sold.
func _catch_up(now: int) -> void:
	var now_period := maxi(period, floori(now / float(STOCK_SECONDS)))
	if now_period != period:
		period = now_period
		sold = PackedInt32Array()


## Puts the Market into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("market", "seed", stock_seed)
	file.set_value("market", "period", period)
	file.set_value("market", "sold", sold)


## The Market saved at `path`, or a fresh one when the save has none, as one from before the town.
static func load_or_start(path: String) -> Market:
	var market := Market.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("market"):
		return market
	market.stock_seed = int(file.get_value("market", "seed"))
	market.period = int(file.get_value("market", "period"))
	market.sold = file.get_value("market", "sold", PackedInt32Array())
	return market
