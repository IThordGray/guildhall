class_name Gear
extends RefCounted

## What each adventurer wears, and the stash the whole guild shares. An item adds its bonuses to
## the wearer's stats. Anyone can wear any item, and gear never wears out.

## The slots every adventurer has, in the order they are shown, with their names for the player.
const SLOTS: Dictionary[String, String] = {
	"head": "Head", "clothes": "Clothes", "armour": "Armour", "belt": "Belt",
	"weapon": "Weapon", "off_hand": "Off-hand", "back": "Back", "neck": "Neck",
}
## How likely a quest's loot is of each quality, in whole percent, from commonest to rarest
## (stand-ins), for a party with no Luck: see `quality_percent`.
const QUALITY_PERCENT: Dictionary[String, int] = {"Standard": 80, "Fine": 18, "Legendary": 2}
## The gold a stash item of each quality sells for (stand-ins).
const SELL_GOLD: Dictionary[String, int] = {"Standard": 3, "Fine": 15, "Legendary": 60}
## The whole-percent chance that a party back from a quest of each rank brings an item (stand-ins).
const LOOT_PERCENT: Dictionary[String, int] = {"F": 25, "E": 50, "D": 75}
## A party's total Luck adds a point to its loot chance per point, at most MOST_LUCK_LOOT_POINTS.
## Each point also moves a point of quality odds from Standard to Fine, and every
## LUCK_PER_LEGENDARY_POINT points one more to Legendary (stand-ins).
const MOST_LUCK_LOOT_POINTS: int = 25
const LUCK_PER_LEGENDARY_POINT: int = 5
## Every item, by the id the save and its icon use, adding stats where its kind leans: a Standard
## item +1–2 in all, a Fine one +2–4, a Legendary one +4–7 (stand-ins).
const ITEMS: Dictionary[String, Dictionary] = {
	"iron_cap": {"name": "Iron cap", "slot": "head", "quality": "Standard", "bonus": {"defence": 1}},
	"goblin_bone_helm": {"name": "Goblin-bone helm", "slot": "head", "quality": "Fine", "bonus": {"defence": 2, "strength": 1}},
	"scouts_hood": {"name": "Scout's hood", "slot": "head", "quality": "Standard", "bonus": {"perception": 1}},
	"moss_hood": {"name": "Moss hood", "slot": "head", "quality": "Standard", "bonus": {"perception": 2}},
	"pointed_hat": {"name": "Pointed hat", "slot": "head", "quality": "Standard", "bonus": {"mind": 1}},
	"silver_circlet": {"name": "Silver circlet", "slot": "head", "quality": "Fine", "bonus": {"presence": 2, "mind": 1}},
	"red_tunic": {"name": "Red tunic", "slot": "clothes", "quality": "Standard", "bonus": {"endurance": 1}},
	"leather_jerkin": {"name": "Leather jerkin", "slot": "clothes", "quality": "Standard", "bonus": {"agility": 1}},
	"apprentice_robe": {"name": "Apprentice robe", "slot": "clothes", "quality": "Standard", "bonus": {"mind": 1}},
	"moonweave_robe": {"name": "Moonweave robe", "slot": "clothes", "quality": "Legendary", "bonus": {"mind": 4, "spirit": 3}},
	"healers_robe": {"name": "Healer's robe", "slot": "clothes", "quality": "Standard", "bonus": {"spirit": 1}},
	"leather_vest": {"name": "Leather vest", "slot": "armour", "quality": "Standard", "bonus": {"endurance": 1}},
	"rangers_vest": {"name": "Ranger's vest", "slot": "armour", "quality": "Standard", "bonus": {"agility": 1, "endurance": 1}},
	"chain_shirt": {"name": "Chain shirt", "slot": "armour", "quality": "Standard", "bonus": {"defence": 2}},
	"chapel_plate": {"name": "Chapel plate", "slot": "armour", "quality": "Legendary", "bonus": {"defence": 4, "spirit": 2}},
	"round_shield": {"name": "Round shield", "slot": "off_hand", "quality": "Standard", "bonus": {"defence": 1}},
	"goblin_shield": {"name": "Goblin shield", "slot": "off_hand", "quality": "Fine", "bonus": {"defence": 3}},
	"chapel_shield": {"name": "Chapel shield", "slot": "off_hand", "quality": "Fine", "bonus": {"defence": 2, "spirit": 1}},
	"short_sword": {"name": "Short sword", "slot": "weapon", "quality": "Standard", "bonus": {"strength": 1}},
	"goblin_slayer_blade": {"name": "Goblin-slayer blade", "slot": "weapon", "quality": "Legendary", "bonus": {"strength": 4, "agility": 2}},
	"oak_staff": {"name": "Oak staff", "slot": "weapon", "quality": "Standard", "bonus": {"mind": 1}},
	"moonherb_staff": {"name": "Moonherb staff", "slot": "weapon", "quality": "Fine", "bonus": {"mind": 3}},
	"hunting_bow": {"name": "Hunting bow", "slot": "weapon", "quality": "Standard", "bonus": {"perception": 1, "agility": 1}},
	"bell_mace": {"name": "Bell mace", "slot": "weapon", "quality": "Standard", "bonus": {"spirit": 1}},
	"red_cloak": {"name": "Red cloak", "slot": "back", "quality": "Standard", "bonus": {"presence": 1}},
	"night_cloak": {"name": "Night cloak", "slot": "back", "quality": "Fine", "bonus": {"agility": 3}},
	"forest_cloak": {"name": "Forest cloak", "slot": "back", "quality": "Standard", "bonus": {"agility": 2}},
	"pilgrim_cloak": {"name": "Pilgrim cloak", "slot": "back", "quality": "Standard", "bonus": {"presence": 2}},
	"quiver": {"name": "Quiver", "slot": "back", "quality": "Standard", "bonus": {"perception": 1}},
	"belt": {"name": "Belt", "slot": "belt", "quality": "Standard", "bonus": {"endurance": 2}},
	"sash": {"name": "Sash", "slot": "belt", "quality": "Standard", "bonus": {"endurance": 1}},
	"green_sash": {"name": "Green sash", "slot": "belt", "quality": "Standard", "bonus": {"endurance": 1}},
	"moonstone_amulet": {"name": "Moonstone amulet", "slot": "neck", "quality": "Standard", "bonus": {"luck": 2}},
}
## What each starter wears on joining the guild, by slot; a recruit joins wearing what they came
## with (Recruits.hire).
const STARTER_GEAR: Dictionary[String, Dictionary] = {
	"bram": {"head": "iron_cap", "clothes": "red_tunic", "armour": "leather_vest", "weapon": "short_sword", "off_hand": "round_shield"},
	"ilse": {"head": "pointed_hat", "clothes": "apprentice_robe", "neck": "moonstone_amulet", "weapon": "oak_staff"},
	"tobin": {"head": "scouts_hood", "clothes": "leather_jerkin", "weapon": "hunting_bow", "back": "quiver"},
	"maren": {"clothes": "healers_robe", "belt": "green_sash", "weapon": "bell_mace"},
}

