class_name Recruits
extends RefCounted

## The candidates visiting the guild, each in a slot of their own until hired. Hiring one empties
## their slot, which refills on its own countdown.

## The most candidates who visit at once, however many Common rooms the guild has.
const MAX_CANDIDATE_SLOTS: int = 4
## How long a slot takes to refill after its candidate is hired.
const CANDIDATE_REFILL_SECONDS: int = 60
## What a hire costs.
const HIRE_GOLD: int = 100
## The rank every candidate starts at.
const RANK: String = "F"
## Once the first Common room is finished, the share of candidates arriving from then on who are
## rank E instead, and what hiring one of them costs.
const RANK_E_CHANCE: float = 0.25
const HIRE_GOLD_E: int = 180
## How many of a candidate's stats show before they are hired; the others show "?".
const STATS_SHOWN: int = 2
## The first names candidates are given.
const NAMES: PackedStringArray = [
	"Aldric", "Alys", "Bryn", "Cael", "Corwin", "Dagny", "Edda", "Elspeth", "Fenn", "Garrick",
	"Hesper", "Hollis", "Idris", "Joss", "Kestrel", "Linnea", "Lorcan", "Mabon", "Nell", "Odile",
	"Osric", "Perrin", "Quill", "Rowan", "Sigrun", "Talia", "Tamsin", "Ulric", "Vesna", "Yara",
]
## Each class's stats on joining, which a candidate's own are up to STAT_SPREAD either side of, its
## growth, and the stat it grows in most: close to the starter of that class.
const CLASSES: Dictionary[String, Dictionary] = {
	"Swordsman": {"main": "might", "stats": {"might": 6, "agility": 3, "mind": 2, "grit": 6}, "growth": {"might": 0.6, "agility": 0.3, "mind": 0.15, "grit": 0.5}},
	"Mage": {"main": "mind", "stats": {"might": 2, "agility": 3, "mind": 7, "grit": 4}, "growth": {"might": 0.15, "agility": 0.3, "mind": 0.65, "grit": 0.35}},
	"Scout": {"main": "agility", "stats": {"might": 3, "agility": 7, "mind": 3, "grit": 3}, "growth": {"might": 0.3, "agility": 0.6, "mind": 0.25, "grit": 0.3}},
	"Healer": {"main": "mind", "stats": {"might": 2, "agility": 3, "mind": 6, "grit": 5}, "growth": {"might": 0.2, "agility": 0.3, "mind": 0.55, "grit": 0.5}},
	"Shield bearer": {"main": "grit", "stats": {"might": 4, "agility": 2, "mind": 2, "grit": 7}, "growth": {"might": 0.45, "agility": 0.2, "mind": 0.15, "grit": 0.6}},
}
const STAT_SPREAD: int = 1
## The share of candidates who are late bloomers: each stat LATE_BLOOMER_STAT_LOSS below what it
## would be, never under 1, but growth in their class's main stat of LATE_BLOOMER_GROWTH.
const LATE_BLOOMER_CHANCE: float = 0.1
const LATE_BLOOMER_STAT_LOSS: int = 2
const LATE_BLOOMER_GROWTH: float = 0.95

## Each slot's candidate, {} while it refills: {"who": as Adventurers.roster keeps it, face_seed
## included, "stats" and
## "growth": as Adventurers.add takes them, "shown": the stats shown before hiring}, and for a
## rank-E one "level": the level they arrive and are hired at.
var candidates: Array[Dictionary] = []
## Unix seconds each slot's candidate arrived, or, while it refills, arrives.
var refill_at: PackedInt64Array = PackedInt64Array()
## Latest unix seconds the slots have been refilled up to.
var checked_at: int = 0
## How many candidates visit at once with no Common room, as the Reception gives it
## (Hall.reception); each finished one adds a slot, up to MAX_CANDIDATE_SLOTS in all. Not saved:
## whoever loads the game sets it from the hall.
var reception_slots: int = Hall.LAYOUTS[Hall.NEW_LAYOUT]["candidate_slots"]


