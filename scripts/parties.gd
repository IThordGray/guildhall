class_name Parties
extends RefCounted

## Who adventures together. A party has a name and 1 to Dispatch.MAX_PARTY_SIZE members; an
## adventurer is in at most one party, and anyone in none is a reserve, who can't go on quests. All
## of it is saved with the adventurers.

## A party's name is "The <adjective> <noun>", one word drawn from each.
const ADJECTIVES: PackedStringArray = [
	"Iron", "Ashen", "Lucky", "Grey", "Silver", "Crimson", "Hollow", "Bold", "Wandering", "Quiet",
	"Golden", "Black", "Broken", "Merry", "Restless", "Stubborn", "Last", "Wild", "Northern", "Weary",
]
const NOUNS: PackedStringArray = [
	"Wolves", "Lanterns", "Oaths", "Ravens", "Blades", "Shields", "Foxes", "Hounds", "Crowns", "Stags",
	"Owls", "Keys", "Banners", "Spears", "Candles", "Boots", "Bells", "Thorns", "Anvils", "Badgers",
]
## The most characters a name the player types keeps, so it fits a party card's header.
const NAME_MOST_CHARS: int = 24
## Where `move` sends someone instead of a party's id: the reserves, or a new party of their own.
const RESERVES: String = ""
const NEW_PARTY: String = "new"
## How boldly a party with Auto on picks its quests (Auto.LOWEST_LOW_END).
const SAFE: String = "safe"
const BOLD: String = "bold"

## The parties, in the order they were made. Each is {"id", "name": drawn or typed, "seed": what the
## name was last drawn from, "members": adventurer ids in the order they joined, and once set,
## "auto": whether it goes questing by itself (see Auto), "mode": SAFE or BOLD, "elite_auto": whether
## Auto may send it on an elite expedition}.
var parties: Array[Dictionary] = []
## The number in the next new party's id, so no id is ever used twice.
var next_id: int = 1


## The id of the party `adventurer` is in; RESERVES when in none.
func party_of(adventurer: String) -> String:
	for party: Dictionary in parties:
		if adventurer in party["members"]:
			return party["id"]
	return RESERVES


## The party with `id`; {} for none.
func party(id: String) -> Dictionary:
	for each: Dictionary in parties:
		if each["id"] == id:
			return each
	return {}


## Each party's id and members, in the order the parties were made: what a screen showing a row or
## card per party is built from, so it rebuilds only when a party is made, goes or changes members.
func groups() -> Array:
	var found := []
	for each: Dictionary in parties:
		found.append([each["id"], each["members"].duplicate()])
	return found


## Whether the party with `id` goes questing by itself (Auto); off until turned on, as in a save
## from before Auto.
func auto(id: String) -> bool:
	return party(id).get("auto", false)


func set_auto(id: String, on: bool) -> void:
	party(id)["auto"] = on


## How boldly the party with `id` picks its quests with Auto on: SAFE until set, as in a save from
## before Auto.
func mode(id: String) -> String:
	return party(id).get("mode", SAFE)


func set_mode(id: String, picked: String) -> void:
	party(id)["mode"] = picked


## Whether Auto may send the party with `id` on an open elite expedition, which can kill (see Auto):
## off until turned on, as in a save from before it.
func elite_auto(id: String) -> bool:
	return party(id).get("elite_auto", false)


func set_elite_auto(id: String, on: bool) -> void:
	party(id)["elite_auto"] = on