## Each adventurer's items, {slot: item id}; a slot missing is empty.
var worn: Dictionary[String, Dictionary] = {}
## Item ids in the shared stash, in the order they came in.
var stash: PackedStringArray = PackedStringArray()
## Items the stash holds at most, as the hall gives it (Hall.stash_cap); loot that finds it full
## waits for the player (Dispatch.waiting_loot). Not saved: whoever runs the game sets it from the hall.
var stash_cap: int = Hall.LAYOUTS[Hall.NEW_LAYOUT]["stash"]


## The points `adventurer`'s items add to `stat`.
func bonus(adventurer: String, stat: String) -> int:
	var total := 0
	for item: String in worn[adventurer].values():
		total += int(ITEMS[item]["bonus"].get(stat, 0))
	return total


## The item a party with `luck` in all, back from a quest of `rank`, brings, or "" for none. It
## depends only on `roll_seed`, `rank` and `luck`, so the same return always brings the same item.
static func loot(roll_seed: int, rank: String, luck: int = 0) -> String:
	var rng := RandomNumberGenerator.new()
	# Not the outcome's own sequence, so whether loot comes is independent of success.
	rng.seed = hash("loot:%d" % roll_seed)
	if rng.randi_range(1, 100) > loot_percent(rank, luck):
		return ""
	return _draw_item(rng, luck)


## The whole-percent chance that a party with `luck` in all, back from a quest of `rank`, brings an
## item.
static func loot_percent(rank: String, luck: int) -> int:
	return LOOT_PERCENT[rank] + mini(MOST_LUCK_LOOT_POINTS, luck)