## Brings the slots up to `now`: adds a slot for each Common room finished, its first candidate due
## at the room's finish time in `common_rooms_done`, and fills each empty slot whose time has come,
## in the order their time comes. Each candidate is drawn from their slot and arrival time alone,
## never the global generator, so refilling once after an absence gives the same candidates as
## refilling every second through it; one arriving at or after the first Common room finished may
## be rank E. Time is read as no earlier than the slots last saw, so a clock set back never undoes
## a refill or restarts a countdown. A new guild starts with every slot filled.
func refill(adventurers: Adventurers, now: int, common_rooms_done: PackedInt64Array = PackedInt64Array()) -> void:
	var at := maxi(now, checked_at)
	if candidates.is_empty():
		for slot: int in reception_slots:
			candidates.append({})
			refill_at.append(at)
	var rooms := common_rooms_done.duplicate()
	rooms.sort()
	for i: int in range(candidates.size() - reception_slots, mini(rooms.size(), MAX_CANDIDATE_SLOTS - reception_slots)):
		candidates.append({})
		refill_at.append(rooms[i])
	var better_from := -1 if rooms.is_empty() else rooms[0]
	while true:
		var next := -1
		for slot: int in candidates.size():
			if candidates[slot].is_empty() and refill_at[slot] <= at and (next == -1 or refill_at[slot] < refill_at[next]):
				next = slot
		if next == -1:
			break
		candidates[next] = candidate_for(next, refill_at[next], _taken(adventurers, next), better_from)
	checked_at = at


## Seconds from `now` until empty slot `slot` refills.
func seconds_to_refill(slot: int, now: int) -> int:
	return maxi(0, refill_at[slot] - maxi(now, checked_at))


## Seconds from `now` until the soonest empty slot refills; -1 when no slot is empty.
func seconds_to_next_refill(now: int) -> int:
	var soonest := -1
	for slot: int in candidates.size():
		if candidates[slot].is_empty() and (soonest == -1 or seconds_to_refill(slot, now) < soonest):
			soonest = seconds_to_refill(slot, now)
	return soonest


## What hiring `candidate` costs: more for a rank-E one.
static func hire_gold(candidate: Dictionary) -> int:
	return HIRE_GOLD_E if candidate["who"]["rank"] == "E" else HIRE_GOLD


## Why nobody costing `cost` can be hired into `adventurers` with `gold` and `beds`, in words for
## the player; "" when they can. A Bunk room is suggested only while `hall` can still build one:
## none built or being built, and the guild's rank opens it.
static func refusal(adventurers: Adventurers, gold: Gold, beds: int, cost: int = HIRE_GOLD, hall: Hall = null) -> String:
	if adventurers.roster.size() >= beds:
		var bunk_room_open := hall != null and hall.has_rank(Hall.ROOM_TYPES["bunk_room"]["rank"]) and hall.first_room("bunk_room").is_empty()
		return "No free bed — convert a Bunk room" if bunk_room_open else "No free bed"
	if gold.amount < cost:
		return "Not enough gold"
	return ""


## Pays `hire_gold` and brings the candidate in `slot` at `now` into `adventurers`, emptying the
## slot until CANDIDATE_REFILL_SECONDS later; false, with nothing paid or hired, when the slot is
## empty or `refusal` gives a reason. `common_rooms_done` is as for `refill`.
func hire(slot: int, adventurers: Adventurers, gold: Gold, beds: int, now: int, common_rooms_done: PackedInt64Array = PackedInt64Array()) -> bool:
	refill(adventurers, now, common_rooms_done)
	if candidates[slot].is_empty() or not refusal(adventurers, gold, beds, hire_gold(candidates[slot])).is_empty():
		return false
	var hired := candidates[slot]
	gold.spend(hire_gold(hired))
	# A slot and an arrival time belong to one candidate only.
	# A candidate saved before rank-E ones arrived levelled is hired at level 1, as they were drawn.
	adventurers.add("recruit_%d_%d" % [slot, refill_at[slot]], hired["who"], hired["stats"], hired["growth"], hired.get("level", 1))
	candidates[slot] = {}
	refill_at[slot] = checked_at + CANDIDATE_REFILL_SECONDS
	return true


