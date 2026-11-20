class_name Gear
extends RefCounted

## What each adventurer wears, and the stash the whole guild shares. An item adds its bonuses to
## the wearer's stats. Any class can wear any item, and gear never wears out.

## The slots every adventurer has, in the order they are shown, with their names for the player.
const SLOTS: Dictionary[String, String] = {
	"head": "Head", "clothes": "Clothes", "armour": "Armour", "belt": "Belt",
	"weapon": "Weapon", "off_hand": "Off-hand", "back": "Back", "neck": "Neck",
}
## How likely a quest's loot is of each quality, in whole percent, from commonest to rarest
## (stand-ins).
const QUALITY_PERCENT: Dictionary[String, int] = {"Standard": 80, "Fine": 18, "Legendary": 2}
## The whole-percent chance that a party back from a quest of each rank brings an item (stand-ins).
const LOOT_PERCENT: Dictionary[String, int] = {"F": 25, "E": 50}
## Items the stash holds at most; loot that finds it full is lost (stand-in).
const STASH_CAP: int = 20
## Every item, by the id the save and its icon use. Bonuses are stand-ins: Standard +1 to one stat
## or none, Fine +1 or +2 to one or two, Legendary +3 or +4 to two.
const ITEMS: Dictionary[String, Dictionary] = {
	"iron_cap": {"name": "Iron cap", "slot": "head", "quality": "Standard", "bonus": {}},
	"goblin_bone_helm": {"name": "Goblin-bone helm", "slot": "head", "quality": "Fine", "bonus": {"grit": 1}},
	"scouts_hood": {"name": "Scout's hood", "slot": "head", "quality": "Standard", "bonus": {}},
	"moss_hood": {"name": "Moss hood", "slot": "head", "quality": "Standard", "bonus": {"agility": 1}},
	"pointed_hat": {"name": "Pointed hat", "slot": "head", "quality": "Standard", "bonus": {}},
	"silver_circlet": {"name": "Silver circlet", "slot": "head", "quality": "Fine", "bonus": {"mind": 1, "grit": 1}},
	"red_tunic": {"name": "Red tunic", "slot": "clothes", "quality": "Standard", "bonus": {}},
	"leather_jerkin": {"name": "Leather jerkin", "slot": "clothes", "quality": "Standard", "bonus": {}},
	"apprentice_robe": {"name": "Apprentice robe", "slot": "clothes", "quality": "Standard", "bonus": {}},
	"moonweave_robe": {"name": "Moonweave robe", "slot": "clothes", "quality": "Legendary", "bonus": {"mind": 4, "grit": 3}},
	"healers_robe": {"name": "Healer's robe", "slot": "clothes", "quality": "Standard", "bonus": {}},
	"leather_vest": {"name": "Leather vest", "slot": "armour", "quality": "Standard", "bonus": {}},
	"rangers_vest": {"name": "Ranger's vest", "slot": "armour", "quality": "Standard", "bonus": {"agility": 1}},
	"chain_shirt": {"name": "Chain shirt", "slot": "armour", "quality": "Standard", "bonus": {"grit": 1}},
	"chapel_plate": {"name": "Chapel plate", "slot": "armour", "quality": "Legendary", "bonus": {"grit": 4, "might": 3}},
	"round_shield": {"name": "Round shield", "slot": "off_hand", "quality": "Standard", "bonus": {}},
	"goblin_shield": {"name": "Goblin shield", "slot": "off_hand", "quality": "Fine", "bonus": {"grit": 2}},
	"chapel_shield": {"name": "Chapel shield", "slot": "off_hand", "quality": "Fine", "bonus": {"grit": 1, "mind": 1}},
	"short_sword": {"name": "Short sword", "slot": "weapon", "quality": "Standard", "bonus": {}},
	"goblin_slayer_blade": {"name": "Goblin-slayer blade", "slot": "weapon", "quality": "Legendary", "bonus": {"might": 4, "agility": 3}},
	"oak_staff": {"name": "Oak staff", "slot": "weapon", "quality": "Standard", "bonus": {}},
	"moonherb_staff": {"name": "Moonherb staff", "slot": "weapon", "quality": "Fine", "bonus": {"mind": 2}},
	"hunting_bow": {"name": "Hunting bow", "slot": "weapon", "quality": "Standard", "bonus": {}},
	"bell_mace": {"name": "Bell mace", "slot": "weapon", "quality": "Standard", "bonus": {}},
	"red_cloak": {"name": "Red cloak", "slot": "back", "quality": "Standard", "bonus": {}},
	"night_cloak": {"name": "Night cloak", "slot": "back", "quality": "Fine", "bonus": {"agility": 2}},
	"forest_cloak": {"name": "Forest cloak", "slot": "back", "quality": "Standard", "bonus": {"agility": 1}},
	"pilgrim_cloak": {"name": "Pilgrim cloak", "slot": "back", "quality": "Standard", "bonus": {"grit": 1}},
	"quiver": {"name": "Quiver", "slot": "back", "quality": "Standard", "bonus": {}},
	"belt": {"name": "Belt", "slot": "belt", "quality": "Standard", "bonus": {}},
	"sash": {"name": "Sash", "slot": "belt", "quality": "Standard", "bonus": {"mind": 1}},
	"green_sash": {"name": "Green sash", "slot": "belt", "quality": "Standard", "bonus": {}},
	"moonstone_amulet": {"name": "Moonstone amulet", "slot": "neck", "quality": "Standard", "bonus": {}},
}
## What each starter wears on joining the guild, by slot; anyone added later joins wearing nothing. Every item here adds nothing, so
## the starters' power and health are what their own stats give.
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


func _init() -> void:
	for adventurer: String in STARTER_GEAR:
		worn[adventurer] = STARTER_GEAR[adventurer].duplicate()


## The points `adventurer`'s items add to `stat`.
func bonus(adventurer: String, stat: String) -> int:
	var total := 0
	for item: String in worn[adventurer].values():
		total += int(ITEMS[item]["bonus"].get(stat, 0))
	return total


## The item a party back from a quest of `rank` brings, or "" for none. It depends only on
## `roll_seed` and `rank`, so the same return always brings the same item.
static func loot(roll_seed: int, rank: String) -> String:
	var rng := RandomNumberGenerator.new()
	# Not the outcome's own sequence, so whether loot comes is independent of success.
	rng.seed = hash("loot:%d" % roll_seed)
	if rng.randi_range(1, 100) > LOOT_PERCENT[rank]:
		return ""
	var roll := rng.randi_range(1, 100)
	var quality := ""
	for each: String in QUALITY_PERCENT:
		quality = each
		roll -= QUALITY_PERCENT[each]
		if roll <= 0:
			break
	var choices := PackedStringArray()
	for item: String in ITEMS:
		if ITEMS[item]["quality"] == quality:
			choices.append(item)
	return choices[rng.randi_range(0, choices.size() - 1)]


## Puts `item` in the stash; false, with the item lost, when the stash is full.
func stow(item: String) -> bool:
	if stash.size() >= STASH_CAP:
		return false
	stash.append(item)
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


## Puts the gear into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("gear", "worn", worn)
	file.set_value("gear", "stash", stash)


## The gear saved at `path`, or everyone in their starter gear with an empty stash when the save
## has none.
static func load_or_start(path: String) -> Gear:
	var gear := Gear.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("gear"):
		return gear
	gear.worn.assign(file.get_value("gear", "worn"))
	gear.stash = file.get_value("gear", "stash", PackedStringArray())
	return gear