## An item a party with `luck` in all brings, as `loot` draws it once there is one, drawn by
## `roll_seed` alone, so the same seed always gives the same item.
static func loot_item(roll_seed: int, luck: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	return _draw_item(rng, luck)


# An item's quality by `quality_percent` for `luck`, then one of that quality's items, each as
# likely, drawn from `rng`.
static func _draw_item(rng: RandomNumberGenerator, luck: int) -> String:
	var roll := rng.randi_range(1, 100)
	var shares := quality_percent(luck)
	var quality := ""
	for each: String in shares:
		quality = each
		roll -= shares[each]
		if roll <= 0:
			break
	var choices := of_quality(quality)
	return choices[rng.randi_range(0, choices.size() - 1)]


## The items of `quality`, in ITEMS order.
static func of_quality(quality: String) -> PackedStringArray:
	var found := PackedStringArray()
	for item: String in ITEMS:
		if ITEMS[item]["quality"] == quality:
			found.append(item)
	return found


## How likely loot is of each quality for a party with `luck` in all, in whole percent, as
## QUALITY_PERCENT orders them: luck moves odds from Standard to Fine and Legendary, until
## Standard has none left.
static func quality_percent(luck: int) -> Dictionary[String, int]:
	var legendary: int = QUALITY_PERCENT["Legendary"] + floori(luck / float(LUCK_PER_LEGENDARY_POINT))
	var fine: int = mini(QUALITY_PERCENT["Fine"] + luck, 100 - legendary)
	return {"Standard": 100 - fine - legendary, "Fine": fine, "Legendary": legendary}


## Puts `item` in the stash; false, with the item lost, when the stash is full.
func stow(item: String) -> bool:
	if stash.size() >= stash_cap:
		return false
	stash.append(item)
	return true


## The gold `item` sells for, by its quality.
static func price(item: String) -> int:
	return SELL_GOLD[ITEMS[item]["quality"]]


## Why `item` can't be sold, in words for the player; "" when it can. Only stash items sell: a worn
## one is taken off first.
func sell_refusal(item: String) -> String:
	return "" if item in stash else "Not in the stash"


## Sells one `item` from the stash for good, its `price` into `gold`; false, with nothing changed,
## when sell_refusal gives a reason.
func sell(item: String, gold: Gold) -> bool:
	if not sell_refusal(item).is_empty():
		return false
	stash.remove_at(stash.find(item))
	gold.amount += price(item)
	return true


## Puts the stash item at `index` on `adventurer`, and whatever they wore in its slot into the
## stash in its place. Whether they may change gear is Dispatch's rule.
func wear(adventurer: String, index: int) -> void:
	var item := stash[index]
	var slot: String = ITEMS[item]["slot"]
	var replaced: String = worn[adventurer].get(slot, "")
	worn[adventurer][slot] = item
	if replaced.is_empty():
		stash.remove_at(index)
	else:
		stash[index] = replaced


## Where in the stash the items that go in `slot` are, in stash order.
func fitting(slot: String) -> PackedInt32Array:
	var found := PackedInt32Array()
	for i: int in stash.size():
		if ITEMS[stash[i]]["slot"] == slot:
			found.append(i)
	return found


## Puts what `adventurer` wears in `slot` into the stash, leaving the slot empty; false, with
## nothing changed, when the stash is full or the slot already empty. Whether they may change gear
## is Dispatch's rule.
func take_off(adventurer: String, slot: String) -> bool:
	var item: String = worn[adventurer].get(slot, "")
	if item.is_empty() or not stow(item):
		return false
	worn[adventurer].erase(slot)
	return true


## Takes everything off `adventurer`, who is leaving the guild, into the stash in SLOTS order, and
## forgets what they wore. Returns the items that found the stash full: those leave with them.
func strip(adventurer: String) -> PackedStringArray:
	var gone := PackedStringArray()
	for slot: String in SLOTS:
		var item: String = worn[adventurer].get(slot, "")
		if not item.is_empty() and not stow(item):
			gone.append(item)
	worn.erase(adventurer)
	return gone


## How many of `adventurer`'s items `strip` would find no room for in the stash now.
func leaving_with(adventurer: String) -> int:
	return maxi(0, worn[adventurer].size() - (stash_cap - stash.size()))


## Puts the gear into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("gear", "worn", worn)
	file.set_value("gear", "stash", stash)


## The gear saved at `path`, or nothing worn and an empty stash when the save has none.
static func load_or_start(path: String) -> Gear:
	var gear := Gear.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("gear"):
		return gear
	gear.worn.assign(file.get_value("gear", "worn"))
	gear.stash = file.get_value("gear", "stash", PackedStringArray())
	return gear