## The candidate who arrives in `slot` at `arrived_at`, named from NAMES other than `taken`; rank E
## by RANK_E_CHANCE when they arrive at or after `better_from`, the first Common room's finish time
## (-1 for none). A rank-E one arrives at the level rank E needs, their stats grown by a level-up's
## gains for each level past the first.
static func candidate_for(slot: int, arrived_at: int, taken: PackedStringArray, better_from: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([slot, arrived_at])
	var names := PackedStringArray()
	for name: String in NAMES:
		if name not in taken:
			names.append(name)
	var classes := Challenges.COVERS.keys()
	var type: String = classes[rng.randi_range(0, classes.size() - 1)]
	var build: Dictionary = CLASSES[type]
	var late_bloomer := rng.randf() < LATE_BLOOMER_CHANCE
	var stats := {}
	for stat: String in Adventurers.STATS:
		var points: int = build["stats"][stat] + rng.randi_range(-STAT_SPREAD, STAT_SPREAD)
		stats[stat] = maxi(1, points - LATE_BLOOMER_STAT_LOSS) if late_bloomer else points
	var growth: Dictionary = build["growth"].duplicate()
	if late_bloomer:
		growth[build["main"]] = LATE_BLOOMER_GROWTH
	var order := PackedStringArray(Adventurers.STATS.keys())
	for i: int in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	var name := names[rng.randi_range(0, names.size() - 1)]
	# Drawn last, so everything else about a candidate is as it would be without a Common room.
	var rank := RANK
	if better_from >= 0 and arrived_at >= better_from and rng.randf() < RANK_E_CHANCE:
		rank = "E"
	var candidate := {
		"who": {"name": name, "class": type, "rank": rank},
		"stats": stats,
		"growth": growth,
		"shown": order.slice(0, STATS_SHOWN),
	}
	if rank == "E":
		# Drawn after the rank, so a rank-F candidate is as they were before rank-E ones levelled.
		var level: int = Adventurers.PROMOTIONS["E"]["level"]
		for level_up: int in level - 1:
			var gains := Adventurers.gains_from(rng, growth)
			for stat: String in gains:
				stats[stat] += gains[stat]
		candidate["level"] = level
	candidate["who"]["face_seed"] = _face_seed(slot, arrived_at)
	return candidate


# The seed of the face of whoever arrives in `slot` at `arrived_at`. Not drawn from the candidate's
# generator: how much that draws depends on their rank, and a face never does, nor does it change
# anything else about them.
static func _face_seed(slot: int, arrived_at: int) -> int:
	return hash([slot, arrived_at, "face"])


## `candidate`'s stats for the player, those not shown as "?", such as "Might 5 · Agility ? · Mind 3
## · Grit ?".
static func stats_line(candidate: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat: String in Adventurers.STATS:
		var value: String = str(candidate["stats"][stat]) if stat in candidate["shown"] else "?"
		parts.append("%s %s" % [Adventurers.STATS[stat], value])
	return " · ".join(parts)


## Puts the candidates into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("recruits", "candidates", candidates)
	file.set_value("recruits", "refill_at", refill_at)
	file.set_value("recruits", "checked_at", checked_at)


## The candidates saved at `path`, or no slots, which the first `refill` fills, when the save has
## none.
static func load_or_start(path: String) -> Recruits:
	var recruits := Recruits.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("recruits"):
		return recruits
	recruits.candidates.assign(file.get_value("recruits", "candidates"))
	recruits.refill_at = file.get_value("recruits", "refill_at")
	recruits.checked_at = file.get_value("recruits", "checked_at")
	# A candidate saved before faces were made gets the one they would arrive with now.
	for slot: int in recruits.candidates.size():
		if not recruits.candidates[slot].is_empty() and not recruits.candidates[slot]["who"].has("face_seed"):
			recruits.candidates[slot]["who"]["face_seed"] = _face_seed(slot, recruits.refill_at[slot])
	return recruits


# The names nobody arriving in `slot` may have: everyone's in the guild and the other candidates'.
func _taken(adventurers: Adventurers, slot: int) -> PackedStringArray:
	var taken := PackedStringArray()
	for who: Dictionary in adventurers.roster.values():
		taken.append(who["name"])
	for other: int in candidates.size():
		if other != slot and not candidates[other].is_empty():
			taken.append(candidates[other]["who"]["name"])
	return taken