## Everyone in `roster` (Adventurers.roster) in no party, in roster order.
func reserves(roster: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	for adventurer: String in roster:
		if party_of(adventurer) == RESERVES:
			found.append(adventurer)
	return found


## The rank of the party with `id`: its members' ranks in `roster` averaged, F counting 0 up to S
## counting 6, rounded down.
func rank(id: String, roster: Dictionary) -> String:
	var members: PackedStringArray = party(id)["members"]
	var total := 0
	for adventurer: String in members:
		total += Challenges.RANKS.find(roster[adventurer]["rank"])
	return Challenges.RANKS[floori(total / float(members.size()))]


## The name drawn from `name_seed`, never the global generator, so a seed always gives one name.
static func name_of(name_seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = name_seed
	return "The %s %s" % [ADJECTIVES[rng.randi() % ADJECTIVES.size()], NOUNS[rng.randi() % NOUNS.size()]]


## Puts `adventurer`, in no party, into the last party while it has room, else into a new party of
## their own: how the starters and a save from before parties are grouped.
func place(adventurer: String) -> void:
	if parties.is_empty() or parties.back()["members"].size() >= Dispatch.MAX_PARTY_SIZE:
		_make(adventurer)
	else:
		_join(parties.back(), adventurer)


## Why `adventurer` can't move to `to` (a party's id, RESERVES or NEW_PARTY) in `dispatch`, in words
## for the player; "" when they can. A move needs them and everyone in the party they leave and the
## one they join at home, and room in the one they join.
func move_refusal(adventurer: String, to: String, dispatch: Dispatch) -> String:
	var from := party_of(adventurer)
	if to == from:
		return "Already there"
	if not dispatch.quest_of(adventurer).is_empty():
		return "Out on a quest"
	var concerned := PackedStringArray()
	for id: String in [from, to]:
		if not party(id).is_empty():
			concerned.append_array(party(id)["members"])
	for member: String in concerned:
		if not dispatch.quest_of(member).is_empty():
			return "%s is out on a quest" % dispatch.adventurers.roster[member]["name"]
	if not party(to).is_empty() and party(to)["members"].size() >= Dispatch.MAX_PARTY_SIZE:
		return "Party full"
	return ""


## Moves `adventurer` to `to`, as for `move_refusal`; false, with nothing changed, when it gives a
## reason.
func move(adventurer: String, to: String, dispatch: Dispatch) -> bool:
	if not move_refusal(adventurer, to, dispatch).is_empty():
		return false
	leave(adventurer)
	if to == NEW_PARTY:
		_make(adventurer)
	elif to != RESERVES:
		_join(party(to), adventurer)
	return true


## Takes `adventurer` out of their party, if any, into the reserves, whoever is home; a party left
## with nobody disappears. For someone leaving the guild or joining it as a reserve.
func leave(adventurer: String) -> void:
	var left := party(party_of(adventurer))
	if left.is_empty():
		return
	var members: PackedStringArray = left["members"]
	members.remove_at(members.find(adventurer))
	left["members"] = members
	if members.is_empty():
		parties.erase(left)


## Names the party with `id` `typed`, without the spaces around it and cut to NAME_MOST_CHARS; a
## name with nothing but spaces keeps the one it has.
func rename(id: String, typed: String) -> void:
	var trimmed := typed.strip_edges().left(NAME_MOST_CHARS)
	if not trimmed.is_empty():
		party(id)["name"] = trimmed


## Gives the party with `id` a new drawn name, never the one it has, typed or drawn, from a seed that
## follows from its last.
func reroll(id: String) -> void:
	var rerolled := party(id)
	var next_seed: int = hash(rerolled["seed"])
	while name_of(next_seed) == rerolled["name"]:
		next_seed = hash(next_seed)
	rerolled["seed"] = next_seed
	rerolled["name"] = name_of(next_seed)


# A new party of `adventurer` alone, named from a seed of the global generator's.
func _make(adventurer: String) -> void:
	var name_seed := randi()
	parties.append({"id": "party_%d" % next_id, "name": name_of(name_seed), "seed": name_seed, "members": PackedStringArray([adventurer])})
	next_id += 1


# Adds `adventurer` last to `joined`'s members.
static func _join(joined: Dictionary, adventurer: String) -> void:
	var members: PackedStringArray = joined["members"]
	members.append(adventurer)
	joined["members"] = members


## Puts the parties into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("parties", "parties", parties)
	file.set_value("parties", "next_id", next_id)


## The parties `file` holds, or, for a save from before parties, everyone in `roster_order` put into
## parties of up to Dispatch.MAX_PARTY_SIZE in that order (`place`).
static func read(file: ConfigFile, roster_order: Array) -> Parties:
	var read_parties := Parties.new()
	if not file.has_section("parties"):
		for adventurer: String in roster_order:
			read_parties.place(adventurer)
		return read_parties
	read_parties.parties.assign(file.get_value("parties", "parties"))
	read_parties.next_id = file.get_value("parties", "next_id")
	return read_parties
